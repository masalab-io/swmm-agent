# swmm_cli simulate run

Triggers a full SWMM simulation run and blocks until the engine finishes, returning the final run status and continuity errors; reach for it whenever you need to execute the model and capture results.

## Syntax

```
swmm_cli simulate run [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session file exists or exactly one SWMM instance is running. |

There are no other flags. The command takes no `--type`, `--id`, `--prop`, or `--value` arguments.

## Response shape

```json
{ "ok": true, "data": { "status": "success", "message": "Run was successful.", "continuity_errors": { "surface_runoff": 0.0012, "flow_routing": -0.0034, "quality_routing": 0.0000 } } }
{ "ok": true, "data": { "status": "warning", "message": "Run was successful with warnings. See Status Report for details.", "continuity_errors": { "surface_runoff": 0.1500, "flow_routing": 0.0200, "quality_routing": 0.0000 } } }
{ "ok": false, "data": { "status": "error", "message": "Run was unsuccessful. See Status Report for reasons." } }
{ "ok": false, "data": { "status": "failed", "message": "Run was unsuccessful due to system error." } }
{ "ok": false, "error": "No project is currently open" }
```

### Field descriptions

**Top-level fields**

| Field | Type | Present when | Description |
|-------|------|-------------|-------------|
| `ok` | boolean | Always | `true` if status is `success` or `warning`; `false` for all other outcomes |
| `data` | object | Always (even on failure) | Nested result object |
| `error` | string | Pre-run guard failures only | Human-readable reason when the run could not be started at all (e.g., no project open) |

**`data` fields**

| Field | Type | Present when | Description |
|-------|------|-------------|-------------|
| `status` | string | Always | One of: `success`, `warning`, `error`, `failed`, `stopped`, `shutdown`, `wrong_version`, `import_error`, `none` |
| `message` | string | Always | Human-readable explanation of the status |
| `continuity_errors` | object | `ok: true` only | Mass-balance error percentages from the SWMM engine |

**`continuity_errors` sub-fields** (only present when `ok: true`)

| Field | Type | Description |
|-------|------|-------------|
| `surface_runoff` | float (4 dp) | Runoff continuity error (%) — EPA guidance: accept < 1 % |
| `flow_routing` | float (4 dp) | Flow routing continuity error (%) — EPA guidance: accept < 1 % |
| `quality_routing` | float (4 dp) | Water quality routing continuity error (%) |

**`status` value reference**

| `status` | `ok` | Meaning |
|----------|------|---------|
| `success` | true | Run completed, no warnings |
| `warning` | true | Run completed, one or more warnings issued (check Status Report) |
| `error` | false | Run failed — check Status Report for input or engine errors |
| `failed` | false | System-level failure (report file empty or OS error) |
| `stopped` | false | Run was stopped before completion |
| `shutdown` | false | Simulator performed an illegal operation and was shut down |
| `wrong_version` | false | `swmm5.dll` version mismatch |
| `import_error` | false | Project could not be exported to the temporary input file |
| `none` | false | Project data invalid — simulation could not start |

## How to use it

1. Confirm a project is open with `swmm_cli file info`.
2. Optionally modify element properties with `swmm_cli element set`.
3. Call `swmm_cli simulate run`.
4. Inspect `ok` and `status` in the response.
5. If `ok: true`, proceed to `swmm_cli results get` or `swmm_cli results summary`.
6. If `ok: false` and `status` is `error` or `warning`, examine the SWMM Status Report window that flashes briefly on screen, or call `swmm_cli simulate status` to confirm the persisted status.

```bash
# Run the simulation and capture the result
RESULT=$(swmm_cli simulate run)
echo $RESULT | jq .

# Check whether it succeeded
OK=$(echo $RESULT | jq -r '.ok')
STATUS=$(echo $RESULT | jq -r '.data.status')
echo "ok=$OK  status=$STATUS"

