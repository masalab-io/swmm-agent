# swmm_cli element list

List all element IDs of a given type in the currently-open SWMM model; use this to discover what nodes, links, or subcatchments exist before calling `element get` or `element set` on individual elements.

## Syntax

```
swmm_cli element list --type <type> [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--type` | string | Yes | Element type to enumerate. Valid values listed below. |
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session file exists or exactly one instance is running. |

### Valid `--type` values

| Value | SWMM object type |
|-------|-----------------|
| `junction` | Junction node |
| `outfall` | Outfall node |
| `divider` | Flow divider node |
| `storage` | Storage unit node |
| `conduit` | Conduit link |
| `pump` | Pump link |
| `orifice` | Orifice link |
| `weir` | Weir link |
| `outlet` | Outlet link |
| `subcatchment` | Subcatchment |

## Response shape

```json
{ "ok": true, "elements": [ ... ] }   // success — array of element refs
{ "ok": false, "error": "..." }        // failure
```

On success the `elements` array contains one object per element of the requested type. Each object is a slim element reference:

```json
[
  { "kind": "swmm_element", "id": "J1", "type": "junction" },
  { "kind": "swmm_element", "id": "J5", "type": "junction" },
  { "kind": "swmm_element", "id": "J12", "type": "junction" }
]
```

| Field | Description |
|-------|-------------|
| `kind` | Always `"swmm_element"` — identifies this as a SWMM element reference |
| `id` | The element's name as it appears in the SWMM model (e.g. `J1`, `C3`, `Sub1`). Case-sensitive; use exactly this value when calling `element get` or `element set`. |
| `type` | Echoes the `--type` argument used in the request (e.g. `"junction"`) |

On failure `{ "ok": false, "error": "..." }` is printed to stdout and the process exits with code 1.

## How to use it

Use `element list` to enumerate all element IDs of a type — for example, to discover all junctions before bulk-editing invert elevations, or to confirm that a newly-added element appears in the model.

```bash
# List all junctions in the open model
swmm_cli element list --type junction

# List all conduits
swmm_cli element list --type conduit

# Extract just the IDs with jq
swmm_cli element list --type junction | jq '[.elements[].id]'
```

To count how many junctions exist:

```bash
swmm_cli element list --type junction | jq '.elements | length'
```

## PID resolution for this command

`element list` uses the standard six-step resolution chain. The most relevant steps are:

1. **`--pid <N>`** — always wins; use this when working with multiple SWMM instances.
2. **Piped stdin** — if a prior command emitted `{"kind":"session","pid":N}`, that PID is used automatically.
3. **`SWMM_PID` env var** — useful in scripts that set the variable once at the top.
4. **Session file** — `.swmm/session.json` in CWD, written by `swmm_cli attach`. This is the most common zero-friction path: run `attach` once at session start and omit `--pid` everywhere.
5. **Auto-discovery** — succeeds only when exactly one `Epaswmm5.exe` is running.
6. **Error** — thrown when no instance is found or multiple instances exist without an explicit PID.

If resolution fails with "Multiple SWMM instances running", specify `--pid` explicitly or run `swmm_cli attach <pid>` to pin a session.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli element list --type junction --pid $PID
swmm_cli element list --type conduit  --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 18340
swmm_cli element list --type junction   # --pid not needed
swmm_cli element list --type conduit    # --pid not needed
```

### Pattern 3 — sequential workflow: list → get → set

The canonical bulk-edit pattern — discover all IDs, then read and modify each one:

```bash
# 1. Enumerate all junctions
JUNCTIONS=$(swmm_cli element list --type junction | jq -r '.elements[].id')

# 2. Read each junction's properties
for ID in $JUNCTIONS; do
  swmm_cli element get --type junction --id "$ID"
done

# 3. Edit a specific junction found from the list
swmm_cli element set --type junction --id J5 --prop invert_elev --value 11.0

# 4. Verify the change
swmm_cli element get --type junction --id J5 | jq '.invert_elev'
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 on success, 1 on any error (unrecognised type string, pipe failure, no file open). Always check exit code before consuming stdout.

- **Empty array is valid**: if the model has no elements of the requested type, `elements` is an empty array `[]` — this is a success response (`"ok": true`), not an error. Do not treat an empty list as a failure.

- **Type string is case-insensitive at the CLI layer**: the `--type` flag accepts `junction`, `Junction`, and `JUNCTION` interchangeably. The `type` field in the response is normalised to lowercase.

- **Unrecognised `--type` value**: if you pass a type that the server does not recognise (e.g. `--type manhole`), the server returns `{ "ok": false, "error": "..." }` and the CLI exits 1. Use only the ten valid type strings from the table above.

- **State requirements**: SWMM must be running and a `.inp` file must be open. Calling `element list` on a fresh SWMM instance with no file open returns an error. Run `swmm_cli file info` first to verify a file is loaded.

- **IDs are case-sensitive in subsequent calls**: the `id` field returned by `element list` is the exact name stored in the model. When passing this value to `element get` or `element set`, use it verbatim — `J5` and `j5` refer to different elements.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no PID is resolved via steps 1–4, the command throws "Multiple SWMM instances running". Always attach or specify `--pid` in multi-instance setups.

- **Pipe availability**: after launching SWMM with `process launch`, poll `swmm_cli process list` until `available` is `true` for the target PID before calling `element list`. Sending commands before the pipe is ready returns a connection error.

- **No pagination**: all elements are returned in a single response. For very large models with hundreds of elements this may produce a large JSON payload; pipe through `jq` to filter early rather than consuming the full output in memory.
