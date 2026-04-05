# swmm_cli file open

Open a `.inp` model file in a running SWMM instance; use this command whenever an agent needs to load or switch to a specific model before inspecting elements or running a simulation.

## Syntax

```
swmm_cli file open --path <path>  [--pid N]
```

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--path` | string | Yes | Full or relative path to the `.inp` model file. Relative paths are resolved to absolute paths by the CLI before sending to SWMM. |
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Omit if a session is active (see PID resolution below). |

## Response shape

```json
{ "ok": true, "file": "C:\\models\\example.inp" }
```

```json
{ "ok": false, "error": "File not found: C:\\models\\missing.inp" }
```

```json
{ "ok": false, "error": "file.open requires \"path\" field" }
```

```json
{ "ok": false, "error": "MainForm is not available" }
```

**Success payload fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `true` on success |
| `file` | string | Absolute path of the file that was loaded, as recorded in SWMM's `InputFileName` global |

**Failure payload fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Always `false` on failure |
| `error` | string | Human-readable reason for failure |

## How to use it

Use `file open` when you know the path to a `.inp` file and want SWMM to load it. After the command succeeds, the model is fully loaded in memory and ready for `element list`, `element get`, `element set`, and `simulate run`.

```bash
# Attach to a running SWMM instance first
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli attach $PID

# Open the model file
swmm_cli file open --path "C:/models/catchment_v3.inp"

# Confirm the file loaded correctly
swmm_cli file info
```

Example success response:

```json
{ "ok": true, "file": "C:\\models\\catchment_v3.inp" }
```

## PID resolution for this command

`file open` uses the standard six-step PID resolution chain:

| Priority | Source |
|----------|--------|
| 1 | `--pid` flag on the command line |
| 2 | `{"kind":"session","pid":N}` as first line of piped stdin |
| 3 | `SWMM_PID` environment variable |
| 4 | `.swmm/session.json` in CWD (written by `swmm_cli attach`) |
| 5 | Auto-discovery — exactly one `Epaswmm5.exe` running |
| 6 | Error — no instance or multiple instances |

If resolution fails, the CLI prints `{"ok":false,"error":"..."}` and exits with code 1. The agent should run `swmm_cli process list` to confirm a process is running and then `swmm_cli attach <pid>` if it has not done so yet.

## How to chain it

### Pattern 1 — capture PID once, reuse across commands

```bash
PID=$(swmm_cli process list | jq '.processes[0].pid')
swmm_cli file open --pid $PID --path "C:/models/catchment_v3.inp"
swmm_cli element list --pid $PID --type junction
```

### Pattern 2 — session file (attach once, omit --pid everywhere)

```bash
swmm_cli attach 14528
swmm_cli file open --path "C:/models/catchment_v3.inp"   # --pid not needed
swmm_cli file info                                         # verify load
swmm_cli element list --type junction
```

### Pattern 3 — sequential workflow (launch → open → simulate)

The most common full workflow: launch SWMM, open a model, run a simulation, retrieve results.

```bash
# Launch SWMM and wait until the pipe is available
swmm_cli process launch
sleep 3
swmm_cli process list   # check available=true before proceeding

# Attach and open the model
swmm_cli attach 14528
swmm_cli file open --path "C:/models/catchment_v3.inp"
swmm_cli file info   # confirm: { "ok": true, "file": "C:\\models\\catchment_v3.inp" }

# Run and poll
swmm_cli simulate run
swmm_cli simulate status   # repeat until status != "running"

# Retrieve results
swmm_cli results summary --type node --id J1
```

## Gotchas and caveats for agents

- **Exit codes**: exit 0 on success, exit 1 on any error (file not found, SWMM not ready, PID resolution failure). Always check `ok` in the JSON rather than relying solely on exit code.

- **Path handling**: the CLI converts relative paths to absolute paths before sending the command to SWMM. However, the path must exist from SWMM's perspective — if SWMM is running as a different user or in a sandboxed context, use an absolute path to avoid ambiguity.

- **Existing model is cleared**: `file open` calls `Project.Clear` and `CloseForms` before loading the new file. Any unsaved changes to the previously open model are discarded without a prompt. Do not call `file open` if the user has unsaved manual edits that should be preserved.

- **Welcome screen dismissal**: if SWMM was freshly launched and is showing its Welcome dialog, `file open` automatically closes it after loading the file. No separate action is needed.

- **State requirements**: SWMM must be running and its named pipe must be available (`available: true` in `process list`) before this command will succeed. If the pipe is not yet available, wait and retry `process list`.

- **Timing**: `file open` is synchronous — it waits for `ReadInpFile` and `RefreshMapForm` to complete before returning. For large models (thousands of elements), this may take a few seconds. The command will not return until the file is fully loaded.

- **Multiple SWMM instances**: if more than one `Epaswmm5.exe` is running and no session file or `--pid` is supplied, resolution fails at step 5 with the error `"Multiple SWMM instances running — specify --pid or run: swmm_cli attach <pid>"`. Always use `attach` or `--pid` when running multiple instances.

- **Invalid path**: if the file does not exist, the error is `"File not found: <path>"` and the previously loaded model remains active (Project is not cleared until after the existence check passes).

- **`file` field in success response**: the `file` field reflects SWMM's internal `InputFileName` global, which is set to the absolute path passed in. Use `file info` immediately after `file open` to confirm the value if there is any doubt.
