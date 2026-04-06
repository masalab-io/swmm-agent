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
{ "kind": "session", "pid": 18432 }
{ "ok": false, "error": "Epaswmm5.exe not found. Set CLAUDE_PLUGIN_ROOT to the plugin root directory, or ensure Epaswmm5.exe exists at dist/ alongside the swmm_cli binary." }
```

**Success fields:**

| Field | Type | Description |
|-------|------|-------------|
| `kind` | string | Always `"session"` — identifies this as a pipeable session line |
| `pid` | int | OS process ID of the newly launched `Epaswmm5.exe` |

The session line format (`{"kind":"session","pid":N}`) is recognized by all
downstream consumer commands when piped, allowing the PID to propagate
automatically through a bash pipeline.

**Failure fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `false` on failure |
| `error` | string | Human-readable reason — `CLAUDE_PLUGIN_ROOT` not set and fallback path `../dist/Epaswmm5.exe` also not found |

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

### Pattern 1 — pipeline mode (recommended)

`process launch` is the natural start of a bash pipeline. Its session line
`{"kind":"session","pid":N}` is picked up automatically by every downstream
consumer — no `--pid` flag or `attach` call needed.

```bash
# Full pipeline: launch → open → simulate → results
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/catchment.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

Each consumer stage blocks until the previous stage finishes (drain-to-EOF),
so the pipeline runs sequentially even though bash starts all processes
simultaneously.

```bash
# Pipeline with element filtering
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/catchment.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 100.0
```

### Pattern 2 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process launch | jq '.pid')
# wait until pipe is ready
until swmm_cli process list | jq -e ".processes[] | select(.pid==$PID) | .available" > /dev/null 2>&1; do sleep 1; done
swmm_cli file open --path "C:/Models/catchment.inp" --pid $PID
swmm_cli element get --type junction --id J1 --pid $PID
```

### Pattern 3 — session file (attach once, omit --pid everywhere)

```bash
PID=$(swmm_cli process launch | jq '.pid')
swmm_cli attach $PID
# all subsequent commands resolve the PID from .swmm/session.json automatically
swmm_cli file open --path "C:/Models/catchment.inp"
swmm_cli simulate run
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 with `{"ok":true,"pid":N}` on success; exits 1 with `{"ok":false,"error":"..."}` if `CLAUDE_PLUGIN_ROOT` is not set or `Epaswmm5.exe` is missing in `dist/`. The agent should halt and report the error — it cannot recover without fixing the environment.

- **Race condition — pipe not immediately available**: the command sleeps 500 ms internally before returning, but the named-pipe server inside `Epaswmm5.exe` typically takes 2–5 seconds to initialise. Always poll `swmm_cli process list` and wait for `"available": true` before sending any element, file, simulate, or results commands.

- **`CLAUDE_PLUGIN_ROOT` preferred but not required**: the command first checks the `CLAUDE_PLUGIN_ROOT` env var, then falls back to looking for `../dist/Epaswmm5.exe` relative to the `swmm_cli` binary itself. If `swmm_cli.exe` lives at `.../plugin/bin/swmm_cli.exe`, the fallback finds `.../plugin/dist/Epaswmm5.exe` automatically. Setting `CLAUDE_PLUGIN_ROOT` is still recommended for clarity. Set it to the directory that contains both `bin/` and `dist/` (e.g. `export CLAUDE_PLUGIN_ROOT=.../plugin`).

- **Standard EPA download will not work**: even if the agent somehow points to a different copy of `Epaswmm5.exe`, the standard EPA binary has no named-pipe server and will not respond to any subsequent `swmm_cli` commands. Always use the binary from `plugin/dist/`.

- **Multiple SWMM instances**: every call to `process launch` starts a fresh instance. If called twice, two instances run with different PIDs. Subsequent commands that rely on auto-discovery (resolution step 5) will fail with "Multiple SWMM instances running". Always attach immediately after launch to pin the session to one PID.

- **Windows only**: `Epaswmm5.exe` is a Windows GUI application. `Process.Start` uses `UseShellExecute = true`, so the SWMM window will appear on the desktop. There is no headless mode.

- **No `--pid` flag**: unlike most other `swmm_cli` commands, `process launch` accepts no flags at all. Passing `--pid` or other unknown flags will cause the command to exit with an error from the argument parser.
