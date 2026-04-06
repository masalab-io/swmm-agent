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

cli/                      .NET named pipe client
  swmm_cli               CLI tool agents use via bash
  requirements.txt        .NET 8, no runtime dependencies

plugin/                   Claude Code plugin
  .claude-plugin/
    plugin.json
  dist/                   Pre-built binaries shipped with the plugin
    Epaswmm5.exe          Augmented SWMM exe (compiled from this repo)
    runswmm.exe           SWMM dependency
    swmm5.dll             SWMM engine
  bin/                    swmm_cli goes here (added to PATH when plugin active)
  skills/swmm-agent/      Master skill + per-command reference docs

agent/                    Agent SDK standalone app
  swmm_agent.py           Entry point for programmatic use
  requirements.txt        anthropic>=0.40.0

.claude-plugin/           Claude Code marketplace definition
  marketplace.json
```

---

## Distribution

The 3 files in `plugin/dist/` are the distributable binaries. They are tracked in git
(not gitignored). After every build, copy the new exe from
`swmm524_gui/Epaswmm5/Build/Win32/` into `plugin/dist/` and commit.

Users never download files manually. `swmm_cli process launch` runs `Epaswmm5.exe`
directly from `plugin/dist/` — no copy to the user's SWMM folder required.

## The Rule: Never Modify Existing Files

All new code goes in `swmm524_gui/Epaswmm5/Agent/` as new `.pas` files.

The only existing file that gets a minimal touch is `Epaswmm5.dpr` — to add the new
units to the `uses` clause. No other existing `.pas` files are changed.

---

## Architecture Summary

```
AI Agent
  → bash: swmm_cli <cmd> --pid <pid>
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

Phase 1 complete — the named-pipe API and CLI are fully implemented:
- All 13 `swmm_cli` commands are working (`process`, `attach`, `file`, `element`, `simulate`, `results`)
- `SwmmAgentAPI.pas` and `SwmmNamedPipe.pas` are compiled into `Epaswmm5.exe`
- Claude Code plugin ships in `plugin/` with master skill and per-command reference docs

Next: Phase 2 — additional element types, write-back for links/subcatchments, geometry layer.
