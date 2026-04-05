# swmm_cli process launch

Launch the bundled `Epaswmm5.exe` from the plugin's `dist/` directory; use this as the first step of any SWMM session when no instance is already running.

## Syntax

```
swmm_cli process launch
```

## Parameters

This command takes no flags. There is no `--pid` option because the process does not yet exist when this command is invoked.

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| *(none)* | — | — | The executable path is resolved automatically from `$CLAUDE_PLUGIN_ROOT/dist/Epaswmm5.exe` |

## Response shape

```json
{ "ok": true, "pid": 18432 }
{ "ok": false, "error": "Epaswmm5.exe not found. CLAUDE_PLUGIN_ROOT is not set or dist/Epaswmm5.exe is missing." }
```

**Success fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `true` on success |
| `pid` | int | OS process ID of the newly launched `Epaswmm5.exe` |

**Failure fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `false` on failure |
| `error` | string | Human-readable reason — typically `CLAUDE_PLUGIN_ROOT` not set, or `dist/Epaswmm5.exe` missing |

## How to use it

The typical agent session start: check whether SWMM is running, launch it if not, wait for the named-pipe server to become available, then attach.

```bash
# 1. Check for existing instances
swmm_cli process list

# 2. No instance found — launch
swmm_cli process launch
# → { "ok": true, "pid": 18432 }

# 3. Wait for the pipe to become available (poll ~2–5 s)
swmm_cli process list
# → { "ok": true, "processes": [{ "pid": 18432, "pipe": "\\\\.\\pipe\\swmm_agent_18432", "available": true }] }

# 4. Attach so subsequent commands need no --pid
swmm_cli attach 18432
```

## PID resolution for this command

`process launch` does **not** use the PID resolution chain — it creates a new process rather than targeting an existing one. No `--pid`, session file, `SWMM_PID` env var, or auto-discovery is consulted. The PID returned in the response is the one to use for all subsequent commands.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process launch | jq '.pid')
# wait until pipe is ready
until swmm_cli process list | jq -e ".processes[] | select(.pid==$PID) | .available" > /dev/null 2>&1; do sleep 1; done
swmm_cli file open --path "C:/Models/catchment.inp" --pid $PID
swmm_cli element get --type junction --id J1 --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
PID=$(swmm_cli process launch | jq '.pid')
swmm_cli attach $PID
# all subsequent commands resolve the PID from .swmm/session.json automatically
swmm_cli file open --path "C:/Models/catchment.inp"
swmm_cli simulate run
```

### Pattern 3 — sequential workflow

Full session start-to-simulation workflow:

```bash
# Launch and capture PID
PID=$(swmm_cli process launch | jq '.pid')

# Poll until the named-pipe server is ready
READY=false
for i in $(seq 1 10); do
  READY=$(swmm_cli process list | jq -r ".processes[] | select(.pid==$PID) | .available")
  [ "$READY" = "true" ] && break
  sleep 1
done

# Attach session so --pid is not needed again
swmm_cli attach $PID

# Open a model file and run
swmm_cli file open --path "C:/Models/catchment.inp"
swmm_cli simulate run

# Poll simulation status
until [ "$(swmm_cli simulate status | jq -r '.status')" != "running" ]; do sleep 2; done
swmm_cli results summary --type node --id J5
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 with `{"ok":true,"pid":N}` on success; exits 1 with `{"ok":false,"error":"..."}` if `CLAUDE_PLUGIN_ROOT` is not set or `Epaswmm5.exe` is missing in `dist/`. The agent should halt and report the error — it cannot recover without fixing the environment.

- **Race condition — pipe not immediately available**: the command sleeps 500 ms internally before returning, but the named-pipe server inside `Epaswmm5.exe` typically takes 2–5 seconds to initialise. Always poll `swmm_cli process list` and wait for `"available": true` before sending any element, file, simulate, or results commands.

- **`CLAUDE_PLUGIN_ROOT` must be set**: the command resolves the bundled exe exclusively via this environment variable. If the variable is absent, the command always fails regardless of whether `Epaswmm5.exe` exists elsewhere on disk.

- **Standard EPA download will not work**: even if the agent somehow points to a different copy of `Epaswmm5.exe`, the standard EPA binary has no named-pipe server and will not respond to any subsequent `swmm_cli` commands. Always use the binary from `plugin/dist/`.

- **Multiple SWMM instances**: every call to `process launch` starts a fresh instance. If called twice, two instances run with different PIDs. Subsequent commands that rely on auto-discovery (resolution step 5) will fail with "Multiple SWMM instances running". Always attach immediately after launch to pin the session to one PID.

- **Windows only**: `Epaswmm5.exe` is a Windows GUI application. `Process.Start` uses `UseShellExecute = true`, so the SWMM window will appear on the desktop. There is no headless mode.

- **No `--pid` flag**: unlike most other `swmm_cli` commands, `process launch` accepts no flags at all. Passing `--pid` or other unknown flags will cause the command to exit with an error from the argument parser.
