# swmm_cli element set

Set a single named property on a SWMM node, link, or subcatchment element; use this command whenever an agent needs to modify a model parameter (invert elevation, pipe roughness, storage geometry, etc.) before running a simulation.

## Syntax

```
swmm_cli element set --type <type> --id <id> --prop <prop> --value <value> [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--type` | string | yes | Element type. Valid values listed below. |
| `--id` | string | yes | Element ID as it appears in the `.inp` file (case-sensitive). |
| `--prop` | string | yes | Property name to set. Must match a field defined for the element type (see tables below). |
| `--value` | string | yes | New value for the property, always passed as a string; SWMM converts it internally. |
| `--pid` | integer | no | PID of the target `Epaswmm5.exe` process. Omit when a session file is present or only one instance is running. |

### Valid `--type` values

| `--type` value | SWMM model object |
|----------------|-------------------|
| `junction` | Junction node |
| `outfall` | Outfall node |
| `divider` | Flow divider node |
| `storage` | Storage unit node |
| `conduit` | Conduit link |
| `pump` | Pump link |
| `orifice` | Orifice link |
| `weir` | Weir link |
| `outlet` | Outlet link |
| `subcatchment` | Subcatchment area |

### Settable properties by element type

**junction**

| `--prop` value | Description |
|----------------|-------------|
| `invert_elev` | Invert elevation (ft or m) |
| `max_depth` | Maximum depth (0 = use distance to top of highest connecting conduit) |
| `init_depth` | Initial water depth |
| `surcharge_depth` | Additional depth before surcharging |
| `ponded_area` | Ponded surface area when flooded |
| `tag` | User tag |
| `comment` | Free-text comment |

**outfall**

| `--prop` value | Description |
|----------------|-------------|
| `invert_elev` | Invert elevation |
| `outfall_type` | Boundary condition type (FREE, NORMAL, FIXED, TIDAL, TIMESERIES) |
| `stage_data` | Fixed stage or time-series name (depends on `outfall_type`) |
| `tide_gate` | YES / NO |
| `route_to` | Subcatchment to receive outfall runoff (optional) |
| `tag` | User tag |
| `comment` | Free-text comment |

**divider**

| `--prop` value | Description |
|----------------|-------------|
| `invert_elev` | Invert elevation |
| `max_depth` | Maximum depth |
| `init_depth` | Initial depth |
| `surcharge_depth` | Surcharge depth |
| `ponded_area` | Ponded area |
| `divider_link` | Link that receives diverted flow |
| `divider_type` | CUTOFF, OVERFLOW, TABULAR, WEIR |
| `cutoff_flow` | Cutoff flow for CUTOFF type |
| `qmin` | Minimum flow for WEIR type |
| `dmax` | Max depth for WEIR type |
| `qcoeff` | Weir coefficient |
| `tag` | User tag |
| `comment` | Free-text comment |

**storage**

| `--prop` value | Description |
|----------------|-------------|
| `invert_elev` | Invert elevation |
| `max_depth` | Maximum depth |
| `init_depth` | Initial depth |
| `surcharge_depth` | Surcharge depth |
| `evap_factor` | Evaporation factor (0–1) |
| `seepage` | Seepage loss rate |
| `geometry` | Shape function (TABULAR, FUNCTIONAL, or named shape) |
| `coeff0` | Functional geometry coefficient A |
| `coeff1` | Functional geometry coefficient B |
| `coeff2` | Functional geometry coefficient C |
| `area_table` | Name of Storage Curve table (TABULAR geometry only) |
| `tag` | User tag |
| `comment` | Free-text comment |

**conduit**

| `--prop` value | Description |
|----------------|-------------|
| `inlet_node` | Upstream node ID |
| `outlet_node` | Downstream node ID |
| `shape` | Cross-section shape (CIRCULAR, RECT_OPEN, etc.) |
| `geom1` | Primary cross-section dimension (diameter for CIRCULAR) |
| `geom2` | Secondary cross-section dimension |
| `geom3` | Tertiary cross-section dimension |
| `geom4` | Quaternary cross-section dimension |
| `length` | Conduit length |
| `roughness` | Manning's n |
| `in_offset` | Inlet offset above node invert |
| `out_offset` | Outlet offset above node invert |
| `init_flow` | Initial flow rate |
| `max_flow` | Maximum flow cap (0 = none) |
| `entry_loss` | Entry loss coefficient |
| `exit_loss` | Exit loss coefficient |
| `avg_loss` | Average loss coefficient |
| `seepage` | Seepage loss rate |
| `check_valve` | YES / NO |
| `culvert_code` | Culvert code (optional) |
| `barrels` | Number of barrels |
| `tag` | User tag |
| `comment` | Free-text comment |

## Response shape

```json
{ "ok": true }
```

```json
{ "ok": false, "error": "Element not found: J99" }
{ "ok": false, "error": "Unknown property: bogus_prop" }
{ "ok": false, "error": "No running SWMM instance found — launch SWMM or specify --pid" }
```

