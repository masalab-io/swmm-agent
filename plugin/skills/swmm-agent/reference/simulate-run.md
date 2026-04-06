# swmm_cli simulate run

Run a full SWMM simulation. **Blocks** until the engine finishes and returns the final status directly.

## Syntax

```
swmm_cli simulate run [--pid N]
```

No other flags.

## Response

```json
{"ok":true,"data":{"status":"success","message":"Run was successful.","continuity_errors":{"surface_runoff":0.0012,"flow_routing":-0.0034,"quality_routing":0.0000}}}
```

| `status` | `ok` | Meaning |
|----------|------|---------|
| `success` | true | Completed, no warnings |
| `warning` | true | Completed with warnings (results still available) |
| `error` | false | Failed — check Status Report |
| `failed` | false | System-level failure |
| `none` | false | Project data invalid |

`continuity_errors` only present when `ok: true`. EPA guidance: accept < 1%.

## Example

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5
```

## Notes specific to this command

- **Blocking**: the response is not returned until the run is complete. Do NOT poll `simulate status` after this — the result is already in the response.
- **Project must be open**: returns `{"ok":false,"error":"No project is currently open"}` if no `.inp` is loaded.
- **UI flash**: after a successful run, a Status Report window appears for ~1 second then closes. This is expected.
- **Exit code 0 even on sim failure**: the CLI exits 0 if the pipe round-trip succeeded. Check `ok` in the JSON, not the exit code.
- **Temp files overwritten**: each run deletes and recreates SWMM's temporary files.
