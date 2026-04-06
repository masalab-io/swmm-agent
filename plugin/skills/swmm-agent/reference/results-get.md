# swmm_cli results get

Retrieve the full time-series for one element/variable pair after a simulation.

## Syntax

```
swmm_cli results get --type <type> --id <id> --variable <variable> [--pid N]
```

`--type` must be a specific subtype — **not** `node` or `link`.

### Valid `--variable` values

| Node types | Link types | Subcatchment |
|---|---|---|
| `depth`, `head`, `volume`, `lateral_inflow`, `total_inflow`, `flooding` | `flow`, `depth`, `velocity`, `volume`, `capacity` | `rainfall`, `snow_depth`, `evaporation`, `infiltration`, `runoff`, `gw_flow`, `gw_elev`, `soil_moisture` |

## Response

```json
{"ok":true,"data":[{"time":"2024-06-01T00:00:00","value":0.00},{"time":"2024-06-01T00:15:00","value":0.42},...]}
```

## Example

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli simulate run | \
  swmm_cli results get --type junction --id J5 --variable depth
```

## Notes specific to this command

- **Variable names are exact**: use `lateral_inflow` not `latflow`, `flooding` not `overflow`. Invalid names return an error listing valid options.
- **Cross-type variables fail**: `--type junction --variable flow` is invalid (flow is a link variable).
- **Empty `data: []`**: valid success — zero reporting timesteps. Check the simulation's reporting interval.
- **Units**: values use the unit system from the `.inp` file. No units field in the response.
