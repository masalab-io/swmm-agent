# swmm_cli results summary

Get max/min across all output variables for one element after a simulation.

## Syntax

```
swmm_cli results summary --type <type> --id <id> [--pid N]
```

`--type` must be a specific subtype (`junction`, `conduit`, etc.) — **not** `node` or `link`.

## Response — varies by type

**Junction:**
```json
{"ok":true,"data":{"id":"J5","type":"junction","nperiods":96,"depth":{"max":4.12,"min":0.00},"head":{"max":9.62,"min":5.50},"volume":{"max":0,"min":0},"lateral_inflow":{"max":2.81,"min":0.00},"total_inflow":{"max":5.63,"min":0.00},"flooding":{"max":0.73,"min":0.00}}}
```

**Conduit:** `flow`, `depth`, `velocity`, `volume`, `capacity`

**Subcatchment:** `rainfall`, `snow_depth`, `evaporation`, `infiltration`, `runoff`, `gw_flow`, `gw_elev`, `soil_moisture`

## Example

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results summary --type junction --id J5

# Check if a junction flooded
swmm_cli results summary --type junction --id J5 | jq '.data.flooding.max'
```

## Notes specific to this command

- **Simulation must be complete**: returns error if status is `none` or `running`.
- **`warning` status is valid**: results are available after a warning run.
- **Units**: values use the unit system from the `.inp` file (US customary or SI). No units field in the response.
- **Unknown ID**: returns `{"ok":false,"error":"Element not found"}`. Verify with `element list` first.
