# swmm_cli process list

List all running `Epaswmm5.exe` processes and their pipe availability.

## Syntax

```
swmm_cli process list
```

No flags. No PID resolution — scans all processes directly.

## Response

```json
{"ok":true,"processes":[{"pid":12480,"pipe":"\\\\.\\pipe\\swmm_agent_12480","available":true}]}
```

| Field | Description |
|-------|-------------|
| `processes[].pid` | Windows process ID |
| `processes[].available` | `true` when the named pipe is ready to accept commands |

Empty `processes: []` means no SWMM is running — not an error.

## Example

```bash
# Check if SWMM is running before launching
swmm_cli process list
```

## Notes specific to this command

- **`available: false`** means the pipe server is still starting (2-5s after launch). Poll until `true` before sending commands.
- **No prerequisites**: can be called at any time, even before SWMM is launched.
- **Multiple entries**: when more than one SWMM instance is running, all appear in the array. Pick the correct PID explicitly.
