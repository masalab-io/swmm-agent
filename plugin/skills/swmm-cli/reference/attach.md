# swmm_cli attach

Saves a SWMM process PID to the local session file so that all subsequent commands in the same working directory resolve the target process automatically without needing `--pid`.

## Syntax

```
swmm_cli attach <pid>
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `pid` | integer (positional) | Yes | PID of the running `Epaswmm5.exe` process to attach to. Obtain this from `swmm_cli process list`. |

`attach` takes no option flags — it has one positional argument only.

## Response shape

```json
{ "ok": true, "pid": 14328 }   // success — PID was written to .swmm/session.json
{ "ok": false, "error": "..." } // failure (not currently emitted by attach itself; see Gotchas)
```

Success payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `true` on success. |
| `pid` | integer | The PID that was written to the session file. Echo of the argument. |

## How to use it

Run `process list` first to find the PID, then call `attach` with that PID. After `attach` completes, all further commands in the same working directory omit `--pid`.

```bash
# 1. Find the running SWMM instance
swmm_cli process list
# Output: {"ok":true,"processes":[{"pid":14328,"pipe":"\\.\pipe\swmm_agent_14328","available":true}]}

# 2. Attach — write the session file
swmm_cli attach 14328
# Output: {"ok":true,"pid":14328}

# 3. All later commands now work without --pid
swmm_cli file info
swmm_cli element list --type junction
```

## PID resolution for this command

`attach` does **not** go through the six-step PID resolution chain. It takes the PID as a direct positional argument and writes it unconditionally. There is nothing to resolve — you supply the PID, `attach` stores it.

If you do not know the PID, run `swmm_cli process list` first. If that returns an empty `processes` array, SWMM is not running — use `swmm_cli process launch` to start it, then wait until `available` is `true`, then attach.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli attach $PID
# From here on, --pid is not needed in the same working directory
swmm_cli file info
swmm_cli element list --type junction
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

This is exactly what `attach` is for. Run it once per working directory:

```bash
swmm_cli attach 14328
# All subsequent commands in this directory pick up .swmm/session.json automatically
swmm_cli element get --type junction --id J1
swmm_cli simulate run
```

### Pattern 3 — full session setup workflow

`attach` sits in the middle of the standard session setup sequence:

```bash
# Step 1: check if SWMM is already running
swmm_cli process list

# Step 2a: if not running, launch and wait for pipe
swmm_cli process launch
# Poll until available=true (pipe ready, usually 2–5 seconds)
swmm_cli process list

# Step 2b: attach whichever instance you want
swmm_cli attach 14328

# Step 3: open a model file (if none is open)
swmm_cli file info
swmm_cli file open --path "C:/Models/catchment_2024.inp"

# Step 4: proceed with element and simulation commands
swmm_cli element list --type conduit
swmm_cli simulate run
```

## Gotchas and caveats for agents

- **Exit codes**: `attach` always exits 0. It does not validate that the supplied PID is a real or running `Epaswmm5.exe` process. It only writes the integer to `.swmm/session.json`. A subsequent command (e.g., `file info`) will exit 1 with a pipe error if the PID is stale or wrong.

- **Stale session**: if `Epaswmm5.exe` crashes or is closed after `attach`, the session file still contains the old PID. The next command that opens the named pipe will fail with a pipe-not-found error. Recover by running `process list`, getting the new PID, and calling `attach` again.

- **Session file location**: the file is written to `.swmm/session.json` relative to the current working directory at the time `attach` runs. If your agent changes directories between calls, subsequent commands may not find the session. Always run `swmm_cli` from a consistent working directory.

- **Multiple SWMM instances**: `attach` lets you pick which of several running instances to target. If two instances are running (PIDs 14328 and 19102), calling `swmm_cli attach 19102` locks all future commands (in that directory) to instance 19102. To switch targets, call `attach` again with the other PID — it overwrites the session file.

- **No `--pid` flag on attach itself**: unlike other commands, `attach` does not accept `--pid`. The PID is always a positional argument. `swmm_cli attach --pid 14328` will fail with a parse error.

- **Pipe availability**: `attach` does not check whether the named pipe for the given PID is available (`available: true`). Always confirm `available: true` via `process list` before attaching if you intend to immediately send commands, otherwise the first pipe-using command may fail if the SWMM process is still initialising.

- **Re-running attach is safe**: calling `attach` with a new PID simply overwrites `.swmm/session.json`. There is no "detach" command and no lock held — overwriting is the correct way to switch instances.
