# swmm_cli results get

Retrieves the full time-series output for a single element/variable pair after a simulation has completed; use this whenever an agent needs to inspect how a value changed over every reporting timestep.

## Syntax

```
swmm_cli results get --type <type> --id <id> --variable <variable> [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--type` | string | Yes | Element category. Valid values: `node`, `link`, `subcatchment` |
| `--id` | string | Yes | Element ID as it appears in the `.inp` file (e.g. `J1`, `C3`, `S2`) |
| `--variable` | string | Yes | Output variable name. See variable tables below. |
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session is active. |

### Valid `--variable` values by type

**node** (`junction`, `outfall`, `divider`, `storage`)

| Variable | Description |
|----------|-------------|
| `depth` | Water depth above invert (ft or m) |
| `head` | Hydraulic head (ft or m) |
| `volume` | Stored volume (ft³ or m³) |
| `latflow` | Lateral inflow (cfs or cms) |
| `inflow` | Total inflow (cfs or cms) |
| `overflow` | Flooding/overflow rate (cfs or cms) |

**link** (`conduit`, `pump`, `orifice`, `weir`, `outlet`)

| Variable | Description |
|----------|-------------|
| `flow` | Flow rate (cfs or cms) |
| `depth` | Water depth (ft or m) |
| `velocity` | Flow velocity (ft/s or m/s) |
| `volume` | Volume in link (ft³ or m³) |
| `capacity` | Fraction of full capacity (0–1) |

**subcatchment**

| Variable | Description |
|----------|-------------|
| `runoff` | Runoff rate (cfs or cms) |
| `rainfall` | Rainfall rate (in/hr or mm/hr) |
| `evap` | Evaporation loss (in/hr or mm/hr) |
| `infil` | Infiltration loss (in/hr or mm/hr) |
| `washoff` | Pollutant washoff (mass/sec) |

## Response shape

```json
{ "ok": true, "data": [{ "time": "2024-01-01T00:15:00", "value": 1.23 }, ...] }
{ "ok": false, "error": "No simulation results available" }
```

Success payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `true` on success |
| `data` | array | One object per reporting timestep, in chronological order |
| `data[].time` | string | ISO 8601 datetime of the reporting step |
| `data[].value` | number | Output variable value at that timestep, in project units |

Failure payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `false` on failure |
| `error` | string | Human-readable reason (no results, unknown element, invalid variable, pipe error, etc.) |

## How to use it

After a simulation completes successfully, retrieve the depth time-series for junction `J5`:

```bash
# 1. Confirm simulation finished successfully
swmm_cli simulate status
# {"ok":true,"status":"success"}

# 2. Retrieve depth at junction J5 across all timesteps
swmm_cli results get --type node --id J5 --variable depth
```

Example response:

```json
{
  "ok": true,
  "data": [
    { "time": "2024-06-01T00:00:00", "value": 0.00 },
    { "time": "2024-06-01T00:15:00", "value": 0.42 },
    { "time": "2024-06-01T00:30:00", "value": 1.87 },
    { "time": "2024-06-01T00:45:00", "value": 3.21 },
    { "time": "2024-06-01T01:00:00", "value": 2.65 }
  ]
}
```

To get the flow time-series for conduit `C3`:

```bash
swmm_cli results get --type link --id C3 --variable flow
```

To get runoff for subcatchment `S2`:

```bash
swmm_cli results get --type subcatchment --id S2 --variable runoff
```

## PID resolution for this command

`results get` uses the standard six-step resolution chain:

1. `--pid` flag (explicit, highest priority)
2. `{"kind":"session","pid":N}` first line on piped stdin
3. `SWMM_PID` environment variable
4. `.swmm/session.json` in CWD (written by `swmm_cli attach`)
5. Auto-discovery — succeeds only if exactly one `Epaswmm5.exe` is running
6. Error — thrown if no instance is found or multiple instances exist

Steps 1–4 are the relevant paths in practice. Step 5 is convenient in single-instance workflows. If resolution fails at step 6, the agent must either run `swmm_cli attach <pid>` to write a session file or pass `--pid` explicitly.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli simulate run --pid $PID
swmm_cli results get --type node --id J5 --variable depth --pid $PID
swmm_cli results get --type link --id C3 --variable flow  --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 18432
swmm_cli simulate run
swmm_cli results get --type node --id J5 --variable depth   # --pid not needed
swmm_cli results get --type subcatchment --id S2 --variable runoff
```

### Pattern 3 — sequential workflow (run → poll → get results)

This command is the final step in the simulate-and-analyse workflow. Always confirm the simulation completed before calling it.

```bash
# 1. Start the run
swmm_cli simulate run

# 2. Poll until simulation finishes (status leaves "running")
while true; do
  STATUS=$(swmm_cli simulate status | jq -r '.status')
  echo "Status: $STATUS"
  [ "$STATUS" = "running" ] || break
  sleep 2
done

# 3. Abort if run did not succeed
if [ "$STATUS" != "success" ] && [ "$STATUS" != "warning" ]; then
  echo "Simulation ended with status: $STATUS — results unavailable"
  exit 1
fi

# 4. Retrieve results for multiple elements
swmm_cli results get --type node --id J1  --variable depth
swmm_cli results get --type node --id J5  --variable overflow
swmm_cli results get --type link --id C3  --variable flow
swmm_cli results get --type subcatchment --id S2 --variable runoff
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 on success, 1 on any failure. Always check `ok` in the JSON before consuming `data`.
- **Simulation must be complete**: calling `results get` before a simulation has run (status `none`) or while it is still running (status `running`) will return `{"ok":false,"error":"No simulation results available"}`. Always poll `simulate status` to confirm `success` or `warning` before calling this command.
- **`warning` status is still valid**: a status of `warning` means the simulation completed with non-fatal warnings. Results are still available and should be retrieved normally.
- **`--type` is the category, not the element subtype**: use `node` for junctions, outfalls, dividers, and storage units; use `link` for conduits, pumps, orifices, weirs, and outlets. Passing `junction` or `conduit` will return an error.
- **Invalid `--variable`**: if the variable name does not exist for the given type (e.g. `--type node --variable flow`), the server returns `{"ok":false,"error":"..."}`. Consult the variable tables above.
- **Unknown element ID**: if `--id` does not exist in the project, the command returns `{"ok":false,"error":"Element not found"}`. Verify element IDs with `swmm_cli element list --type <type>` first.
- **Empty `data` array**: a successful response with `"data":[]` means the simulation produced zero reporting timesteps for this element. Check the simulation's reporting interval in the `.inp` file.
- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no session or `--pid` is provided, PID resolution fails at step 5. The agent must specify `--pid` or run `swmm_cli attach` first.
- **Pipe availability**: if `process list` shows `available=false` for the target process, the named-pipe server is not yet ready and any command — including `results get` — will fail with a pipe error. Wait and retry until `available=true` before issuing commands.
- **Units**: values are returned in the unit system configured in the open `.inp` file (US customary or SI). The response does not include a units field; the agent must check the project's `[OPTIONS]` section if unit context is required.
