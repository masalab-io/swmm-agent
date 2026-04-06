---
name: swmm-cli
description: >
  Use for any interaction with a running SWMM model. Requires the bundled
  Epaswmm5.exe from plugin/dist/ — the standard EPA SWMM download does not have
  the named-pipe API and will not work. Triggers include: launching or connecting
  to SWMM; opening a .inp model file; listing, reading, filtering, or changing
  properties of junctions, conduits, outfalls, storage units, pumps, weirs,
  orifices, or subcatchments; adding new nodes; running or checking the status of
  a simulation; and retrieving time-series or summary results for any node, link,
  or subcatchment after a run. Commands can be chained with bash pipes for
  sequential, session-propagating workflows.
---

# swmm_cli — Master Command Reference

`swmm_cli` is the named-pipe client that communicates with the running
`Epaswmm5.exe` process. Every command outputs JSON with an `ok` boolean.
Exit code 0 = success, 1 = error.

---

## Invoking swmm_cli

Requires **Claude Code v2.1.92+**. On that version and above, `swmm_cli` is
automatically on PATH and works as a bare command.

If you get "command not found", the user needs to update Claude Code:
1. In `~/.claude/settings.json`, set `"autoUpdatesChannel": "latest"`
2. Run `claude update` in the terminal
3. Restart Claude Code

Until updated, use the full path as a fallback:
`"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe"`. Do **not** glob or search for it.

---

## Session setup — two approaches

### Approach A — Pipeline mode (recommended)

Chain commands with bash `|`. The session line `{"kind":"session","pid":N}`
flows automatically through every stage; no `--pid`, no session file needed.

```bash
# Full workflow in one pipeline: launch → open → simulate → results
swmm_cli process launch | \
  swmm_cli file open --path "/path/to/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

Each consumer stage **blocks** until the previous stage finishes (drain-to-EOF
semantics), so the commands run sequentially even though bash starts all
processes simultaneously.

### Approach B — Attach + explicit --pid (classic)

```bash
# 1. Check if SWMM is already running
swmm_cli process list

# 2a. If no process found — launch it, then wait for the pipe to become available
swmm_cli process launch
# repeat process list until available=true (pipe is ready, ~2–5 seconds)

# 2b. If process found but not attached yet — save the session
swmm_cli attach <pid>

# 3. Verify a file is open before touching elements or results
swmm_cli file info
```

Once `attach` has been run, all subsequent commands resolve the PID
automatically from `.swmm/session.json` — no `--pid` flag needed.

**Reliability note**: the session file is written to `.swmm/session.json`
relative to the working directory at the time `attach` runs. Because the shell
CWD can vary between Bash tool calls, the session file is often not found in
subsequent calls. The most reliable approach is to use Pipeline mode above, or
pass `--pid` explicitly on every command.

---

## PID resolution — how swmm_cli finds the target process

Every command that talks to SWMM needs a process PID. It resolves in this
order (first match wins):

| Priority | Source | How |
|----------|--------|-----|
| 1 | `--pid <N>` flag | Explicit on the command line |
| 2 | Piped stdin | `{"kind":"session","pid":N}` line found in stdin (pipeline mode) |
| 3 | Environment | `SWMM_PID` env var |
| 4 | Session file | `.swmm/session.json` in CWD (written by `swmm_cli attach`) |
| 5 | Auto-discovery | Exactly one `Epaswmm5.exe` running — use it |
| 6 | Error | Throw — no instance found or multiple instances |

**Pipeline mode (priority 2)**: when commands are connected with `|`, each
consumer drains all stdin to EOF (re-emitting every line), extracts the session
PID, then appends its own output. This gives sequential execution and automatic
PID propagation with no flags required.

**Classic mode (priority 4)**: after the user runs `swmm_cli attach <pid>`,
priority 4 resolves automatically. Omit `--pid` unless you are working with
multiple simultaneous SWMM instances.

---

## Command inventory

### process — manage the SWMM process

```
swmm_cli process launch
swmm_cli process list
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `process launch` | Launch bundled `Epaswmm5.exe` from `plugin/dist/` | `{"kind":"session","pid":N}` — session line, pipeable |
| `process list` | List all running Epaswmm5 processes | `{ok, processes:[{pid, pipe, available}]}` |

### attach — persist a session

```
swmm_cli attach <pid>
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `attach <pid>` | Write PID to `.swmm/session.json`; enables --pid-less calls | `{"kind":"session","pid":N}` — session line, pipeable |

### file — open and inspect the model file

```
swmm_cli file info  [--pid N]
swmm_cli file open  --path <path>  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `file info` | Metadata of currently open `.inp` file | `{ok, path, ...}` |
| `file open` | Open a `.inp` model file in the running instance | `{ok}` |

### element — read, write, add, and filter model elements

