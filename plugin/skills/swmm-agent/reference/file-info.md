# swmm_cli file info

Return the path of the currently open `.inp` file. Use to verify the correct model is loaded.

## Syntax

```
swmm_cli file info [--pid N]
```

## Response

```json
{"ok":true,"data":{"file":"C:\\Models\\catchment.inp"}}
```

`data.file` is empty string `""` if no file is open.

## Example

```bash
swmm_cli file info
# If empty, open a file:
swmm_cli file open --path "C:/Models/model.inp"
```

## Notes specific to this command

- **Read-only**: no side effects. Safe to call at any time, including during a simulation.
- **Empty file is not an error**: `{"ok":true,"data":{"file":""}}` means SWMM is running but no project is loaded. Follow up with `file open`.
