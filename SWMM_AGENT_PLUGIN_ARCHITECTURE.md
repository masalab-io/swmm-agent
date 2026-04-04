# SWMM Agent — Architecture

## Goal

Enable AI agents (Claude Code or any bash-capable agent) to control the EPA SWMM 5.2.4 GUI
programmatically — reading model data, editing element properties, running simulations, and
retrieving results.

---

## Approach

Add new Delphi source files to the existing SWMM GUI project. Compile the project normally.
The resulting `Epaswmm5.exe` is a drop-in replacement for the official EPA binary — identical
in every way except it also starts a named pipe server on launch that accepts JSON commands.

No DLL injection. No loader. No runtime tricks. Just a recompiled exe.

Users download the source, build once with Delphi Community Edition (free), and replace
their `Epaswmm5.exe`. They keep using SWMM exactly as before.

---

## Architecture

```
AI Agent (Claude Code / Agent SDK)
    │
    │  bash: swmm_cli.py <command> [args] --pid <pid>
    ▼
swmm_cli.py  (thin Python CLI client)
    │
    │  JSON over Windows Named Pipe: \\.\pipe\swmm_agent_{PID}
    ▼
SwmmAgentAPI.pas  (compiled into Epaswmm5.exe)
    │
    │  direct in-process Delphi calls
    ▼
Project.GetNode(...)  /  MainForm.MnuProjectRunSimulationClick(nil)
```

---

## New Files (do not modify existing files)

All new code lives in `swmm524_gui/Epaswmm5/Agent/`:

| File | Purpose |
|---|---|
| `SwmmNamedPipe.pas` | Named pipe server — background thread, listens for JSON commands |
| `SwmmAgentAPI.pas` | API handlers — parses commands, calls SWMM internals, returns JSON |

To wire them in, add both units to the `uses` clause in `Epaswmm5.dpr` (the project file).
The `initialization` section in `SwmmAgentAPI.pas` starts the pipe server thread automatically
when SWMM launches — no other changes to existing files required.

---

## Named Pipe Protocol

- Pipe name: `\\.\pipe\swmm_agent_{PID}`
- One pipe per running SWMM instance (supports multiple open windows)
- Newline-delimited JSON: one JSON object per request, one JSON object per response
- Synchronous: client sends request, waits for response, pipe stays open

**Request format:**
```json
{"cmd": "element.get", "type": "junction", "id": "J1"}
```

**Response format:**
```json
{"ok": true, "data": {"id": "J1", "invert_elev": "10.5", "max_depth": "3.0", "x": 1000.0, "y": 2000.0}}
{"ok": false, "error": "Node J1 not found"}
```

---

## Commands (Phase 1 — 3 functions)

| Command | Action |
|---|---|
| `element.get` | Look up node by ID, return properties as JSON |
| `element.set` | Write a single property value to a node |
| `simulate.run` | Call `MainForm.MnuProjectRunSimulationClick(nil)`, return run status |

---

## Commands (Full)

### Process
```bash
swmm_cli.py process list                          # list all running SWMM instances
```

### File
```bash
swmm_cli.py file open   --pid <pid> --path model.inp
swmm_cli.py file save   --pid <pid>
swmm_cli.py file save-as --pid <pid> --path new.inp
```

### Element
```bash
swmm_cli.py element list   --pid <pid> --type junction
swmm_cli.py element get    --pid <pid> --type junction --id J1
swmm_cli.py element set    --pid <pid> --type junction --id J1 --prop invert_elev --value 10.5
swmm_cli.py element add    --pid <pid> --type junction --id J2 --x 1000 --y 2000
swmm_cli.py element delete --pid <pid> --type junction --id J1
```

### Simulation
```bash
swmm_cli.py simulate run    --pid <pid>
swmm_cli.py simulate wait   --pid <pid> --timeout 300
swmm_cli.py simulate status --pid <pid>
```

### Results
```bash
swmm_cli.py results get     --pid <pid> --type node --id J1 --variable depth
swmm_cli.py results summary --pid <pid>
```

### View
```bash
swmm_cli.py view screenshot --pid <pid> --out snap.png
swmm_cli.py view status-bar --pid <pid>
```

---

## Delphi Internals Used

| Command | Delphi access |
|---|---|
| `element.get` | `Project.FindNode(id, ntype, idx)` → `Project.GetNode(ntype, idx)` → `.ID`, `.X`, `.Y`, `.Data[NODE_INVERT_INDEX]` |
| `element.set` | same lookup → `node.Data[prop_index] := value` |
| `element.list` | iterate `Project.Lists[type]` |
| `simulate.run` | `MainForm.MnuProjectRunSimulationClick(nil)` |
| `simulate.status` | read `RunStatus` global (`TRunStatus` enum) |
| `results.get` | read binary `.out` file via `Uoutput.pas` logic |

Key constants (from `Uproject.pas`):
- `NODE_INVERT_INDEX = 7`
- `JUNCTION_MAX_DEPTH_INDEX = 8`
- `CONDUIT_LENGTH_INDEX = 7`
- `CONDUIT_ROUGHNESS_INDEX = 8`

---

## Two Ways Agents Use This

### 1. Claude Code Plugin (`plugin/`)

Engineers using Claude Code interactively. Skills auto-invoke `swmm_cli` via the Bash tool.
`swmm_cli` is on PATH via the plugin's `bin/` directory.

```
/swmm-agent:attach        ← one-time setup
[Claude auto-uses skills mid-task]
```

### 2. Agent SDK App (`agent/`)

Programmatic / automated use. A Python script drives `claude-opus-4-6` with the Bash tool
and a system prompt describing the available `swmm_cli` commands.

```bash
python agent/swmm_agent.py "Run a sensitivity study on J1 invert elevation"
```

---

## Build Instructions

1. Install **Delphi Community Edition** (free — [embarcadero.com](https://www.embarcadero.com/products/delphi/starter))
2. Open `swmm524_gui/Epaswmm5/Epaswmm5.dproj`
3. Build → `swmm524_gui/Epaswmm5/Build/Win32/Epaswmm5.exe`
4. Replace your existing `Epaswmm5.exe` with the compiled one

The pipe server starts automatically when SWMM launches. No additional setup.

---

## What This Is NOT

- Not modifying any existing `.pas` files
- Not DLL injection
- Not a separate loader process
- Not a commercial product — open source, build from source
