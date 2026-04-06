# swmm_cli file open

Open a `.inp` model file in a running SWMM instance.

## Syntax

```
swmm_cli file open --path <path> [--pid N]
```

| Flag | Required | Description |
|------|----------|-------------|
| `--path` | Yes | Full or relative path to the `.inp` file |
| `--pid` | No | Target PID (usually resolved via pipeline) |

## Response

```json
{"ok":true,"file":"C:\\models\\example.inp"}
```

On failure: `{"ok":false,"error":"File not found: ..."}` (exit 1).

## Example

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/models/model.inp" | \
  swmm_cli simulate run
```

## Notes specific to this command

- **Clears previous model**: any unsaved changes to a previously open file are discarded without prompt.
- **Synchronous**: blocks until the file is fully loaded. Large models may take a few seconds.
- **Dismisses welcome screen**: if SWMM was freshly launched, the welcome dialog is closed automatically.
- **Path is converted to absolute**: relative paths work, but use absolute paths to avoid ambiguity.