```
swmm_cli element list   --type <type>                                    [--pid N]
swmm_cli element get    --type <type>  --id <id>                         [--pid N]
swmm_cli element set    --type <type>  --id <id>  --prop <p> --value <v> [--pid N]
swmm_cli element add    --type <type>  --id <id>  [--x N]  [--y N]      [--pid N]
swmm_cli element filter --prop <prop>  --op <op>  --value <v>            [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `element list` | List all element IDs of a given type | `{ok, data:{type, ids:[...]}}` |
| `element get` | Get all properties of one element | `{ok, data:{...}}` |
| `element set` | Set one property on an element | `{ok}` |
| `element add` | Add a new node element (junction/outfall/divider/storage) | `{ok}` |
| `element filter` | Filter a piped element list by a property condition | `{ok, data:{type, ids:[...]}}` |

`element filter` must be piped from `element list` or a prior `element filter`.
Supported `--op` values: `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `contains`,
`not-contains`, `starts-with`, `ends-with`. Numeric operators (`lt`/`le`/`gt`/`ge`)
parse both sides as double; string operators are case-insensitive.

Valid `--type` values: `junction`, `outfall`, `divider`, `storage`, `conduit`,
`pump`, `orifice`, `weir`, `outlet`, `subcatchment`

### simulate — run and monitor the simulation

```
swmm_cli simulate run     [--pid N]
swmm_cli simulate status  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `simulate run` | Run simulation — **blocks** until the engine finishes, returns final status | `{ok, data:{status, message, continuity_errors}}` |
| `simulate status` | Query the status of the most recent run | `{ok, status}` — status values: `none` `running` `success` `warning` `error` `failed` |

### results — retrieve output after a simulation

```
swmm_cli results get      --type <type>  --id <id>  --variable <var>  [--pid N]
swmm_cli results summary  --type <type>  --id <id>                    [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `results get` | Full time-series for one element/variable | `{ok, data:[{time, value},...]}` |
| `results summary` | Max/min/avg across all variables for one element | `{ok, data:{...}}` |

Valid `--type` for results: `junction`, `outfall`, `divider`, `storage`,
`conduit`, `pump`, `orifice`, `weir`, `outlet`, `subcatchment`

**Important**: results commands require the element subtype, not a category
name. `node` and `link` are **not** valid — passing them returns an error.

---

## Pipeline mode — chaining commands with bash pipes

Commands can be connected with `|` to build full workflows where the session
PID propagates automatically and each stage runs only after the previous one
finishes.

### How it works

**Producers** (`process launch`, `attach`) emit one line:
```json
{"kind":"session","pid":12345}
```

**Consumers** (all other commands) on startup:
1. Drain all stdin to EOF, re-emitting every line verbatim.
2. Extract the PID from the `{"kind":"session",...}` line.
3. Use that PID for the pipe call, then append their own JSON result line.

Because step 1 blocks until stdin closes (upstream exits), each stage runs
sequentially even though bash starts all processes simultaneously.

### Full pipeline examples

```bash
# Launch → open → run → summarise results
swmm_cli process launch | \
  swmm_cli file open --path "/path/to/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

```bash
# Launch → open → list → filter by elevation → filter by tag
swmm_cli process launch | \
  swmm_cli file open --path "/path/to/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970 | \
  swmm_cli element filter --prop tag --op eq --value Main
```

### Output stream

Every stage appends its output to the stream. The terminal shows all lines from
all stages (session line + each command's result). To see only the final
result, pipe through `tail -1` or filter with `jq` on the last line.

### element filter operator reference

| Operator | Type | Matches when |
|----------|------|-------------|
| `eq` | string | value equals (case-insensitive) |
| `ne` | string | value does not equal |
| `contains` | string | value contains substring |
| `not-contains` | string | value does not contain substring |
| `starts-with` | string | value starts with prefix |
| `ends-with` | string | value ends with suffix |
| `lt` | numeric | value < threshold |
| `le` | numeric | value ≤ threshold |
| `gt` | numeric | value > threshold |
| `ge` | numeric | value ≥ threshold |

---

## Loading detailed documentation

Each command has a reference file with full parameter tables, chaining
examples, and agent gotchas. Read it before using that command:

```
${CLAUDE_PLUGIN_ROOT}/skills/swmm-cli/reference/<command>.md
```

Reference file names:

| Command | Reference file |
|---------|---------------|
| `process launch` | `process-launch.md` |
| `process list` | `process-list.md` |
| `attach` | `attach.md` |
| `file info` | `file-info.md` |
| `file open` | `file-open.md` |
| `element list` | `element-list.md` |
| `element get` | `element-get.md` |
| `element set` | `element-set.md` |
| `element add` | `element-add.md` |
| `element filter` | `element-filter.md` |
| `simulate run` | `simulate-run.md` |
| `simulate status` | `simulate-status.md` |
| `results get` | `results-get.md` |
| `results summary` | `results-summary.md` |

If a reference file does not exist yet, proceed using the summary above.
