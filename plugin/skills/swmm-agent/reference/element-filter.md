# swmm_cli element filter

Filter a piped element list by testing one property against a value. **Must be piped from `element list` or another `element filter`** — cannot run standalone.

## Syntax

```
swmm_cli element list --type <type> | swmm_cli element filter --prop <prop> --op <op> --value <value>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--prop` | Yes | Property name (matches fields from `element get`, case-insensitive) |
| `--op` | Yes | Comparison operator (see table below) |
| `--value` | Yes | Value to compare against |

### Operators

| `--op` | Type | Matches when |
|--------|------|-------------|
| `eq` | string | equals (case-insensitive) |
| `ne` | string | does not equal |
| `contains` | string | contains substring |
| `not-contains` | string | does not contain substring |
| `starts-with` | string | starts with prefix |
| `ends-with` | string | ends with suffix |
| `lt` | numeric | < value |
| `le` | numeric | <= value |
| `gt` | numeric | > value |
| `ge` | numeric | >= value |

## Response

```json
{"ok":true,"data":{"type":"junction","ids":["J2","J4","J9"]}}
```

Same shape as `element list` output — chainable into another `element filter`.

## Examples

```bash
# Junctions above elevation 4970
swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970

# Chain filters: conduits tagged "Swale" AND longer than 200 ft
swmm_cli element list --type conduit | \
  swmm_cli element filter --prop tag --op eq --value Swale | \
  swmm_cli element filter --prop length --op gt --value 200

# Extract only the final IDs
swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970 | \
  tail -1 | jq '.data.ids'
```

## Notes specific to this command

- **Calls `element get` internally** for each ID — 100 elements = 100 pipe round-trips. Pre-filter by type to reduce the list.
- **Missing property = excluded**: if an element doesn't have the property, it's silently dropped (not an error).
- **Numeric parse failure = excluded**: for numeric operators, unparseable values are silently skipped.
- **Empty result is valid**: `{"ok":true,"data":{"type":"junction","ids":[]}}` means nothing matched.
- **Last-wins for chained filters**: each filter reads the previous filter's output, not the original full list.
