---
name: swmm-agent
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

## Version requirement

**Requires Claude Code v2.1.92 or later.** Earlier versions do not put
plugin binaries on PATH, so `swmm_cli` will not be found as a bare command.

To check your version:
```bash
claude --version
```

If you need to update, set the updates channel to `latest` and run the update:
```bash
# In ~/.claude/settings.json, set:
#   "autoUpdatesChannel": "latest"
# Then:
claude update
```

After updating, restart Claude Code and run `/reload-plugins`.

If `swmm_cli` returns "command not found", the plugin may not be installed:
1. The user should run `/plugin install swmm-agent@masalab-io` then
   `/reload-plugins`.
2. If still not found, use the fallback: `"${CLAUDE_PLUGIN_ROOT}/bin/swmm_cli.exe"`
3. Do **not** search for the binary with `ls`, `find`, or `glob`.

---

## Rules — read these first

1. **`swmm_cli` is on PATH.** Call it directly. Never `cd` to the plugin
   directory or any other directory before calling it. Do not use relative
   paths to the binary. Do not ls or glob to locate it.
2. **Use pipeline mode for end-to-end workflows.** Chain commands with `|`
   when running a full sequence from launch to results. For interactive
   workflows where you need to inspect intermediate results, use `--pid` on
   separate calls instead.
3. **Never loop over `element get` to filter.** Use
   `element list | element filter` — it runs server-side in one pipeline.
4. **Use the specific element subtype** (`junction`, `conduit`, etc.) for
   `--type`. Never pass `node` or `link` — those are not valid.

---

## Command selection guide

