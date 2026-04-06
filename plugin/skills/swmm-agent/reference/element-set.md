# swmm_cli element set

Set one property on a SWMM element.

## Syntax

```
swmm_cli element set --type <type> --id <id> --prop <prop> --value <value> [--pid N]
```

All flags required except `--pid`.

## Response

```json
{"ok":true}
```

On failure: `{"ok":false,"error":"Element not found: J99"}` or `{"ok":false,"error":"Unknown property: bogus_prop"}`.

## Settable properties by type

**junction**: `invert_elev`, `max_depth`, `init_depth`, `surcharge_depth`, `ponded_area`, `tag`, `comment`

**outfall**: `invert_elev`, `outfall_type` (FREE/NORMAL/FIXED/TIDAL/TIMESERIES), `stage_data`, `tide_gate`, `route_to`, `tag`, `comment`

**divider**: `invert_elev`, `max_depth`, `init_depth`, `surcharge_depth`, `ponded_area`, `divider_link`, `divider_type`, `cutoff_flow`, `qmin`, `dmax`, `qcoeff`, `tag`, `comment`

**storage**: `invert_elev`, `max_depth`, `init_depth`, `surcharge_depth`, `evap_factor`, `seepage`, `geometry`, `coeff0`, `coeff1`, `coeff2`, `area_table`, `tag`, `comment`

**conduit**: `inlet_node`, `outlet_node`, `shape`, `geom1`-`geom4`, `length`, `roughness`, `in_offset`, `out_offset`, `init_flow`, `max_flow`, `entry_loss`, `exit_loss`, `avg_loss`, `seepage`, `check_valve`, `culvert_code`, `barrels`, `tag`, `comment`

## Example

```bash
swmm_cli element set --type junction --id J5 --prop invert_elev --value 97.5

# Verify the change
swmm_cli element get --type junction --id J5 | jq '.invert_elev'
```

## Notes specific to this command

- **In-memory only**: changes are not saved to disk until the user saves in SWMM.
- **Re-run after changes**: previous simulation results are stale after any `element set`.
- **Values are strings**: pass `--value 97.5` (SWMM parses internally). Non-numeric string for a numeric field returns an error.
- **Use `element get` first** to discover exact property name spellings.