On success the response is always `{"ok":true}` with no additional fields. The value is written to the SWMM in-memory model immediately but is not saved to disk until the user saves the file inside SWMM or an agent calls the appropriate file-save command.

## How to use it

To raise the invert elevation of junction J5 from 95.0 to 97.5:

```bash
# 1. Confirm the current value
swmm_cli element get --type junction --id J5

# 2. Apply the change
swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5

# 3. Verify the write was accepted
swmm_cli element get --type junction --id J5
```

To increase the Manning's roughness on conduit C3:

```bash
swmm_cli element set --type conduit --id C3 --prop roughness --value 0.015
```

## PID resolution for this command

`element set` uses the standard six-step PID resolution chain. The most relevant steps are:

- **Step 1 (`--pid`)**: use when multiple SWMM instances are running and you must target a specific one.
- **Step 4 (session file)**: after running `swmm_cli attach <pid>`, the PID is read from `.swmm/session.json` automatically — omit `--pid` for the remainder of the session.
- **Step 5 (auto-discovery)**: if exactly one `Epaswmm5.exe` is running and no session file exists, the PID is resolved automatically.

If resolution fails (step 6), the command outputs `{"ok":false,"error":"..."}` and exits with code 1. The agent should run `swmm_cli process list` to diagnose.

## How to chain it

### Pattern 1 — pipeline mode

`element set` can sit in a pipeline after `process launch` and `file open`.

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5
```

To set multiple properties, run the pipeline once per property (each stage
re-emits the session line so it flows to all subsequent commands):

```bash
PID=$(swmm_cli process launch | jq '.pid')
swmm_cli element set --pid $PID --type junction --id J5 --prop invert_elev --value 97.5
swmm_cli element set --pid $PID --type junction --id J5 --prop max_depth   --value 4.0
```

### Pattern 2 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli element set --pid $PID --type junction --id J5 --prop invert_elev --value 97.5
swmm_cli element set --pid $PID --type conduit  --id C3 --prop roughness    --value 0.015
```

### Pattern 3 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 14832
swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5
swmm_cli element set --type conduit  --id C3 --prop roughness    --value 0.015
```

### Pattern 4 — sequential workflow (set → verify → simulate → check results)

```bash
# Attach to session
swmm_cli attach 14832

# Make parameter changes
swmm_cli element set --type junction --id J1 --prop max_depth --value 4.5
swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5
swmm_cli element set --type conduit  --id C3 --prop roughness --value 0.013

# Verify the changes were applied
swmm_cli element get --type junction --id J1
swmm_cli element get --type junction --id J5
swmm_cli element get --type conduit  --id C3

# Run simulation and poll until complete
swmm_cli simulate run
until swmm_cli simulate status | jq -e '.status == "success" or .status == "error" or .status == "failed"' > /dev/null; do
  sleep 2
done

# Retrieve results
swmm_cli results summary --type junction --id J5
```

## Gotchas and caveats for agents

- **Exit codes**: exit 0 means `{"ok":true}` was returned — the property was accepted by the SWMM model API. Exit 1 means the command output `{"ok":false,...}`. Always check `ok` in the JSON, not just the exit code.

- **No persistence until save**: `element set` writes to the running in-memory model only. If SWMM crashes or is closed without saving, the change is lost. Prompt the user to save, or build a save step into the workflow.

- **String values for numeric properties**: all values are passed as strings (e.g., `--value 97.5`). SWMM parses them internally. Passing a non-numeric string for a numeric field (e.g., `--value abc`) will produce `{"ok":false,"error":"..."}`.

- **Invalid property names**: if `--prop` does not match any known property for the given type, the command returns `{"ok":false,"error":"Unknown property: <name>"}`. Use `element get` first to discover the exact property name spellings.

- **Invalid element ID**: SWMM IDs are case-sensitive. `J1` and `j1` are different elements. Use `element list --type junction` to retrieve exact IDs.

- **Invalid type value**: passing an unrecognised `--type` (e.g., `--type pipe`) returns `{"ok":false,"error":"..."}`. Use only the values listed in the Parameters table.

- **State requirements**: a `.inp` model file must be open in the SWMM instance before `element set` can succeed. Run `swmm_cli file info` first — if `ok` is false or `path` is empty, open a file with `swmm_cli file open --path <path>`.

- **Simulation must be re-run after changes**: `element set` modifies design parameters. Any previously computed results are stale. Always re-run `simulate run` after making changes if results are needed.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no session file or `--pid` is provided, resolution fails with `"Multiple SWMM instances running — specify --pid or run: swmm_cli attach <pid>"`. Resolve by running `swmm_cli attach <pid>` for the target instance.

- **Pipe availability**: if `process list` shows `available: false` for a process, its named pipe is not yet ready. Wait and retry — do not attempt `element set` until `available` is true.