| User wants to... | Use this | NOT this |
|---|---|---|
| Open a model and run a simulation | `process launch \| file open \| simulate run` (one pipeline) | Separate Bash calls for each step |
| See one element's properties | `element get --type T --id X` | — |
| Find elements matching a condition | `element list --type T \| element filter --prop P --op O --value V` | Looping `element get` in bash and filtering with Python/jq |
| Change a property | `element set --type T --id X --prop P --value V` | — |
| Get max/min summary after sim | `results summary --type T --id X` | `results get` (that's for full time-series) |
| Get full time-series after sim | `results get --type T --id X --variable V` | `results summary` (that's for scalars only) |
| Add a new node to the model | `element add --type T --id X --x N --y N` | Only nodes (junction/outfall/divider/storage) supported |

---

## Common tasks — copy these patterns

### Run a model and get results for one element

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/path/to/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

### Find all junctions matching a condition

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/path/to/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4960
```

The last line of output contains the filtered IDs. Extract with `tail -1 | jq '.data.ids'`.

### Chain multiple filters (AND logic)

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/path/to/model.inp" | \
  swmm_cli element list --type conduit | \
  swmm_cli element filter --prop length --op gt --value 200 | \
  swmm_cli element filter --prop tag --op eq --value Main
```

### Modify a property and re-run

This is an interactive workflow — use `--pid` so you can inspect the set
result before committing to a re-run.

```bash
# Step 1: launch and open
PID=$(swmm_cli process launch | swmm_cli file open --path "C:/path/to/model.inp" | tail -1 | jq '.pid')

# Step 2: inspect current value, then set
swmm_cli element get --type junction --id J5 --pid $PID
swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5 --pid $PID

# Step 3: re-run and get results
swmm_cli simulate run --pid $PID | swmm_cli results summary --type junction --id J5
```

### Get full depth time-series for a junction

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/path/to/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results get --type junction --id J5 --variable depth
```

### Inspect then filter to get details of matched elements

```bash
# Step 1: find matching IDs
IDS=$(swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4960 | \
  tail -1 | jq -r '.data.ids[]')

# Step 2: get full properties of each match
for ID in $IDS; do
  swmm_cli element get --type junction --id "$ID"
done
```

---

## Command inventory

### process — manage the SWMM process

| Command | What it does | Key output |
|---------|-------------|------------|
| `process launch` | Launch bundled Epaswmm5.exe | `{"kind":"session","pid":N}` — pipeable |
| `process list` | List running instances | `{ok, processes:[{pid, pipe, available}]}` |

### attach — persist a session (rarely needed with pipelines)

| Command | What it does |
|---------|-------------|
| `attach <pid>` | Write PID to `.swmm/session.json` for --pid-less calls |

### file — open and inspect the model

| Command | What it does |
|---------|-------------|
| `file open --path <path>` | Open a `.inp` model file |
| `file info` | Show path of currently open file |

### element — read, write, add, and filter

| Command | What it does |
|---------|-------------|
| `element list --type <type>` | List all IDs of a type |
| `element get --type <type> --id <id>` | Get all properties of one element |
| `element set --type <type> --id <id> --prop <p> --value <v>` | Set one property |
| `element add --type <type> --id <id> [--x N] [--y N]` | Add a new node (junction/outfall/divider/storage only) |
| `element filter --prop <p> --op <op> --value <v>` | Filter a piped element list by property. Must be piped from `element list` or another `element filter`. |

**Valid `--type` values:** `junction`, `outfall`, `divider`, `storage`,
`conduit`, `pump`, `orifice`, `weir`, `outlet`, `subcatchment`

**`element filter` operators:** `eq`, `ne`, `lt`, `le`, `gt`, `ge`,
`contains`, `not-contains`, `starts-with`, `ends-with`.
Numeric operators parse both sides as double; string operators are case-insensitive.

### simulate — run and monitor

| Command | What it does |
|---------|-------------|
| `simulate run` | Run simulation — **blocks** until finished, returns status + continuity errors |
| `simulate status` | Query status of most recent run (rarely needed — `simulate run` already returns it) |

### results — retrieve output after a simulation

| Command | What it does |
|---------|-------------|
| `results summary --type <type> --id <id>` | Max/min across all variables for one element |
| `results get --type <type> --id <id> --variable <var>` | Full time-series for one variable |

**Valid `--type` for results:** same as element types above.

**Valid `--variable` values:**

| Node types (junction, outfall, divider, storage) | Link types (conduit, pump, orifice, weir, outlet) | Subcatchment |
|---|---|---|
| `depth`, `head`, `volume`, `lateral_inflow`, `total_inflow`, `flooding` | `flow`, `depth`, `velocity`, `volume`, `capacity` | `rainfall`, `snow_depth`, `evaporation`, `infiltration`, `runoff`, `gw_flow`, `gw_elev`, `soil_moisture` |

---

## Pipeline mode — how it works

Commands chained with `|` form a pipeline. The session PID propagates
automatically — no `--pid` flag needed.

**Producers** (`process launch`, `attach`) emit: `{"kind":"session","pid":N}`

**Consumers** (all other commands) on startup:
1. Drain all stdin to EOF, re-emitting every line.
2. Extract the PID from the session line.
3. Execute their operation, then append their own JSON result.

Because step 1 blocks until stdin closes, each stage runs sequentially.

**Getting the final result:** every stage appends output. The terminal shows
all lines. To extract only the last command's output: `| tail -1`.

---

## PID resolution

Every command that talks to SWMM resolves the PID in this order (first match wins):

| Priority | Source |
|----------|--------|
| 1 | `--pid <N>` flag |
| 2 | `{"kind":"session","pid":N}` in piped stdin (pipeline mode) |
| 3 | `SWMM_PID` env var |
| 4 | `.swmm/session.json` in CWD (written by `attach`) |
| 5 | Auto-discovery: exactly one `Epaswmm5.exe` running |
| 6 | Error |

**In practice:** pipeline mode (priority 2) handles everything. If you must
use separate Bash calls, auto-discovery (priority 5) works when only one
SWMM instance is running.

---

## Shared gotchas

- **Pipe startup delay:** after `process launch`, the named pipe takes 2-5s
  to initialise. In pipeline mode this is handled automatically (the next
  stage blocks). In separate calls, poll `process list` until
  `available: true`.
- **`simulate run` blocks:** it returns the final status directly. Do not
  poll `simulate status` after it — the result is already in the response.
- **All numeric properties are strings:** `element get` returns values like
  `"10.5"` not `10.5`. Use `jq`'s `tonumber` if you need arithmetic.
- **Changes are in-memory only:** `element set` modifies the running model.
  Changes are lost if SWMM closes without saving.
- **Re-run after changes:** after `element set`, previous results are stale.
  Call `simulate run` again.
- **Pipeline output is multi-line:** each stage re-emits all upstream lines
  before appending its own result. The final command's result is always the
  last line. Extract it with `tail -1 | jq`.

---

## Loading detailed documentation

Each command has a reference file with parameter details and
command-specific notes. Read one before using an unfamiliar command:

```
${CLAUDE_PLUGIN_ROOT}/skills/swmm-agent/reference/<command>.md
```

| Command | File |
|---------|------|
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
