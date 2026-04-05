# swmm_cli element get

Read all properties of a single SWMM model element (node, link, or subcatchment) by type and ID; use this whenever you need to inspect or verify the current state of a specific element before or after making changes.

## Syntax

```
swmm_cli element get --type <type> --id <id> [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--type` | string | Yes | Element type. Valid values listed below. |
| `--id` | string | Yes | The element's name/ID as it appears in the SWMM model (e.g. `J1`, `C3`, `Sub1`). Case-sensitive. |
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
{ "ok": true, "data": { ... } }   // success — typed element object
{ "ok": false, "error": "..." }   // failure
```

On success the CLI pretty-prints the `data` object directly (the outer `ok` wrapper is not printed; only the typed element JSON appears on stdout). On failure the raw `{"ok":false,"error":"..."}` object is printed and the process exits with code 1.

### Junction

```json
{
  "id": "J5",
  "type": "junction",
  "x": 1200.0,
  "y": 850.0,
  "comment": "",
  "tag": "",
  "invert_elev": "10.5",
  "max_depth": "3.0",
  "init_depth": "0",
  "surcharge_depth": "0",
  "ponded_area": "0"
}
```

| Field | Description |
|-------|-------------|
| `id` | Element name |
| `type` | Always `"junction"` |
| `x`, `y` | Map coordinates |
| `comment` | Optional free-text comment |
| `tag` | Optional tag label |
| `invert_elev` | Invert elevation (ft or m) |
| `max_depth` | Maximum depth; `0` means use distance to top of highest connecting conduit |
| `init_depth` | Initial water depth at simulation start |
| `surcharge_depth` | Additional depth before flooding occurs |
| `ponded_area` | Ponded surface area when flooded |

### Outfall

```json
{
  "id": "Out1",
  "type": "outfall",
  "x": 3000.0,
  "y": 400.0,
  "comment": "",
  "tag": "",
  "invert_elev": "5.0",
  "tide_gate": "NO",
  "route_to": "",
  "outfall_type": "FREE",
  "stage_data": ""
}
```

| Field | Description |
|-------|-------------|
| `invert_elev` | Invert elevation |
| `tide_gate` | `YES` or `NO` — whether a tide gate is present |
| `route_to` | Subcatchment to route outfall discharge to (empty if none) |
| `outfall_type` | `FREE`, `NORMAL`, `FIXED`, `TIDAL`, or `TIMESERIES` |
| `stage_data` | Fixed stage value or time series name (depends on `outfall_type`) |

### Conduit

```json
{
  "id": "C3",
  "type": "conduit",
  "comment": "",
  "tag": "",
  "inlet_node": "J1",
  "outlet_node": "J5",
  "shape": "CIRCULAR",
  "geom1": "1.5",
  "geom2": "0",
  "geom3": "0",
  "geom4": "0",
  "length": "120.0",
  "roughness": "0.013",
  "in_offset": "0",
  "out_offset": "0",
  "init_flow": "0",
  "max_flow": "0",
  "entry_loss": "0.5",
  "exit_loss": "1.0",
  "avg_loss": "0",
  "seepage": "0",
  "check_valve": "NO",
  "culvert_code": "",
  "barrels": "1"
}
```

| Field | Description |
|-------|-------------|
| `inlet_node` / `outlet_node` | Connected node IDs |
| `shape` | Cross-section shape (e.g. `CIRCULAR`, `RECT_CLOSED`) |
| `geom1` | Primary cross-section dimension (diameter for circular) |
| `geom2`–`geom4` | Secondary dimensions (shape-dependent) |
| `length` | Conduit length |
| `roughness` | Manning's n |
| `in_offset` / `out_offset` | Invert offsets at inlet/outlet nodes |
| `entry_loss` / `exit_loss` / `avg_loss` | Loss coefficients |
| `check_valve` | `YES` or `NO` |
| `culvert_code` | HDS-5 culvert code (empty if not a culvert) |
| `barrels` | Number of parallel barrels |

### Subcatchment

```json
{
  "id": "Sub1",
  "type": "subcatchment",
  "comment": "",
  "tag": "",
  "rain_gage": "RG1",
  "outlet": "J1",
  "area": "5.0",
  "imperv": "60.0",
  "width": "200.0",
  "slope": "1.5",
  "curb_length": "0",
  "snow_pack": ""
}
```

## How to use it

Use `element get` to read the current property values of an element — for example, to check a junction's invert elevation before editing it, or to confirm a change made via `element set`.

```bash
# Read all properties of junction J5
swmm_cli element get --type junction --id J5

