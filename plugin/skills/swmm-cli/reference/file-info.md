# swmm_cli file info

Returns the absolute path of the `.inp` file currently open in a running SWMM instance; use it to confirm that the correct model is loaded before issuing element or simulation commands.

## Syntax

```
swmm_cli file info  [--pid N]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session is active (see PID resolution below). |

`file info` takes no positional arguments and no other flags.

## Response shape

```json
{ "ok": true, "data": { "file": "C:\\Models\\catchment_2024.inp" } }
```

```json
{ "ok": false, "error": "Pipe connect timeout — is SWMM running with the agent?" }
```

```json
{ "ok": false, "error": "No running SWMM instance found — launch SWMM or specify --pid" }
```

```json
{ "ok": false, "error": "Multiple SWMM instances running — specify --pid or run: swmm_cli attach <pid>" }
```

**Success payload fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `true` on success. |
| `data` | object | Wrapper object containing the file information. |
| `data.file` | string | Absolute Windows path of the `.inp` file currently open in SWMM, as stored in SWMM's internal `InputFileName` global. Backslashes are escaped (`\\`). Empty string (`""`) if no file is open. |

**Failure payload fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `false` on failure. |
| `error` | string | Human-readable reason for failure — pipe timeout, PID resolution failure, or similar. |

## How to use it

The most common use is to verify that SWMM has the expected model loaded before you start reading elements or triggering a simulation. An empty `data.file` means SWMM is running but no project has been opened yet — follow up with `file open`.

```bash
# Attach to a running SWMM instance (run once per working directory)
swmm_cli attach 18340

# Check which file is currently open
swmm_cli file info
# Expected output:
# {"ok":true,"data":{"file":"C:\\Models\\catchment_2024.inp"}}
```

To assert the correct file is loaded before proceeding:

```bash
FILE=$(swmm_cli file info | jq -r '.data.file')
if [ "$FILE" != "C:\\Models\\catchment_2024.inp" ]; then
  swmm_cli file open --path "C:/Models/catchment_2024.inp"
fi
```

## PID resolution for this command

`file info` uses the full six-step PID resolution chain. All six steps apply:

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | `--pid N` flag | Explicit — always wins. Use when targeting a specific instance. |
| 2 | Piped stdin `{"kind":"session","pid":N}` | Relevant when chaining commands via pipes. |
| 3 | `SWMM_PID` environment variable | Useful in scripts that set the variable at session start. |
| 4 | `.swmm/session.json` in CWD | Written by `swmm_cli attach`; the normal no-flag path. |
| 5 | Auto-discovery | Succeeds only when exactly one `Epaswmm5.exe` is running. |
| 6 | Error | Thrown when no instance is found or multiple instances are running. |

If resolution fails, the CLI prints `{"ok":false,"error":"..."}` and exits with code 1. The agent should:

1. Run `swmm_cli process list` to check whether any `Epaswmm5.exe` is running.
2. If `processes` is empty, run `swmm_cli process launch` and wait until `available: true`.
3. Run `swmm_cli attach <pid>` to write the session file and avoid specifying `--pid` on every subsequent call.

## How to chain it

### Pattern 1 — pipeline mode

`file info` can sit in a pipeline as a verification step after `file open`.

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/catchment_2024.inp" | \
  swmm_cli file info
```

### Pattern 2 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli file info --pid $PID
swmm_cli element list --pid $PID --type junction
```

### Pattern 3 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 18340
swmm_cli file info   # --pid not needed
```

### Pattern 4 — sequential workflow (session setup → file open → file info → element commands)

`file info` is the verification step that sits between `file open` and the first element command. Always run it after opening a file to confirm the correct model is loaded.

```bash
# Step 1: confirm SWMM is running and the pipe is ready
swmm_cli process list
# Output: {"ok":true,"processes":[{"pid":18340,"pipe":"\\\\.\\pipe\\swmm_agent_18340","available":true}]}

# Step 2: attach (write .swmm/session.json)
swmm_cli attach 18340

# Step 3: open the target model
swmm_cli file open --path "C:/Models/catchment_2024.inp"
# Output: {"ok":true,"data":{"file":"C:\\Models\\catchment_2024.inp"}}

# Step 4: verify — file info confirms what is loaded
swmm_cli file info
# Output: {"ok":true,"data":{"file":"C:\\Models\\catchment_2024.inp"}}

# Step 5: now safe to read or modify elements
swmm_cli element list --type junction
swmm_cli element get --type junction --id J1

# Step 6: run the simulation
swmm_cli simulate run
swmm_cli simulate status   # repeat until status != "running"

# Step 7: retrieve results
swmm_cli results summary --type junction --id J1
```

## Gotchas and caveats for agents

- **Exit codes**: exits 0 when the command reaches SWMM and receives a response, even if `data.file` is an empty string (no file open). Exits 1 only when the pipe cannot be reached or PID resolution fails. Always check `ok` in the JSON, not just the exit code.

- **Empty file path**: if SWMM is running but no `.inp` file has been opened (e.g., immediately after launch), the response is `{"ok":true,"data":{"file":""}}`. An empty `data.file` is a valid success response — it is not an error. Follow up with `swmm_cli file open --path <path>` to load a model.

- **State requirements**: `Epaswmm5.exe` must be running with the named-pipe server active. The pipe becomes available a few seconds after launch. Use `swmm_cli process list` and check `available: true` before calling `file info` on a freshly started instance. If the pipe is not yet available, the command will fail with `"Pipe connect timeout — is SWMM running with the agent?"`.

- **Pipe connect timeout**: `PipeClient` waits up to 5 seconds for the named pipe to accept a connection. If SWMM is still initialising, the command will fail. Wait for `available: true` in `process list` before calling `file info`.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no `--pid`, `SWMM_PID`, or session file is present, resolution fails at step 5 with `"Multiple SWMM instances running — specify --pid or run: swmm_cli attach <pid>"`. Use `swmm_cli attach <pid>` to pin the session to one instance.

- **Path format in response**: `data.file` always uses Windows backslash notation with JSON escaping (`\\`). When comparing in bash with `jq -r`, the raw string contains single backslashes (e.g., `C:\Models\catchment_2024.inp`). Use `-r` with `jq` to strip JSON encoding before string comparison.

- **No side effects**: `file info` is read-only. It queries `InputFileName` from the running SWMM process and returns it without modifying any model state. It is safe to call at any time, including during an active simulation.

- **`file info` vs `file open` response**: both commands return `{"ok":true,"data":{"file":"..."}}` on success. The difference is that `file open` triggers a file load operation first; `file info` only reads the current state.

- **Stale session after SWMM restart**: if SWMM is restarted (new PID), the `.swmm/session.json` written by a previous `attach` call contains the old PID. `file info` will fail with a pipe error. Recover by running `process list`, getting the new PID, and calling `attach` again.
