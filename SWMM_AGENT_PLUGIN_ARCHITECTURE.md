# SWMM Agent Plugin — Architecture Document

## Goal

Enable AI agents (Claude Code or any bash-capable agent) to control the EPA SWMM 5.2.4 GUI desktop application programmatically — reading model data, editing element properties, running simulations, and retrieving results — without modifying the official SWMM installation.

---

## High-Level Architecture

```
AI Agent (Claude Code)
    │
    │  bash: swmm_cli.py <command> [args] --pid <pid>
    ▼
swmm_cli.py  (thin Python CLI client)
    │
    │  JSON over Windows Named Pipe: \\.\pipe\swmm_agent_{PID}
    ▼
swmm_plugin.dll  (Delphi DLL, injected into epaswmm5.exe)
    │
    │  direct in-process Delphi calls
    ▼
Project.GetNode(...).Data[prop] := value
MainForm.MnuProjectRunSimulationClick(nil)
```

The agent never knows about named pipes or Delphi internals. It calls `swmm_cli.py` via bash and receives JSON back — exactly like calling `git` or `curl`.

---

## Components

### 1. `swmm_plugin.dll` — Delphi DLL (in-process)

- Written in **Embarcadero Delphi 10.4** (same version as SWMM GUI)
- Injected into the running `epaswmm5.exe` process by the loader
- Starts a **Windows Named Pipe server** on startup: `\\.\pipe\swmm_agent_{PID}`
- Listens for JSON commands, executes them directly against SWMM internals, returns JSON responses
- Has direct access to:
  - `Project` — the live `TProject` object with all model data in memory
  - `MainForm` — can call any menu handler (e.g. `MnuProjectRunSimulationClick`)
  - All element lists, properties, themes, results

**Initialization:**
```pascal
// Exported function called by the loader after injection
procedure swmm_plugin_init(AppHandle: THandle; MainFormPtr: Pointer); stdcall;
```

### 2. `swmm_agent_loader.exe` — Delphi or C injector

- Small standalone executable
- Attaches to a running `epaswmm5.exe` process
- Injects `swmm_plugin.dll` via `CreateRemoteThread` + `LoadLibrary`
- Exits immediately — plugin stays resident in SWMM
- Can target a specific PID or auto-detect SWMM windows

### 3. `swmm_cli.py` — Python CLI client

- Thin named pipe client (~300-500 lines)
- Serializes CLI arguments to JSON, sends to plugin, prints response to stdout
- Exit code 0 = success, 1 = error
- All output is JSON

**Dependencies:**
```
pywin32   — named pipe client (win32pipe, win32file)
click     — CLI argument parsing
```

---

## User Workflow

```
1. Open SWMM normally (unchanged, unmodified installation)
2. Run swmm_agent_loader.exe  (or use the SWMM Tools menu entry)
3. Plugin is now resident — named pipe server is running
4. swmm_cli.py commands now work
```

### Bootstrap via SWMM's Built-in Tools Menu

SWMM has a built-in external tools system (Tools → Tool Options). Register the loader there so users can activate the plugin with one click inside SWMM:

```
Tool Name:    SWMM Agent
Program:      C:\swmm-agent\swmm_agent_loader.exe
Parameters:   (empty)
Disable SWMM: unchecked (loader exits immediately, SWMM keeps running)
```

---

## Multiple Instances

When multiple SWMM windows are open, the agent first lists all instances and targets by PID:

```bash
# List all running SWMM instances
swmm_cli.py process list
```
```json
[
  {"index": 0, "pid": 12345, "title": "model_v1.inp - SWMM 5", "file": "C:/models/model_v1.inp"},
  {"index": 1, "pid": 67890, "title": "model_v2.inp - SWMM 5", "file": "C:/models/model_v2.inp"}
]
```

All subsequent commands take `--pid`:
```bash
swmm_cli.py simulate run --pid 67890
```

Each SWMM instance has its own named pipe (`swmm_agent_12345`, `swmm_agent_67890`).

---

## CLI Command Reference

### Process Management
```bash
swmm_cli.py process list                          # list all running SWMM instances
swmm_cli.py process launch --path model.inp       # launch new SWMM with file
```

### File Operations
```bash
swmm_cli.py file open   --pid <pid> --path model.inp
swmm_cli.py file save   --pid <pid>
swmm_cli.py file save-as --pid <pid> --path new_model.inp
swmm_cli.py file reload --pid <pid>               # close and reopen current file
```

### Element Operations
```bash
swmm_cli.py element list         --pid <pid> --type junction
swmm_cli.py element get          --pid <pid> --type junction --id J1
swmm_cli.py element set          --pid <pid> --type junction --id J1 --prop invert_elev --value 10.5
swmm_cli.py element add          --pid <pid> --type junction --id J2 --x 1000 --y 2000
swmm_cli.py element delete       --pid <pid> --type junction --id J1
```

