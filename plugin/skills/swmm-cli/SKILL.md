---
name: swmm-cli
description: >
  Use for any interaction with a running SWMM model. Requires the bundled
  Epaswmm5.exe from plugin/dist/ — the standard EPA SWMM download does not have
  the named-pipe API and will not work. Triggers include: launching or connecting
  to SWMM; opening a .inp model file; listing, reading, or changing properties of
  junctions, conduits, outfalls, storage units, pumps, weirs, orifices, or
  subcatchments; adding new nodes; running or checking the status of a simulation;
  and retrieving time-series or summary results for any node, link, or
  subcatchment after a run.
---

# swmm_cli — Master Command Reference

`swmm_cli` is the named-pipe client that communicates with the running
`Epaswmm5.exe` process. Every command outputs JSON with an `ok` boolean.
Exit code 0 = success, 1 = error.

---

## Invoking swmm_cli

Claude Code v2.1.92+ automatically adds the plugin `bin/` directory to PATH,
so `swmm_cli` works as a bare command. On older versions it is not on PATH.

**Always invoke using the full path via `${CLAUDE_PLUGIN_ROOT}`:**

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process list
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process launch
```

Do **not** glob or search for the exe — `${CLAUDE_PLUGIN_ROOT}` is always set
correctly by Claude Code when the plugin is active.

---

## Session setup — do this at the start of every SWMM session

Before using any element, simulate, file, or results command, ensure a SWMM
process is running and attached:

```bash
# 1. Check if SWMM is already running
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process list

# 2a. If no process found — launch it, then wait for the pipe to become available
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process launch
# repeat process list until available=true (pipe is ready, ~2–5 seconds)

# 2b. If process found but not attached yet — save the session
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" attach <pid>

# 3. Verify a file is open before touching elements or results
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" file info
```

Once `attach` has been run, all subsequent commands resolve the PID
automatically from `.swmm/session.json` — no `--pid` flag needed.

**Reliability note**: the session file is written to `.swmm/session.json`
relative to the working directory at the time `attach` runs. Because the shell
CWD can vary between Bash tool calls, the session file is often not found in
subsequent calls. The most reliable approach is to pass `--pid` explicitly on
every command rather than relying on the session file.

---

## PID resolution — how swmm_cli finds the target process

Every command that talks to SWMM needs a process PID. It resolves in this
order (first match wins):

| Priority | Source | How |
|----------|--------|-----|
| 1 | `--pid <N>` flag | Explicit on the command line |
| 2 | Piped stdin | `{"kind":"session","pid":N}` as first line |
| 3 | Environment | `SWMM_PID` env var |
| 4 | Session file | `.swmm/session.json` in CWD (written by `swmm_cli attach`) |
| 5 | Auto-discovery | Exactly one `Epaswmm5.exe` running — use it |
| 6 | Error | Throw — no instance found or multiple instances |

**Practical implication**: after the user runs `swmm_cli attach <pid>`,
priority 4 resolves automatically. Omit `--pid` unless you are working with
multiple simultaneous SWMM instances.

---

## Command inventory

### process — manage the SWMM process

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process launch
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" process list
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `process launch` | Launch bundled `Epaswmm5.exe` from `plugin/dist/` | `{ok, pid}` |
| `process list` | List all running Epaswmm5 processes | `{ok, processes:[{pid, pipe, available}]}` |

### attach — persist a session

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" attach <pid>
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `attach <pid>` | Write PID to `.swmm/session.json`; enables --pid-less calls | `{ok, pid}` |

### file — open and inspect the model file

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" file info  [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" file open  --path <path>  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `file info` | Metadata of currently open `.inp` file | `{ok, path, ...}` |
| `file open` | Open a `.inp` model file in the running instance | `{ok}` |

### element — read, write, and add model elements

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" element list  --type <type>                                   [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" element get   --type <type>  --id <id>                        [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" element set   --type <type>  --id <id>  --prop <p> --value <v> [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" element add   --type <type>  --id <id>  [--x N]  [--y N]     [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `element list` | List all elements of a given type | `{ok, elements:[...]}` |
| `element get` | Get all properties of one element | `{ok, data:{...}}` |
| `element set` | Set one property on an element | `{ok}` |
| `element add` | Add a new node element (junction/outfall/divider/storage) | `{ok}` |

Valid `--type` values: `junction`, `outfall`, `divider`, `storage`, `conduit`,
`pump`, `orifice`, `weir`, `outlet`, `subcatchment`

### simulate — run and monitor the simulation

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" simulate run     [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" simulate status  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `simulate run` | Run simulation — **blocks** until the engine finishes, returns final status | `{ok, data:{status, message, continuity_errors}}` |
| `simulate status` | Query the status of the most recent run | `{ok, status}` — status values: `none` `running` `success` `warning` `error` `failed` |

### results — retrieve output after a simulation

```
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" results get      --type <type>  --id <id>  --variable <var>  [--pid N]
"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe" results summary  --type <type>  --id <id>                    [--pid N]
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
| `simulate run` | `simulate-run.md` |
| `simulate status` | `simulate-status.md` |
| `results get` | `results-get.md` |
| `results summary` | `results-summary.md` |

If a reference file does not exist yet, proceed using the summary above.