# If successful, inspect continuity errors
echo $RESULT | jq '.data.continuity_errors'
```

## PID resolution for this command

`simulate run` follows the standard six-step resolution chain:

| Step | Source | Notes |
|------|--------|-------|
| 1 | `--pid <N>` flag | Use when running multiple SWMM instances simultaneously |
| 2 | Piped stdin `{"kind":"session","pid":N}` | Relevant when chaining with `process list` output |
| 3 | `SWMM_PID` env var | Useful in scripted / CI environments |
| 4 | `.swmm/session.json` | Written by `swmm_cli attach`; most common path after setup |
| 5 | Auto-discovery | Succeeds only if exactly one `Epaswmm5.exe` is running |
| 6 | Error | Thrown if no instance found or multiple instances running |

If resolution fails with "Multiple SWMM instances running", use `--pid` to target the correct one. If no instance is found, call `swmm_cli process launch` first.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli file open --path "C:/Models/ExampleModel.inp" --pid $PID
swmm_cli simulate run --pid $PID
swmm_cli results summary --type junction --id J5 --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 7412
swmm_cli file open --path "C:/Models/ExampleModel.inp"
swmm_cli simulate run          # --pid not needed
swmm_cli results summary --type junction --id J5
```

### Pattern 3 — sequential workflow: modify → run → verify → fetch results

This is the standard agent workflow for a parametric study.

```bash
# 1. Attach once
swmm_cli attach 7412

# 2. Verify a file is loaded
swmm_cli file info

# 3. Change a junction's maximum depth
swmm_cli element set --type junction --id J5 --prop max_depth --value 4.0

# 4. Run simulation — blocks until the engine finishes
RUN=$(swmm_cli simulate run)
OK=$(echo $RUN | jq -r '.ok')

if [ "$OK" != "true" ]; then
  echo "Simulation failed: $(echo $RUN | jq -r '.data.status')"
  exit 1
fi

# 5. Check continuity errors
echo $RUN | jq '.data.continuity_errors'

# 6. Retrieve peak depth time-series for J5
swmm_cli results get --type junction --id J5 --variable depth
```

## Gotchas and caveats for agents

- **Blocking call**: `simulate run` **blocks** on the named pipe until the SWMM DLL finishes the entire simulation and returns the final status directly in the response. Do not poll `simulate status` in a loop after calling `simulate run` — the pipe response is not returned until the run is complete. `simulate status` is only useful for checking the outcome of a previous run or querying state between sessions.

- **Exit code**: the CLI process exits 0 if the pipe round-trip itself succeeded (even if `ok: false` in the JSON). Check `ok` in the JSON to know whether the simulation succeeded — do not rely on the exit code alone to determine simulation outcome.

- **`ok: false` does not always mean pipe failure**: if the run status is `error`, `failed`, `none`, etc., the JSON still uses `{"ok":false,"data":{...}}` — the `data` key is present. Only pre-run guard failures (e.g., "No project is currently open") use the `{"ok":false,"error":"..."}` shape without a `data` key.

- **State requirement — project must be open**: the handler checks `Assigned(Project)` before running. If no `.inp` file has been loaded, the response is `{"ok":false,"error":"No project is currently open"}`. Call `swmm_cli file open` first.

- **State requirement — SWMM must have the pipe server**: the bundled `plugin/dist/Epaswmm5.exe` is required. The standard EPA binary does not have the named-pipe API and will not respond to any `swmm_cli` command.

- **UI flash on success**: after a successful or warning run, the Delphi code briefly shows a Status Report window for 1 second (`UI_FLASH_DELAY_MS = 1000` in `SwmmAgentConfig.pas`) and then closes it. This is expected behaviour — the window will appear and disappear on the user's screen.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and `--pid` is omitted, resolution step 5 throws "Multiple SWMM instances running". Always specify `--pid` or use `swmm_cli attach` when running multiple instances.

- **Pipe availability**: before sending `simulate run`, ensure the SWMM process is ready. Use `swmm_cli process list` and wait until `available: true` for the target PID. Attempting to connect before the pipe server has started results in a 5-second timeout and a "Pipe connect timeout" error.

- **Continuity errors on warning runs**: `ok: true` with `status: "warning"` still includes `continuity_errors`. Evaluate the percentages — EPA SWMM guidance recommends accepting errors below 1 %. Larger values may indicate time-step or routing issues.

- **Temp file management**: the handler deletes and recreates SWMM temporary files on every run. If `ResultsSaved` is false, old report and output files are removed. Do not rely on the previous run's temp files surviving a second `simulate run` call.
