# SWMM Agent

Control EPA SWMM 5.2.4 from AI agents (Claude Code, Agent SDK, or any bash-capable tool).

## What It Does

Adds a JSON command interface to the SWMM GUI. Once built, the SWMM executable accepts
commands over a Windows named pipe — so an AI agent can read and write model element
properties, run simulations, and retrieve results programmatically.

```bash
# Example: agent reads a junction, changes its invert elevation, runs the model
swmm_cli element get  --pid 1234 --type junction --id J1
swmm_cli element set  --pid 1234 --type junction --id J1 --prop invert_elev --value 12.5
swmm_cli simulate run --pid 1234
```

## How It Works

Two new Delphi source files are compiled into the existing SWMM project:

- `SwmmAgentAPI.pas` — handles JSON commands, calls SWMM internals directly
- `SwmmNamedPipe.pas` — runs a background thread listening on `\\.\pipe\swmm_agent_{PID}`

The resulting `Epaswmm5.exe` is a drop-in replacement for the official EPA binary.
No DLL injection. No separate loader. SWMM works exactly as before, plus the pipe server.

## Build

**Requirements:** [Delphi Community Edition](https://www.embarcadero.com/products/delphi/starter) (free)

```
1. Clone this repo
2. Open swmm524_gui/Epaswmm5/Epaswmm5.dproj in Delphi
3. Build (Ctrl+F9)
4. Run build.bat — copies binaries into plugin/dist/ and signs them
```

## Use with Claude Code

Install the plugin (includes the pre-built SWMM exe):
```
/plugin marketplace add masalab/swmm
/plugin install swmm@masalab
```

Launch SWMM and connect:
```bash
swmm_cli process launch
swmm_cli attach <pid>
```

Claude will auto-use SWMM skills when relevant to your task.

## Use Programmatically (Agent SDK)

```python
python agent/swmm_agent.py "Run a sensitivity study varying J1 invert elevation from 5 to 15m"
```

## Project Structure

```
swmm524_gui/Epaswmm5/Agent/   New Delphi source (the only thing we add to SWMM)
cli/                           .NET CLI client (swmm_cli.exe)
plugin/
  dist/                        Pre-built Epaswmm5.exe + runswmm.exe + swmm5.dll
  bin/                         swmm_cli (on PATH when plugin active)
  skills/swmm-cli/             Master skill + per-command reference docs
.claude-plugin/                Claude Code marketplace definition
agent/                         Agent SDK standalone app
```

## License

MIT. Open source — download the source, build it yourself.
The EPA SWMM source in `swmm524_gui/` is public domain.