**Element types:** `junction`, `outfall`, `storage`, `divider`, `conduit`, `pump`, `orifice`, `weir`, `outlet`, `subcatchment`, `raingage`

### Simulation
```bash
swmm_cli.py simulate run    --pid <pid>
swmm_cli.py simulate wait   --pid <pid> --timeout 300    # blocks until complete
swmm_cli.py simulate status --pid <pid>
```

### Results
```bash
swmm_cli.py results get --pid <pid> --type node --id J1 --variable depth
swmm_cli.py results summary --pid <pid>           # reads .rpt file directly
```

### Map / Visual
```bash
swmm_cli.py view screenshot   --pid <pid> --out /tmp/swmm.png
swmm_cli.py view theme-set    --pid <pid> --layer nodes --variable depth --ramp "Blue-Red"
swmm_cli.py view status-bar   --pid <pid>          # read status bar text
```

---

## What the Plugin Does Internally

| CLI Command | Plugin Action |
|---|---|
| `element get` | `Project.GetNode(type, idx).Data[prop_index]` |
| `element set` | Direct memory write to `TNode.Data[prop_index]` |
| `element list` | Iterate `Project.Lists[type]` |
| `simulate run` | Call `MainForm.MnuProjectRunSimulationClick(nil)` |
| `simulate status` | Read `RunStatus` global variable |
| `view theme-set` | Call map viewer theme procedures directly |
| `results get` | Read binary `.out` file via `Uoutput.pas` logic |

---

## Why Not pywinauto?

| | pywinauto | This plugin |
|---|---|---|
| Element property edit | INP file round-trip | Direct in-memory |
| Theme / visual change | Dialog navigation (fragile) | Direct property set |
| Speed | Slow (UI timing delays) | Instant |
| Reliability | Fragile (dialogs, timing) | Solid |
| Needs SWMM source? | No | No (injection, no source mod) |

---

## Claude API Integration (Optional)

`claude-opus-4-6` with vision can be used for two purposes:

**1. Screenshot verification after actions:**
```bash
swmm_cli.py view screenshot --pid 12345 --out /tmp/swmm.png
# → send to Claude API: "Did the file open? Any blocking dialog?"
# → returns {"success": true, "dialog": null}
```

**2. Natural language → command routing:**
```
User: "Add a junction at the river crossing"
→ Claude API (adaptive thinking) plans the sequence:
  1. swmm_cli.py view screenshot
  2. swmm_cli.py element add --type junction ...
  3. swmm_cli.py view screenshot → verify
```

Enable with `--verify` flag on any command:
```bash
swmm_cli.py file open --path model.inp --pid 12345 --verify
# → automatically takes screenshot + calls Claude API to confirm success
```

---

## Skill Files Structure

Document each compound operation as a markdown skill file so Claude Code can find and use the right command sequences:

```
skills/swmm-gui/
├── _commands.md          # Full CLI reference (auto-generated from --help)
├── launch.md             # How to start/attach to SWMM + load plugin
├── open-model.md         # Open INP file
├── run-simulation.md     # Run + wait for completion + get summary
├── add-junction.md       # Add junction: element add → set properties
├── add-conduit.md        # Add conduit connecting two nodes
├── edit-properties.md    # Edit element properties
├── read-results.md       # Get simulation results for elements
└── set-theme.md          # Change map visualization theme
```

---

## Tech Stack

| Component | Technology | License |
|---|---|---|
| `swmm_plugin.dll` | Delphi 10.4 Community Edition | Free for open source |
| `swmm_agent_loader.exe` | Delphi or C | Free |
| `swmm_cli.py` | Python 3.x + pywin32 + click | MIT |
| SWMM GUI source | Object Pascal (EPA) | Public domain |
| SWMM engine | `swmm5.dll` C API | Public domain |

**Delphi Community Edition** is free for open source projects (OSI-approved license). No paid license required.

---

## What You Are NOT Doing

- **Not modifying** `epaswmm5.exe` or any EPA files — users keep their official SWMM installation
- **Not rewriting** the SWMM GUI in C# (estimated 1-2 years, not worth it for this goal)
- **Not using pywinauto** (fragile, slow, requires dialog navigation)
- **Not requiring** an MCP server (too token-heavy for agents)

---

## Open Questions / Future Work

- Code-sign the binaries to avoid antivirus false positives (DLL injection is a common malware technique — signing + documentation helps)
- Define the full property index mapping for all element types (from `Uproject.pas` `objprops.txt`)
- Decide named pipe protocol: newline-delimited JSON vs. length-prefixed frames
- Consider a simple HTTP server alternative to named pipes (easier to debug, language-agnostic)
