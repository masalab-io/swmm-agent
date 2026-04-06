# swmm_cli element list

List all element IDs of a given type. Use to discover what exists before `element get`, `element set`, or `element filter`.

## Syntax

```
swmm_cli element list --type <type> [--pid N]
```

Valid `--type`: `junction`, `outfall`, `divider`, `storage`, `conduit`, `pump`, `orifice`, `weir`, `outlet`, `subcatchment`

## Response

```json
{"ok":true,"data":{"type":"junction","ids":["J1","J5","J12"]}}
```

Empty `ids: []` is valid — no elements of that type exist.

## Example — filter by property (recommended pattern)

```bash
swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4960
```

**Never** loop over `element get` to filter. Always use `element list | element filter`.

## Other examples

```bash
# Count junctions
swmm_cli element list --type junction | jq '.data.ids | length'

# List then inspect each match
IDS=$(swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 100 | \
  tail -1 | jq -r '.data.ids[]')
for ID in $IDS; do
  swmm_cli element get --type junction --id "$ID"
done
```

## Notes specific to this command

- **IDs are case-sensitive**: use the exact strings returned here when calling `element get` or `element set`.
- **Unrecognised `--type`**: exits 1. Use only the ten valid type strings.
- **A model file must be open**: call `file info` to verify before listing.
- **Output format matches `element filter` input**: the `data.type` + `data.ids` shape is exactly what `element filter` reads from stdin.
