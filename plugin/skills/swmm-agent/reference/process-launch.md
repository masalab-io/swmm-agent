# swmm_cli process launch

Launch the bundled `Epaswmm5.exe` from `plugin/dist/`. First step of any new SWMM session.

## Syntax

```
swmm_cli process launch
```

No flags. The exe path is resolved from `$CLAUDE_PLUGIN_ROOT/dist/Epaswmm5.exe` automatically.

## Response

```json
{"kind":"session","pid":18432}
```

The `kind: "session"` line is picked up by all downstream pipeline stages — no `--pid` needed.

On failure: `{"ok":false,"error":"Epaswmm5.exe not found..."}` (exit 1).

## Example

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

## Notes specific to this command

- **No PID resolution**: this command creates a new process, it does not target an existing one.
- **Pipe not immediately ready**: the named pipe takes 2-5s to initialise after launch. In pipeline mode this is handled automatically. In separate calls, poll `process list` until `available: true`.
- **Each call starts a new instance**: calling `process launch` twice creates two SWMM processes. Auto-discovery (PID resolution step 5) will fail with "Multiple SWMM instances running" if you have more than one.
- **Windows only**: SWMM is a GUI app. The window will appear on screen. No headless mode.
- **Standard EPA binary won't work**: only the `plugin/dist/` build has the named-pipe API.