# Read all properties of conduit C3
swmm_cli element get --type conduit --id C3

# Read an outfall
swmm_cli element get --type outfall --id Out1
```

To extract a specific field, pipe through `jq`:

```bash
swmm_cli element get --type junction --id J5 | jq '.invert_elev'
```

## PID resolution for this command

`element get` uses the standard six-step resolution chain. The most relevant steps are:

1. **`--pid <N>`** — always wins; use this when working with multiple SWMM instances.
2. **Piped stdin** — if a prior command emitted `{"kind":"session","pid":N}`, that PID is used automatically.
3. **`SWMM_PID` env var** — useful in scripts that set the variable once.
4. **Session file** — `.swmm/session.json` in CWD, written by `swmm_cli attach`. This is the most common zero-friction path: run `attach` once at session start and omit `--pid` everywhere.
5. **Auto-discovery** — succeeds only when exactly one `Epaswmm5.exe` is running.
6. **Error** — thrown when no instance is found or multiple instances exist without an explicit PID.

If resolution fails with "Multiple SWMM instances running", specify `--pid` explicitly or run `swmm_cli attach <pid>` to pin a session.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli element get --type junction --id J5 --pid $PID
swmm_cli element get --type conduit  --id C3  --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 18340
swmm_cli element get --type junction --id J5   # --pid not needed
swmm_cli element get --type conduit  --id C3   # --pid not needed
```

### Pattern 3 — sequential workflow: get → set → verify

The canonical pattern for making a controlled edit:

```bash
# 1. Read current state
swmm_cli element get --type junction --id J5

# 2. Change invert elevation
swmm_cli element set --type junction --id J5 --prop invert_elev --value 11.0

# 3. Verify the change took effect
swmm_cli element get --type junction --id J5 | jq '.invert_elev'

# 4. Run simulation and check results
swmm_cli simulate run
swmm_cli simulate status   # poll until status != "running"
swmm_cli results summary --type node --id J5
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 on success, 1 on any error (unknown type, unknown ID, pipe failure, JSON parse error). Always check exit code before consuming stdout.

- **Output format**: on success, only the element JSON object is printed — not the outer `{"ok":true,"data":{...}}` envelope. Scripts that parse the output with `jq` should read the object directly (e.g. `jq '.invert_elev'`, not `jq '.data.invert_elev'`).

- **Unrecognised type falls back to raw JSON**: if the API returns a type string not known to the deserializer, the raw `data` object is printed as-is. This is forward-compatible but means field names may differ from the typed records above.

- **All numeric property values are strings**: fields like `invert_elev`, `max_depth`, and `length` are returned as JSON strings (e.g. `"10.5"`), not numbers. Use `jq` arithmetic with `tonumber` if you need to compare or compute with them.

- **State requirements**: SWMM must be running and a `.inp` file must be open (`swmm_cli file info` should return a non-empty path). Calling `element get` against a fresh SWMM instance with no file open returns an error.

- **ID is case-sensitive**: `J5` and `j5` are different. Use `element list --type junction` to enumerate exact IDs from the model.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no PID is resolved via steps 1–4, the command throws "Multiple SWMM instances running". Always attach or specify `--pid` in multi-instance setups.

- **Pipe availability**: before issuing any element command after launching SWMM, confirm the pipe is ready by polling `swmm_cli process list` until `available` is `true` for the target PID. Sending commands before the pipe is up returns a connection error.

- **No partial reads**: the command returns all properties at once; there is no way to request a single property. Use `jq` to filter the output to the field you need.
