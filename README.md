# SWMM Agent

Control EPA SWMM 5.2.4 from AI agents (Claude Code, Agent SDK, or any bash-capable tool).

## Use with Claude Code

> **Requires:** Claude Code, Windows 10/11. No SWMM installation needed — the plugin ships the exe.

### 1. Add the marketplace (once)

```
/plugin marketplace add masalab-io/swmm-agent
```

### 2. Install the plugin

Run `/plugin`, go to **Discover**, find **swmm**, and choose your scope:
- **User** — available in all your projects
- **Project** — available to everyone who clones this repo
- **Local** — just for you in this repo

Or install directly:
```
/plugin install swmm@masalab-io-swmm-agent
```

### 3. Activate

```
/reload-plugins
```

### Uninstall

```
/plugin uninstall swmm@masalab-io-swmm-agent
```

To also remove the marketplace:
```
/plugin marketplace remove masalab-io/swmm-agent
```

### 4. Start a SWMM session

```bash
# Launch the bundled Epaswmm5.exe
swmm_cli process launch

# Wait ~3 seconds for the pipe to be ready, then attach
swmm_cli process list          # note the pid
swmm_cli attach <pid>

# Open your model
swmm_cli file open --path "C:\path\to\your\model.inp"
```

### 5. Ask Claude

Claude will automatically use SWMM skills whenever relevant:

> *"What's the invert elevation of junction J5?"*
> *"Raise all junction inverts in the north basin by 0.5 m and re-run the simulation"*
> *"What was the peak flow at conduit C3 in the last run?"*

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

Commands can also be chained into pipelines — the output of one command becomes the
input of the next, so multi-step workflows run in a single call:

```bash
# Chain: get all junctions → filter to a basin → set invert → run → fetch results
swmm_cli element list --pid 1234 --type junction \
  | swmm_cli element filter --prop basin --value north \
  | swmm_cli element set --prop invert_elev --value 12.5 \
  | swmm_cli simulate run \
  | swmm_cli results summary
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
