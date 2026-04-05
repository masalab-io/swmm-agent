# swmm_cli element add

Add a new node element to the open SWMM model; use this when building or
programmatically expanding a drainage network by creating junctions, outfalls,
dividers, or storage units at specified map coordinates.

## Syntax

```
swmm_cli element add --type <type> --id <id> [--x <x>] [--y <y>] [--pid <pid>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--type` | string | yes | Element type to create. Valid values: `junction`, `outfall`, `divider`, `storage` |
| `--id` | string | yes | New element ID. Must be unique within the model; SWMM IDs are case-sensitive |
| `--x` | double | no | X map coordinate in the project's coordinate system (default: `0`) |
| `--y` | double | no | Y map coordinate in the project's coordinate system (default: `0`) |
| `--pid` | integer | no | PID of the target `Epaswmm5.exe` process. Omit after running `swmm_cli attach` |

### Valid `--type` values

| Value | SWMM model object | Notes |
|-------|-------------------|-------|
| `junction` | Manhole / junction node | Most common node type; collects and routes flow |
| `outfall` | Terminal outfall node | System boundary; must be connected downstream of conduits |
| `divider` | Flow divider node | Splits flow between two links; requires diversion rules after creation |
| `storage` | Storage unit node | Pond or tank; requires geometry attributes set via `element set` |

Note: link types (`conduit`, `pump`, `orifice`, `weir`, `outlet`) and
`subcatchment` are **not** supported by `element add`. The command will
return an error for those types.

## Response shape

```json
{ "ok": true }
```

```json
{ "ok": false, "error": "Element 'J5' already exists" }
```

The success response contains only `ok: true`. All element properties beyond
the map coordinates default to SWMM's built-in zero or empty values. Use
`element set` immediately after to configure invert elevation, max depth, and
any other required properties.

## How to use it

Add a new junction node `J10` at map position (1200.0, 850.0), then verify it
was created and set its invert elevation.

```bash
# 1. Add the junction
swmm_cli element add --type junction --id J10 --x 1200.0 --y 850.0

# 2. Confirm it exists and see its default properties
swmm_cli element get --type junction --id J10

# 3. Set invert elevation to 45.5 m
swmm_cli element set --type junction --id J10 --prop invert_elev --value 45.5
```

## PID resolution for this command

`element add` calls `SessionResolver.ResolvePid` which walks the six-step
chain:

1. `--pid` flag — use if provided.
2. Piped stdin `{"kind":"session","pid":N}` — used when this command is part
   of a pipeline.
3. `SWMM_PID` environment variable.
4. `.swmm/session.json` in the current working directory (written by
   `swmm_cli attach`).
5. Auto-discovery — succeeds only when exactly one `Epaswmm5.exe` is running.
6. Error — thrown if no instance is found or multiple instances are running.

If resolution fails the command exits 1 with
`{"ok":false,"error":"No running SWMM instance found ..."}` or
`{"ok":false,"error":"Multiple SWMM instances running ..."}`.
**Recommended fix**: run `swmm_cli attach <pid>` once at session start, then
omit `--pid` for all subsequent calls.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli element add --pid $PID --type junction --id J10 --x 1200.0 --y 850.0
swmm_cli element set --pid $PID --type junction --id J10 --prop invert_elev --value 45.5
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 4872
swmm_cli element add --type junction --id J10 --x 1200.0 --y 850.0
swmm_cli element set --type junction --id J10 --prop invert_elev --value 45.5
swmm_cli element get --type junction --id J10   # verify
```

### Pattern 3 — sequential workflow: add node, connect conduit, run simulation

After adding a new node you typically need to add a conduit connecting it to
the network, set properties, and then run a simulation to check the impact.
Because `element add` only supports node types, conduit creation must be done
via a separate mechanism (direct `.inp` file edit or a future `element add`
extension).

```bash
# Add junction and configure it
swmm_cli element add --type junction --id J10 --x 1200.0 --y 850.0
swmm_cli element set --type junction --id J10 --prop invert_elev --value 45.5
swmm_cli element set --type junction --id J10 --prop max_depth --value 3.0

# Verify the node before running
swmm_cli element get --type junction --id J10

# Run simulation to check updated network
swmm_cli simulate run

# Poll until done (success/warning/error)
swmm_cli simulate status

# Inspect results at the new node
swmm_cli results summary --type junction --id J10
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 on success, 1 on any error (duplicate ID, unsupported
  type, pipe failure, PID resolution failure). Always check `ok` in the JSON
  response before proceeding.

- **Duplicate IDs**: if `--id` matches an existing element of any type the
  agent-side SWMM code will return an error. Check `element list --type
  <type>` first if the ID may already exist.

- **Supported types only**: `element add` accepts `junction`, `outfall`,
  `divider`, and `storage`. Passing `conduit`, `pump`, `orifice`, `weir`,
  `outlet`, or `subcatchment` will return `{"ok":false,"error":"..."}` with
  exit code 1.

- **Default property values**: the newly created node has all numeric
  properties set to zero (invert elevation 0, max depth 0, etc.). A junction
  with max depth 0 means SWMM treats depth as unlimited. Always follow up with
  `element set` calls to configure critical properties before running a
  simulation.

- **State requirements**: a model file must be open in the SWMM instance
  (`swmm_cli file info` returns a path) before `element add` will succeed.
  Calling it against a freshly launched instance with no file loaded returns an
  error from the named pipe handler.

- **Map coordinates vs. hydraulic data**: `--x` and `--y` are purely visual
  (map canvas position). They do not affect hydraulic calculations. Omitting
  them places the node at (0, 0) which may cause visual overlap in the SWMM
  GUI but has no simulation consequence.

- **Multiple SWMM instances**: if two or more `Epaswmm5.exe` processes are
  running and `--pid` is omitted (and no session file exists), resolution
  fails at step 5 with an error. Specify `--pid` explicitly or run `swmm_cli
  attach <pid>` for the target instance.

- **Pipe availability**: after launching SWMM with `process launch`, the named
  pipe is not immediately ready. Check `process list` until `available=true`
  before calling `element add`, otherwise the connection will be refused and
  the command exits 1.

- **No undo**: SWMM's in-memory model is mutated directly. There is no
  rollback mechanism. If you add the wrong element, the only recourse is to
  close the file without saving or reopen the original `.inp`.
