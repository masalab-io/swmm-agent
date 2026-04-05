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

## Session setup — do this at the start of every SWMM session

Before using any element, simulate, file, or results command, ensure a SWMM
process is running and attached:

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
swmm_cli process launch
swmm_cli process list
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `process launch` | Launch bundled `Epaswmm5.exe` from `plugin/dist/` | `{ok, pid}` |
| `process list` | List all running Epaswmm5 processes | `{ok, processes:[{pid, pipe, available}]}` |

### attach — persist a session

```
swmm_cli attach <pid>
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `attach <pid>` | Write PID to `.swmm/session.json`; enables --pid-less calls | `{ok, pid}` |

### file — open and inspect the model file

```
swmm_cli file info  [--pid N]
swmm_cli file open  --path <path>  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `file info` | Metadata of currently open `.inp` file | `{ok, path, ...}` |
| `file open` | Open a `.inp` model file in the running instance | `{ok}` |

### element — read, write, and add model elements

```
swmm_cli element list  --type <type>                                   [--pid N]
swmm_cli element get   --type <type>  --id <id>                        [--pid N]
swmm_cli element set   --type <type>  --id <id>  --prop <p> --value <v> [--pid N]
swmm_cli element add   --type <type>  --id <id>  [--x N]  [--y N]     [--pid N]
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
swmm_cli simulate run     [--pid N]
swmm_cli simulate status  [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `simulate run` | Trigger a simulation run (returns immediately) | `{ok}` |
| `simulate status` | Poll current run status | `{ok, status}` — status values: `none` `running` `success` `warning` `error` `failed` |

### results — retrieve output after a simulation

```
swmm_cli results get      --type <type>  --id <id>  --variable <var>  [--pid N]
swmm_cli results summary  --type <type>  --id <id>                    [--pid N]
```

| Command | What it does | Returns |
|---------|-------------|---------|
| `results get` | Full time-series for one element/variable | `{ok, data:[{time, value},...]}` |
| `results summary` | Max/min/avg across all variables for one element | `{ok, data:{...}}` |

Valid `--type` for results: `node`, `link`, `subcatchment`

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
