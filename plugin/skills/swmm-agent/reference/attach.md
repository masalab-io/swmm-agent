# swmm_cli attach

Save a PID to `.swmm/session.json` so subsequent commands in the same working directory resolve it automatically. Rarely needed when using pipeline mode.

## Syntax

```
swmm_cli attach <pid>
```

One positional argument (the PID). No `--pid` flag — unlike other commands.

## Response

```json
{"kind":"session","pid":14328}
```

Also pipeable — can start a pipeline just like `process launch`.

## Example

```bash
swmm_cli attach 14328
swmm_cli file info          # --pid not needed
swmm_cli element list --type junction
```

## Notes specific to this command

- **No validation**: `attach` does not check if the PID is a real SWMM process. A wrong PID will cause pipe errors on subsequent commands.
- **Session file location**: written to `.swmm/session.json` relative to CWD at the time of the call. If CWD changes between Bash calls, subsequent commands won't find it. Prefer pipeline mode instead.
- **Re-running is safe**: calling `attach` again overwrites the session file. No "detach" needed.
- **Always exits 0**: even with a wrong PID, the write itself succeeds.
