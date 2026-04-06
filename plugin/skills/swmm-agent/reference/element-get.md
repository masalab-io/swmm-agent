# swmm_cli element get

Read all properties of a single element by type and ID.

## Syntax

```
swmm_cli element get --type <type> --id <id> [--pid N]
```

## Response — varies by type

**Junction:**
```json
{"id":"J5","type":"junction","x":1200.0,"y":850.0,"comment":"","tag":"","invert_elev":"10.5","max_depth":"3.0","init_depth":"0","surcharge_depth":"0","ponded_area":"0"}
```

**Conduit:**
```json
{"id":"C3","type":"conduit","comment":"","tag":"","inlet_node":"J1","outlet_node":"J5","shape":"CIRCULAR","geom1":"1.5","length":"120.0","roughness":"0.013","in_offset":"0","out_offset":"0",...}
```

**Outfall:** includes `invert_elev`, `tide_gate`, `route_to`, `outfall_type`, `stage_data`

**Subcatchment:** includes `rain_gage`, `outlet`, `area`, `imperv`, `width`, `slope`

See `element set` reference for full property lists per type.

## Example

```bash
# Read one junction
swmm_cli element get --type junction --id J5

# Extract a specific field
swmm_cli element get --type junction --id J5 | jq '.invert_elev'
```

## Notes specific to this command

- **All numeric values are strings**: `"10.5"` not `10.5`. Use `jq`'s `tonumber` for arithmetic.
- **Output is the element object directly** — not wrapped in `{"ok":true,"data":{...}}`. Parse with `jq '.invert_elev'`, not `jq '.data.invert_elev'`.
- **ID is case-sensitive**: `J5` and `j5` are different. Use `element list` to get exact IDs.
- **No partial reads**: returns all properties at once. Use `jq` to extract what you need.
- **Do not use this in a loop to filter** — use `element list | element filter` instead.
