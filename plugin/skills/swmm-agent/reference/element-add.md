# swmm_cli element add

Add a new node element to the open model.

## Syntax

```
swmm_cli element add --type <type> --id <id> [--x <x>] [--y <y>] [--pid N]
```

| Flag | Required | Description |
|------|----------|-------------|
| `--type` | Yes | `junction`, `outfall`, `divider`, or `storage` only |
| `--id` | Yes | Unique element ID (case-sensitive) |
| `--x`, `--y` | No | Map coordinates (default: 0, 0) |

**Links and subcatchments are not supported** by `element add`.

## Response

```json
{"ok":true}
```

On failure: `{"ok":false,"error":"Element 'J5' already exists"}`.

## Example

```bash
swmm_cli element add --type junction --id J10 --x 1200.0 --y 850.0
swmm_cli element set --type junction --id J10 --prop invert_elev --value 45.5
swmm_cli element get --type junction --id J10
```

## Notes specific to this command

- **All properties default to zero**: always follow up with `element set` to configure invert elevation, max depth, etc.
- **Duplicate IDs**: returns error. Check `element list` first if the ID may exist.
- **No undo**: the model is mutated directly. Reopen the `.inp` file to revert.
- **Coordinates are visual only**: `--x`/`--y` affect map display, not hydraulics.
