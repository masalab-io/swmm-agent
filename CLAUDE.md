# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

---

## What This Project Is

An open-source integration layer that gives AI agents (Claude Code, Agent SDK, or any
bash-capable tool) programmatic control over the **EPA SWMM 5.2.4 desktop GUI**.

SWMM is a Windows desktop app built in Delphi. This project adds a named pipe server
directly into the SWMM executable by compiling new Delphi source files into the existing
project. The result is a drop-in replacement `Epaswmm5.exe` that behaves identically to
the official EPA binary but also accepts JSON commands over a named pipe.

---

## Repository Layout

```
swmm524_gui/              EPA SWMM 5.2.4 source (reference — do not modify existing files)
  Epaswmm5/
    Agent/                NEW files only go here
      SwmmAgentAPI.pas    API command handlers (to be written)
      SwmmNamedPipe.pas   Named pipe server thread (to be written)
    Epaswmm5.dpr          Project file — add new units here (minimal touch)

cli/                      Python named pipe client
  swmm_cli.py             CLI tool agents use via bash
  requirements.txt        pywin32, click

plugin/                   Claude Code plugin
  .claude-plugin/
    plugin.json
  dist/                   Pre-built binaries shipped with the plugin
    Epaswmm5.exe          Augmented SWMM exe (compiled from this repo)
    runswmm.exe           SWMM dependency
    swmm5.dll             SWMM engine
  bin/                    swmm_cli goes here (added to PATH when plugin active)
  skills/                 Model-invoked skills
  commands/
    swmm-install.md       Copies dist/ files into user's SWMM install folder
    swmm-attach.md        Connects to a running SWMM instance

agent/                    Agent SDK standalone app
  swmm_agent.py           Entry point for programmatic use
  requirements.txt        anthropic, claude-agent-sdk

marketplace/              Claude Code marketplace definition
  .claude-plugin/
    marketplace.json
```

---

## Distribution

The 3 files in `plugin/dist/` are the distributable binaries. They are tracked in git
(not gitignored). After every build, copy the new exe from
`swmm524_gui/Epaswmm5/Build/Win32/` into `plugin/dist/` and commit.

Users never download files manually — `/swmm-agent:install` copies `plugin/dist/` into
their SWMM installation folder automatically.

## The Rule: Never Modify Existing Files

All new code goes in `swmm524_gui/Epaswmm5/Agent/` as new `.pas` files.

The only existing file that gets a minimal touch is `Epaswmm5.dpr` — to add the new
units to the `uses` clause. No other existing `.pas` files are changed.

---

## Architecture Summary

```
AI Agent
  → bash: swmm_cli.py <cmd> --pid <pid>
  → JSON over \\.\pipe\swmm_agent_{PID}
  → SwmmAgentAPI.pas (compiled into Epaswmm5.exe)
  → Project.GetNode() / MainForm.MnuProjectRunSimulationClick()
```

Full details: `SWMM_AGENT_PLUGIN_ARCHITECTURE.md`

---

## Key Delphi References

When writing new Delphi code, use these (from existing source — do not redefine):

- `Uglobals.pas` — `Project: TProject`, `RunStatus: TRunStatus`, `MainForm`
- `Uproject.pas` — `TProject`, `TNode`, `TLink`, `NODE_INVERT_INDEX = 7`, `JUNCTION_MAX_DEPTH_INDEX = 8`
- `Fmain.pas` — `TMainForm.MnuProjectRunSimulationClick`
- `TRunStatus` values: `rsSuccess`, `rsWarning`, `rsError`, `rsFailed`, `rsNone`

---

## Build

- Delphi Community Edition (free)
- Open `swmm524_gui/Epaswmm5/Epaswmm5.dproj`
- Build → `swmm524_gui/Epaswmm5/Build/Win32/Epaswmm5.exe`

---

## Current Status

Phase 1 — writing the first 3 API functions:
1. `element.get` — read node properties
2. `element.set` — write a node property
3. `simulate.run` — trigger simulation

Files to create: `SwmmAgentAPI.pas`, `SwmmNamedPipe.pas`
