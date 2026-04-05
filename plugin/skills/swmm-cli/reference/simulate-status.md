# swmm_cli simulate status

Poll the current simulation run status of a running SWMM instance; use this after `simulate run` to determine whether the engine has finished and whether it succeeded or encountered errors.

## Syntax

```
swmm_cli simulate status [--pid <N>]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session file exists or exactly one instance is running. |

## Response shape

```json
{ "ok": true, "status": "<value>" }   // success — one of the six status strings
{ "ok": false, "error": "..." }        // failure (pipe error, resolution error, etc.)
```

### Status values

| `status` value | Meaning |
|----------------|---------|
| `none` | No simulation has been run yet in this session |
| `running` | Simulation is currently executing |
| `success` | Simulation completed without warnings or errors |
| `warning` | Simulation completed but generated one or more warnings |
| `error` | Simulation encountered a recoverable error |
| `failed` | Simulation failed to complete (fatal error) |

The `status` field is always present when `ok` is `true`. The command exits with code 0 for all valid status values (including `error` and `failed`) — it is reporting status, not signaling failure.

## How to use it

Call `simulate status` after `simulate run` to poll until the engine finishes, then branch on the returned status string.

```bash
# Trigger the run (returns immediately)
swmm_cli simulate run

# Poll until status is no longer "running"
while true; do
  STATUS=$(swmm_cli simulate status | jq -r '.status')
  echo "Status: $STATUS"
  if [ "$STATUS" != "running" ]; then
    break
  fi
  sleep 1
done

# Act on the result
if [ "$STATUS" = "success" ] || [ "$STATUS" = "warning" ]; then
  swmm_cli results summary --type node --id J5
else
  echo "Simulation did not complete successfully: $STATUS"
fi
```

## PID resolution for this command

`simulate status` uses the standard six-step resolution chain. The most relevant steps are:

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
swmm_cli simulate run --pid $PID
swmm_cli simulate status --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 18340
swmm_cli simulate run            # --pid not needed
swmm_cli simulate status         # --pid not needed
```

### Pattern 3 — sequential workflow: run → poll status → get results

The canonical end-to-end pattern for running a simulation and retrieving output:

```bash
# 1. (Optional) Edit a property first
swmm_cli element set --type junction --id J1 --prop invert_elev --value 8.5

# 2. Trigger the simulation
swmm_cli simulate run

# 3. Poll until done
while true; do
  STATUS=$(swmm_cli simulate status | jq -r '.status')
  [ "$STATUS" != "running" ] && break
  sleep 1
done

# 4. Retrieve results if run was successful
if [ "$STATUS" = "success" ] || [ "$STATUS" = "warning" ]; then
  swmm_cli results summary --type node --id J1
  swmm_cli results get     --type node --id J1 --variable depth
fi
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 when the JSON response is delivered (even when `status` is `error` or `failed`). Exits 1 only when the command itself fails — for example, when PID resolution throws, when the named pipe is not available, or when the response JSON cannot be parsed. Always check `ok` in the response body, not just the exit code.

- **Race conditions / timing**: `simulate run` returns immediately after triggering the engine; the engine runs asynchronously in the SWMM GUI thread. Call `simulate status` in a polling loop with a short sleep (1 second is sufficient for most models). Do not assume the simulation is finished just because `simulate run` returned `{"ok":true}`.

- **`none` status**: if `simulate status` returns `none`, no simulation has been triggered in the current session. Ensure `simulate run` was called and returned `{"ok":true}` before polling.

- **`warning` is a valid result**: models with minor issues (e.g., continuity errors below threshold) return `warning` but still produce complete output. Retrieve results normally; inspect the SWMM report file for details.

- **`failed` vs `error`**: `failed` means the engine could not complete execution (e.g., missing routing data, severe numerical instability). `error` is a recoverable condition. In either case, results may be incomplete or absent — do not call `results get` / `results summary` after these statuses without verifying first.

- **State requirements**: SWMM must be running, a `.inp` file must be open, and `simulate run` must have been called at least once. Calling `simulate status` on a fresh instance with no run attempted returns `{"ok":true,"status":"none"}` — not an error.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no PID is resolved via steps 1–4, the command throws "Multiple SWMM instances running". Always attach or specify `--pid` in multi-instance setups.

- **Pipe availability**: before issuing `simulate status` after launching SWMM, confirm the pipe is ready by polling `swmm_cli process list` until `available` is `true` for the target PID. Sending commands before the pipe is up returns a connection error (exit code 1).

- **No progress information**: the command reports coarse status only (`running` / `success` / etc.). There is no percentage-complete or step counter. For long-running models, just sleep-poll at 1-second intervals.
