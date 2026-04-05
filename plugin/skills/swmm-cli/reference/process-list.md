# swmm_cli process list

Enumerate all running `Epaswmm5.exe` processes and report whether their named
pipe is available; use this before every session to discover which PID to
attach to.

## Syntax

```
swmm_cli process list
```

## Parameters

This command takes no flags.

## Response shape

```json
{ "ok": true, "processes": [{ "pid": 12480, "pipe": "\\\\.\\pipe\\swmm_agent_12480", "available": true }] }
{ "ok": false, "error": "..." }
```

### Success payload fields

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `true` on success |
| `processes` | array | Zero or more entries, one per running `Epaswmm5.exe` |
| `processes[].pid` | int | Windows process ID of that SWMM instance |
| `processes[].pipe` | string | Full named-pipe path for that instance: `\\.\pipe\swmm_agent_{pid}` |
| `processes[].available` | bool | `true` when the pipe file exists — i.e. the agent server inside SWMM is listening and ready to accept commands |

An empty `processes` array (`[]`) is a valid success response meaning no
`Epaswmm5.exe` is currently running.

### Failure payload

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `false` |
| `error` | string | Exception message from the .NET runtime |

## How to use it

The typical use is at the start of a session to decide whether to launch a new
instance or attach to an existing one.

```bash
# 1. Check what is running
swmm_cli process list

# Example output when one instance is ready:
# {"ok":true,"processes":[{"pid":12480,"pipe":"\\\\.\\pipe\\swmm_agent_12480","available":true}]}

# 2. If available=true, attach to it
swmm_cli attach 12480

# 3. If available=false, the pipe server is still starting — poll
until swmm_cli process list | jq -e '.processes[0].available == true' > /dev/null 2>&1; do
  sleep 1
done
swmm_cli attach 12480

# 4. If processes is empty, launch first
swmm_cli process launch
# then poll as in step 3
```

## PID resolution for this command

`process list` does **not** use the SessionResolver. It calls
`Process.GetProcessesByName("Epaswmm5")` directly and requires no PID input.
There is no `--pid` flag and no resolution chain. The command always succeeds
(returning an empty array) even when no SWMM instance is running.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli attach $PID
swmm_cli file info --pid $PID
swmm_cli element get --type junction --id J1 --pid $PID
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

Run `process list` once to find the PID, attach to persist it, then drop
`--pid` from every subsequent call.

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli attach $PID
# All subsequent calls resolve PID from .swmm/session.json automatically
swmm_cli file info
swmm_cli element list --type junction
swmm_cli simulate run
```

### Pattern 3 — sequential workflow (launch → wait → attach)

Use `process list` to poll after a fresh launch until the pipe becomes
available, then attach.

```bash
swmm_cli process launch
for i in $(seq 1 10); do
  READY=$(swmm_cli process list | jq '.processes[0].available // false')
  [ "$READY" = "true" ] && break
  sleep 1
done
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli attach $PID
swmm_cli file open --path "C:/Models/tutorial.inp"
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 on success (including when no processes are
  running — empty array is not an error), exits 1 only if the underlying
  `Process.GetProcessesByName` call throws an OS-level exception. An exit
  code of 1 indicates an unexpected system error; inspect the `error` field.

- **`available` vs running**: `available` is determined by
  `File.Exists(pipePath)`. A process can appear in the list with
  `available: false` for 2–5 seconds after launch while the named-pipe
  server initialises inside the Delphi executable. Always poll on
  `available` before issuing any pipe-dependent command.

- **Race conditions**: do not rely on the index position of a process entry
  being stable across successive calls. Always read `pid` from the response
  rather than hard-coding it.

- **Multiple SWMM instances**: when more than one entry appears, the agent
  must pick the correct PID explicitly using `--pid` or `swmm_cli attach`.
  Commands that use SessionResolver (steps 5–6) will throw if multiple
  instances exist and no session file or env var is set.

- **State requirements**: none — this command has no prerequisites and can
  be called at any time, even before SWMM is launched.

- **Pipe path format**: the `pipe` field contains a Windows device path
  (`\\.\pipe\swmm_agent_{pid}`). On bash (e.g. Git Bash or WSL), double
  backslashes in JSON strings are normal escaping; the actual path uses
  single backslashes.

- **Empty processes array**: `{"ok":true,"processes":[]}` is a success
  response meaning no instance is running — do not treat it as an error.
  Proceed to `swmm_cli process launch` if you need a running instance.
