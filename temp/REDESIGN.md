# SWMM Agent — Redesign Plan

Based on: study of ExchangeTerminal (Exter) pipeline architecture + review of current SWMM Agent codebase.

---

## Core Ideas

### 1. NDJSON Pipeline (from Exter)

Every command operates in one of three output modes, selected automatically:

| Mode | When | Format |
|---|---|---|
| **Pipe** | stdout is redirected, `--full` not set | Slim NDJSON — one `{"kind":"swmm_element","id":"...","type":"..."}` per line |
| **Full** | `--full` flag set | Full NDJSON — all properties per line |
| **Terminal** | stdout is a terminal | Human-readable table |

Commands that accept a collection as input read NDJSON from stdin. This enables Unix-style pipelines:

```bash
swmm_cli --pid 1234 \
  | swmm_cli element list --type junction \
  | swmm_cli element get \
  | swmm_cli element filter --prop max_depth --lt 2.0 \
  | swmm_cli element set --prop invert_elev --value 8.5
```

The LLM writes one bash line. It never reads intermediate output. Context stays clean.

---

### 2. Session / PID Mechanism

`--pid` is specified **once** at the start of the pipeline. It flows through the stream as a session line.

```bash
swmm_cli --pid 1234         # emits: {"kind":"session","pid":1234}
swmm_cli --auto             # auto-discovers single running SWMM instance
```

**PID resolution order** (each command):

1. `--pid` explicit flag (always wins)
2. `{"kind":"session","pid":...}` from piped stdin ← the chain mechanism
3. `SWMM_PID` environment variable
4. `.swmm/session.json` in CWD (written by `swmm_cli attach <pid>`)
5. Auto-discovery (if exactly one `Epaswmm5.exe` is running)
6. Error: "Multiple SWMM instances — specify --pid or run: swmm_cli attach <pid>"

Every transform/sink command **re-emits** the session line at the top of its own output so it propagates through the full chain.

---

### 3. Element Schema Layer

SWMM stores all element properties as string arrays indexed by integer constants (`NODE_INVERT_INDEX = 7`, etc.). We need a dedicated schema layer on each side so index-to-name mappings live in one place only.

- **Delphi**: `SwmmElementSchema.pas` — one `Serialize*` function per element type. No index constants anywhere else in Agent code.
- **C#**: `Models/` directory — one strongly-typed record per element type. JSON property names must match the Delphi schema exactly.

---

### 4. File Organisation

#### Delphi — `swmm524_gui/Epaswmm5/Agent/`

Flat directory, one file per resource group (Delphi unit boilerplate cost is too high for one-file-per-command):

```
Agent/
  SwmmNamedPipe.pas           # pipe server thread — no changes after Phase 1
  SwmmAgentAPI.pas            # dispatcher ONLY — routes cmd string to handler units
  SwmmJsonUtils.pas           # JsonStr, OkResult, ErrResult, NodeTypeCode, LinkTypeCode
  SwmmElementSchema.pas       # authoritative: index→name mapping + Serialize* functions
  SwmmElementCommands.pas     # element.get, set, list, add, get-batch, set-batch
  SwmmSimulateCommands.pas    # simulate.run, status, wait
  SwmmFileCommands.pas        # file.open, info, save, save-as
  SwmmResultsCommands.pas     # results.get, summary
```

#### C# — `cli/SwmmCli/`

One file per command (C# files have minimal boilerplate — idiomatic and follows Exter):

```
cli/SwmmCli/
  Program.cs                      # DI wiring, root command setup, session emitter (--pid with no subcommand)
  SwmmCli.csproj
  IO/
    OutputMode.cs                 # IsPipeMode, ForceFullOutput, HasPipedInput
    NdJson.cs                     # WriteSession, WriteElement, WriteElementFull, ReadSessionAndRefsAsync, WriteStatus
  Session/
    SessionResolver.cs            # ResolvePid: walks the resolution chain
    SessionStore.cs               # read/write .swmm/session.json
  Models/
    SwmmElementRef.cs             # {kind, id, type} — slim pipe-mode ref
    Nodes/
      JunctionElement.cs
      OutfallElement.cs
      DividerElement.cs
      StorageElement.cs
    Links/
      ConduitElement.cs
      PumpElement.cs
      OrificeElement.cs
      WeirElement.cs
      OutletElement.cs
    Subcatchments/
      SubcatchmentElement.cs
    SwmmElementDeserializer.cs    # factory: reads "type" field, returns correct typed record
  Commands/
    AttachCommand.cs
    ProcessListCommand.cs
    ProcessLaunchCommand.cs
    ElementListCommand.cs
    ElementGetCommand.cs          # accepts piped refs → batches into element.get-batch
    ElementSetCommand.cs          # accepts piped refs → batches into element.set-batch
    ElementAddCommand.cs
    ElementFilterCommand.cs       # pure .NET transform — no pipe call, reads/writes NDJSON
    SimulateRunCommand.cs
    SimulateStatusCommand.cs
    SimulateWaitCommand.cs        # polls simulate.status until done or timeout
    FileOpenCommand.cs
    FileInfoCommand.cs
    FileSaveCommand.cs
    ResultsGetCommand.cs
    ResultsSummaryCommand.cs
```

---

### 5. Named Pipe Commands (full set)

#### Current (Phase 1, already implemented)
| Command | Action |
|---|---|
| `element.get` | Get single element properties |
| `element.set` | Set single property on element |
| `element.list` | List all IDs of a given type |
| `element.add` | Add a new node |
| `simulate.run` | Trigger simulation |
| `simulate.status` | Get run status |
| `file.open` | Open a .inp file |
| `file.info` | Get current open file path |

#### New (to be added)
| Command | Action |
|---|---|
| `element.get-batch` | `{"cmd":"element.get-batch","type":"junction","ids":["J1","J2"]}` → array of full element objects |
| `element.set-batch` | `{"cmd":"element.set-batch","type":"junction","ids":["J1","J2"],"prop":"invert_elev","value":"8.5"}` → `{"ok":true,"count":2}` |
| `file.save` | Save current project |
| `file.save-as` | Save to new path |
| `results.get` | Get simulation result for element+variable |
| `results.summary` | Get overall simulation summary |

---

### 6. JSON Schema per Element Type

Property names are the contract between Delphi serialization and C# deserialization. These must match exactly on both sides.

#### Nodes (common fields on all node types)
```json
{
  "id": "J1",
  "type": "junction",
  "x": 1000.0,
  "y": 2000.0,
  "invert_elev": "10.5",
  "tag": "",
  "comment": ""
}
```

#### Junction
```json
{
  "id": "J1", "type": "junction", "x": 0, "y": 0,
  "invert_elev": "10.5",
  "max_depth": "3.0",
  "init_depth": "0",
  "surcharge_depth": "0",
  "ponded_area": "0"
}
```

#### Outfall
```json
{
  "id": "O1", "type": "outfall", "x": 0, "y": 0,
  "invert_elev": "0",
  "outfall_type": "FREE",
  "stage_data": "",
  "tide_gate": "NO",
  "route_to": ""
}
```

#### Divider
```json
{
  "id": "D1", "type": "divider", "x": 0, "y": 0,
  "invert_elev": "0",
  "max_depth": "0",
  "init_depth": "0",
  "surcharge_depth": "0",
  "ponded_area": "0",
  "divider_link": "",
  "divider_type": "CUTOFF",
  "cutoff_flow": "0",
  "qmin": "0",
  "dmax": "0",
  "qcoeff": "0"
}
```

#### Storage
```json
{
  "id": "S1", "type": "storage", "x": 0, "y": 0,
  "invert_elev": "0",
  "max_depth": "0",
  "init_depth": "0",
  "surcharge_depth": "0",
  "evap_factor": "0",
  "seepage": "0",
  "geometry": "TABULAR",
  "coeff0": "0",
  "coeff1": "0",
  "coeff2": "0",
  "area_table": ""
}
```

#### Conduit
```json
{
  "id": "C1", "type": "conduit",
  "inlet_node": "J1", "outlet_node": "J2",
  "shape": "CIRCULAR",
  "geom1": "1.0",
  "geom2": "0", "geom3": "0", "geom4": "0",
  "length": "100",
  "roughness": "0.01",
  "in_offset": "0",
  "out_offset": "0",
  "init_flow": "0",
  "max_flow": "0",
  "entry_loss": "0",
  "exit_loss": "0",
  "avg_loss": "0",
  "seepage": "0",
  "check_valve": "NO",
  "culvert_code": "",
  "barrels": "1"
}
```

#### Pump
```json
{
  "id": "P1", "type": "pump",
  "inlet_node": "J1", "outlet_node": "J2",
  "pump_curve": "",
  "init_status": "ON",
  "startup_depth": "0",
  "shutoff_depth": "0"
}
```

#### Orifice
```json
{
  "id": "OR1", "type": "orifice",
  "inlet_node": "J1", "outlet_node": "J2",
  "orifice_type": "SIDE",
  "shape": "CIRCULAR",
  "height": "0",
  "width": "0",
  "bottom_height": "0",
  "discharge_coeff": "0.65",
  "flap_gate": "NO"
}
```

#### Weir
```json
{
  "id": "W1", "type": "weir",
  "inlet_node": "J1", "outlet_node": "J2",
  "weir_type": "TRANSVERSE",
  "height": "0",
  "length": "0",
  "side_slope": "0",
  "discharge_coeff": "3.33",
  "flap_gate": "NO",
  "end_contractions": "0",
  "end_coeff": "0"
}
```

#### Outlet
```json
{
  "id": "OT1", "type": "outlet",
  "inlet_node": "J1", "outlet_node": "J2",
  "offset_height": "0",
  "flap_gate": "NO",
  "discharge_curve": ""
}
```

#### Subcatchment
```json
{
  "id": "S1", "type": "subcatchment",
  "rain_gage": "",
  "outlet": "",
  "area": "0",
  "width": "0",
  "slope": "0",
  "imperv": "0",
  "imperv_n": "0.01",
  "perv_n": "0.1",
  "imperv_ds": "0.05",
  "perv_ds": "0.05",
  "pct_zero": "0",
  "route_to": "OUTLET",
  "pct_routed": "100",
  "infil_model": "",
  "groundwater": "",
  "snowpack": ""
}
```

---

## Implementation Phases

---

### Phase 1 — Foundation (no new features, restructuring only)

**Goal:** Lay the structural groundwork without breaking anything that works today.

#### C# CLI
- [ ] Create `IO/OutputMode.cs`
- [ ] Create `IO/NdJson.cs` — `WriteSession`, `WriteElement`, `WriteElementFull`, `WriteStatus`
- [ ] Create `Session/SessionResolver.cs` — full resolution chain
- [ ] Create `Session/SessionStore.cs` — read/write `.swmm/session.json`
- [ ] Create `Models/SwmmElementRef.cs`
- [ ] Refactor `Program.cs`: root command with `--pid`/`--auto` as session emitter; extract existing commands into `Commands/` files
  - `Commands/ProcessListCommand.cs`
  - `Commands/ProcessLaunchCommand.cs`
  - `Commands/AttachCommand.cs` (new — writes `.swmm/session.json`)
  - `Commands/ElementListCommand.cs`
  - `Commands/ElementGetCommand.cs`
  - `Commands/ElementSetCommand.cs`
  - `Commands/ElementAddCommand.cs`
  - `Commands/SimulateRunCommand.cs`
  - `Commands/SimulateStatusCommand.cs`
  - `Commands/FileOpenCommand.cs`
  - `Commands/FileInfoCommand.cs`

All existing commands keep their current behaviour — this is a refactor, not a feature change. All commands are updated to use `SessionResolver.ResolvePid(explicitPid)` instead of requiring `--pid`.

#### Delphi
- [ ] Create `SwmmJsonUtils.pas` — extract `JsonStr`, `OkResult`, `ErrResult`, `NodeTypeCode`, `LinkTypeCode` from `SwmmAgentAPI.pas`
- [ ] Thin down `SwmmAgentAPI.pas` to dispatcher only (calls into handler units)
- [ ] Create `SwmmElementCommands.pas` — move all `HandleElement*` functions from `SwmmAgentAPI.pas`
- [ ] Create `SwmmSimulateCommands.pas` — move `HandleSimulateRun`, `HandleSimulateStatus`
- [ ] Create `SwmmFileCommands.pas` — move `HandleFileOpen`, `HandleFileInfo`
- [ ] Add new units to `Epaswmm5.dpr` uses clause

**Outcome:** Same external behaviour, clean file structure in place.

---

### Phase 2 — Element Schema

**Goal:** Replace ad-hoc index access with a typed schema layer. Define the JSON contract for all 10 element types.

#### Delphi
- [ ] Create `SwmmElementSchema.pas`
  - `SerializeJunction(Node)`, `SerializeOutfall(Node)`, `SerializeDivider(Node)`, `SerializeStorage(Node)`
  - `SerializeConduit(Link)`, `SerializePump(Link)`, `SerializeOrifice(Link)`, `SerializeWeir(Link)`, `SerializeOutlet(Link)`
  - `SerializeSubcatchment(Sub)`
  - `NodePropIndex(Ntype, PropName)` — maps JSON name → Data[] index for `element.set`
  - `LinkPropIndex(Ltype, PropName)`
- [ ] Update `SwmmElementCommands.pas` to call `SwmmElementSchema` — remove all direct index constants

#### C#
- [ ] `Models/Nodes/JunctionElement.cs`
- [ ] `Models/Nodes/OutfallElement.cs`
- [ ] `Models/Nodes/DividerElement.cs`
- [ ] `Models/Nodes/StorageElement.cs`
- [ ] `Models/Links/ConduitElement.cs`
- [ ] `Models/Links/PumpElement.cs`
- [ ] `Models/Links/OrificeElement.cs`
- [ ] `Models/Links/WeirElement.cs`
- [ ] `Models/Links/OutletElement.cs`
- [ ] `Models/Subcatchments/SubcatchmentElement.cs`
- [ ] `Models/SwmmElementDeserializer.cs`
- [ ] Update `ElementGetCommand.cs` to deserialize into typed records

**Outcome:** Every element type has a correct, complete JSON representation. Adding or changing a property is a two-file change (one Delphi, one C#).

---

### Phase 3 — NDJSON Pipeline

**Goal:** Commands emit NDJSON and accept piped input. The pipeline pattern becomes usable.

#### Delphi
- [ ] Add `element.get-batch` to `SwmmElementCommands.pas`
  - Request: `{"cmd":"element.get-batch","type":"junction","ids":["J1","J2"]}`
  - Response: `{"ok":true,"data":[{...J1...},{...J2...}]}`
- [ ] Add `element.set-batch` to `SwmmElementCommands.pas`
  - Request: `{"cmd":"element.set-batch","type":"junction","ids":["J1","J2"],"prop":"invert_elev","value":"8.5"}`
  - Response: `{"ok":true,"count":2}`

#### C#
- [ ] Update `ElementListCommand.cs`:
  - Pipe mode: emit one `{"kind":"swmm_element","id":"J1","type":"junction"}` per element
  - `--full` mode: emit one full element JSON per line
  - Terminal mode: formatted table
  - Always emit session line first
- [ ] Update `ElementGetCommand.cs`:
  - If stdin is piped: read session + element refs → batch into `element.get-batch` → emit full NDJSON per element
  - Re-emit session line
- [ ] Update `ElementSetCommand.cs`:
  - If stdin is piped: read session + element refs → collect IDs → send `element.set-batch`
  - Emit `{"kind":"status","success":true,"count":N}`
- [ ] Create `Commands/ElementFilterCommand.cs` — pure .NET transform:
  - Reads session + element refs from stdin (full mode required)
  - Filters by `--prop`, `--eq/--gt/--lt/--gte/--lte`
  - Re-emits session line + matching elements

**Outcome:** Full pipeline works end-to-end. Agent writes one bash line for bulk operations.

---

### Phase 4 — Simulate + Results

**Goal:** Simulation workflow is pipeline-friendly. Results can be fetched per-element via pipe.

#### Delphi
- [ ] Add `simulate.wait` polling logic (or expose it in status check)
- [ ] Create `SwmmResultsCommands.pas`:
  - `results.get`: `{"cmd":"results.get","type":"node","id":"J1","variable":"depth"}` → time series or peak value
  - `results.summary`: overall simulation stats

#### C#
- [ ] Create `Commands/SimulateWaitCommand.cs` — polls `simulate.status` at interval until `success`/`error`/`failed`, with `--timeout`
- [ ] Create `Commands/ResultsGetCommand.cs` — accepts piped element refs, fetches result per element
- [ ] Create `Commands/ResultsSummaryCommand.cs`

**Outcome:** Full simulation loop is scriptable in one pipeline.

---

### Phase 5 — File Commands

**Goal:** File operations are complete and scriptable.

#### Delphi
- [ ] Add `file.save` to `SwmmFileCommands.pas`
- [ ] Add `file.save-as` to `SwmmFileCommands.pas`

#### C#
- [ ] Create `Commands/FileSaveCommand.cs`
- [ ] Create `Commands/FileSaveAsCommand.cs`

---

## Full SWMM Object Inventory

Source: `Uproject.pas`, `objprops.txt`, dialog units (`D*.pas`), `Ulid.pas`.
SWMM has 35 object classes (indices 0–34 in `Project.Lists[]`).

---

### Tier 1 — Simple Data[] arrays (straightforward to expose)

These objects store all their properties in a flat `Data: array[0..N] of String`.
Each index has a named constant in `Uproject.pas`. Clean 1:1 mapping to JSON.

#### Rain Gage (`TRaingage`) — `MAXGAGEPROPS = 15`
```
Index  Constant                  JSON name
5      GAGE_DATA_FORMAT          data_format          (TIMESERIES | FILE)
6      GAGE_DATA_FREQ            interval             (recording interval in minutes)
7      GAGE_SNOW_CATCH           snow_catch_factor
8      GAGE_DATA_SOURCE          data_source          (TIMESERIES | FILE)
9      GAGE_TIME_SERIES          time_series          (if TIMESERIES)
10     GAGE_SERIES_NAME          series_name
11     GAGE_DATA_FILE            data_file            (if FILE)
12     GAGE_FILE_NAME            file_name
13     GAGE_STATION_NUM          station_number
14     GAGE_RAIN_UNITS           rain_units           (IN | MM)
15     GAGE_FILE_PATH            file_path
```
Also has `X`, `Y` map coordinates (direct fields, not in Data[]).

#### Pollutant (`TPollutant`) — `MAXPOLLUTPROPS = 9`
```
Index  Constant               JSON name
0      POLLUT_UNITS_INDEX     units             (MG/L | UG/L | #/L)
1      POLLUT_RAIN_INDEX      rain_conc
2      POLLUT_GW_INDEX        gw_conc
3      POLLUT_II_INDEX        ii_conc
4      POLLUT_DWF_INDEX       dwf_conc
5      POLLUT_INIT_INDEX      init_conc
6      POLLUT_DECAY_INDEX     decay_coeff
7      POLLUT_SNOW_INDEX      snow_conc
8      POLLUT_COPOLLUT_INDEX  co_pollutant
9      POLLUT_FRACTION_INDEX  co_fraction
```

#### Land Use (`TLanduse`) — `MAXLANDUSEPROPS = 3`
```
Index  Constant                  JSON name
0      LANDUSE_CLEANING_INDEX    cleaning_interval
1      LANDUSE_AVAILABLE_INDEX   available_fraction
2      LANDUSE_LASTCLEAN_INDEX   last_cleaned
```
Also has `NonpointSources: TStringList` — buildup/washoff data per pollutant (nested, Tier 2).

#### Aquifer (`TAquifer`) — `MAXAQUIFERPROPS = 12`
```
Index  JSON name
0      porosity
1      wilting_point
2      field_capacity
3      conductivity
4      conductivity_slope
5      tension_slope
6      upper_evap_fraction
7      lower_evap_depth
8      lower_gw_loss_rate
9      bottom_elevation
10     water_table_elevation
11     unsat_zone_moisture
12     upper_evap_pattern
```

#### Street Section (`TStreet`) — `MAXSTREETPROPS = 9`
```
Index  Constant              JSON name
0      STREET_CROWN_WIDTH    crown_width
1      STREET_CURB_HEIGHT    curb_height
2      STREET_CROSS_SLOPE    cross_slope
3      STREET_ROUGHNESS      roughness
4      STREET_DEPRESSION     gutter_depression
5      STREET_GUTTER_WIDTH   gutter_width
6      STREET_SIDES          sides             (1 | 2)
7      STREET_BACK_WIDTH     back_width
8      STREET_BACK_SLOPE     back_slope
9      STREET_BACK_ROUGHNESS back_roughness
```
Also has `MaxDepth: String` (computed field, not in Data[]).

#### Analysis Options (`TOptions`) — `MAXOPTIONS = 42`
Full mapping from `Uproject.pas` index constants → `OptionLabels[]` in `objprops.txt`:
```
flow_units, infiltration, flow_routing, link_offsets, min_slope, allow_ponding,
skip_steady_state, ignore_rainfall, ignore_rdii, ignore_snowmelt,
ignore_groundwater, ignore_routing, ignore_quality,
start_date, start_time, report_start_date, report_start_time,
end_date, end_time, sweep_start, sweep_end, dry_days,
report_step, wet_step, dry_step, routing_step, rule_step,
inertial_damping, normal_flow_limited, force_main_equation, surcharge_method,
variable_step, lengthening_step, min_surfarea, max_trials,
head_tolerance, sys_flow_tol, lat_flow_tol, minimum_step, threads
```
Stored in `Project.Options.Data[0..42]`. Accessed via `Project.Options` (singleton, no list index).

---

### Tier 2 — Structured objects with named sub-sections (moderate complexity)

#### Time Pattern (`TPattern`)
Fields: `PatternType` (int: MONTHLY/DAILY/HOURLY/WEEKEND), `Comment`, `Count`, `Data[0..23]` (multipliers).
JSON:
```json
{
  "id": "DWF_HOURLY", "type": "pattern",
  "pattern_type": "HOURLY",
  "comment": "",
  "multipliers": ["1.0","0.9","0.8","0.7","0.7","0.8","1.2","1.4","1.3","1.2","1.1","1.0",
                  "1.0","1.1","1.2","1.3","1.2","1.1","1.0","1.0","0.9","0.9","0.9","1.0"]
}
```

#### Curves (`TCurve`) — 7 types (indices 14–21)
Types: `CONTROL`, `DIVERSION`, `PUMP`, `RATING`, `SHAPE`, `STORAGE`, `TIDAL`, `WEIR`.
Fields: `Comment`, `CurveType: String`, `CurveCode: Integer`, `Xdata: TStringList`, `Ydata: TStringList`.
JSON:
```json
{
  "id": "PUMP1_CURVE", "type": "pump_curve",
  "comment": "",
  "points": [
    {"x": "0", "y": "0"},
    {"x": "1", "y": "10"},
    {"x": "2", "y": "18"}
  ]
}
```

#### Time Series (`TTimeSeries`)
Fields: `Comment`, `Filename` (if file-based), `Dates: TStringList`, `Times: TStringList`, `Values: TStringList`.
Three parallel string lists — zip into array of objects for JSON:
```json
{
  "id": "RAIN_2024", "type": "time_series",
  "comment": "",
  "file": "",
  "data": [
    {"date": "01/01/2024", "time": "00:00", "value": "0.1"},
    {"date": "01/01/2024", "time": "01:00", "value": "0.3"}
  ]
}
```

#### Transect (`TTransect`) — `MAXTRANSECTPROPS = 8`
Fields: `Comment`, `Data[0..8]` (roughness + station adjustments), `Xdata/Ydata: TStringList` (station/elevation pairs).
```
Data[0] = n_left       Data[1] = n_right      Data[2] = n_channel
Data[3] = x_left       Data[4] = x_right      Data[5] = x_factor
Data[6] = y_factor     Data[7] = length_factor Data[8] = max_depth
```
```json
{
  "id": "CULVERT_XS", "type": "transect",
  "n_left": "0.05", "n_right": "0.05", "n_channel": "0.035",
  "x_left": "0", "x_right": "0", "x_factor": "1.0",
  "y_factor": "1.0", "length_factor": "1.0",
  "stations": [
    {"station": "0", "elevation": "10.0"},
    {"station": "5", "elevation": "8.5"},
    {"station": "10", "elevation": "10.0"}
  ]
}
```

#### Groundwater (`TSubcatch.Groundwater: TStringList`)
Stored as a TStringList on each subcatchment. From `Dgwater.pas` `PropNames`:
```
aquifer_name, receiving_node, surface_elevation,
a1_coeff, b1_exponent, a2_coeff, b2_exponent, a3_coeff,
surface_water_depth, threshold_water_table, bottom_elevation,
initial_water_table, unsat_zone_moisture,
custom_lateral_flow_eqn, custom_deep_flow_eqn
```
Exposed as a nested object within the subcatchment schema.

---

### Tier 3 — Complex nested structures (higher implementation cost)

#### LID Control (`TLid`) — `MAXCLASS = 32`
Has `ProcessType` (int: 0–7 = Bio-Retention/Rain Garden/Green Roof/Infil. Trench/Perm. Pavement/Rain Barrel/Roof Discon./Veg. Swale) plus 6 typed layer arrays:

```
SurfaceLayer[0..4]:   berm_height, veg_fraction, roughness, slope, side_slope
PavementLayer[0..6]:  thickness, void_ratio, imperv_fraction, permeability, clog_factor, regen_interval, regen_fraction
SoilLayer[0..6]:      thickness, porosity, field_capacity, wilting_point, ksat, ksat_slope, suction_head
StorageLayer[0..4]:   thickness, void_ratio, ksat, clog_factor, covered (YES/NO)
DrainLayer[0..6]:     flow_coeff, flow_exponent, offset_height, delay, open_head, closed_head, control_curve
DrainMatLayer[0..2]:  thickness, void_fraction, roughness
```
Also has `DrainRemovals: TStringList` (pollutant removal rates).

#### Snowpack (`TSnowpack`)
`FracPlowable: String`, `Data[1..3, 1..7]` (2D: surface type × parameter), `Plowing[1..7]`.
Surface types: 1=PLOWABLE, 2=IMPERVIOUS, 3=PERVIOUS.
Parameters: min_melt_coeff, max_melt_coeff, init_snow_depth, init_free_water, depth_100pct_cover, depth_pack_snow, init_abs_moisture.

#### Climatology (`TClimatology`)
Large singleton structure:
- Temperature: `TempDataSource`, `TempTseries`, `TempFile`, `TempStartDate`, `TempUnitsType`
- Evaporation: `EvapType`, `EvapTseries`, `EvapData[0..11]` (monthly), `PanData[0..11]`, `RecoveryPat`, `EvapDryOnly`
- Wind: `WindType`, `WindSpeed[1..12]`
- Snowmelt: `SnowMelt[1..6]`, `ADCurve[1..2, 1..10]`
- Adjustments: `TempAdjust[0..11]`, `EvapAdjust[0..11]`, `RainAdjust[0..11]`, `CondAdjust[0..11]`

#### RDII Unit Hydrograph (`THydrograph`)
`Raingage: String`, `Params[0..12, 1..3, 1..3]` (month × RTK triangle × parameter), `InitAbs[0..12, 1..3, 1..3]`.

#### Control Rules (`Project.ControlRules: TStringList`)
Stored as raw text lines. No structured data model — parsing would require implementing the SWMM control rule grammar. Expose as a raw string block.

#### Node Inflows
Each `TNode` has three TStringList fields for inflow data:
- `DWInflow` — dry weather inflow (base flow + pattern)
- `DXInflow` — direct external inflow (time series)
- `IIInflow` — RDII inflow (unit hydrograph)
Best exposed as nested objects on the node schema, read-only initially.

#### Inlet (`INLET = 34`)
Complex — uses `Uinlet.pas`. Separate class with culvert/grate geometry. Defer to later phase.

---

### Not worth exposing

| Object | Reason |
|---|---|
| `MAPLABEL` (13) | Pure visual — text label on map, no hydraulic relevance |
| `Project.Clipboard` | Transient UI state |
| `Project.ProfileNames/Links` | UI-only saved profile plot state |

---

### Summary table

| Class | Delphi type | Storage | Tier | Data[] indices defined? |
|---|---|---|---|---|
| OPTION (1) | `TOptions` | `Data[0..42]` | 1 | Yes — `*_INDEX` constants |
| RAINGAGE (2) | `TRaingage` | `Data[0..15]` | 1 | Yes — `GAGE_*` constants |
| SUBCATCH (3) | `TSubcatch` | `Data[0..27]` + nested | 1+3 | Yes |
| JUNCTION (4) | `TNode` | `Data[0..21]` | 1 | Yes |
| OUTFALL (5) | `TNode` | `Data[0..21]` | 1 | Yes |
| DIVIDER (6) | `TNode` | `Data[0..21]` | 1 | Yes |
| STORAGE (7) | `TNode` | `Data[0..21]` | 1 | Yes |
| CONDUIT (8) | `TLink` | `Data[0..24]` | 1 | Yes |
| PUMP (9) | `TLink` | `Data[0..24]` | 1 | Yes |
| ORIFICE (10) | `TLink` | `Data[0..24]` | 1 | Yes |
| WEIR (11) | `TLink` | `Data[0..24]` | 1 | Yes |
| OUTLET (12) | `TLink` | `Data[0..24]` | 1 | Yes |
| CONTROL_CURVE–WEIR_CURVE (14–21) | `TCurve` | `Xdata/Ydata` | 2 | N/A (x/y pairs) |
| TIMESERIES (22) | `TTimeSeries` | 3 parallel TStringLists | 2 | N/A |
| PATTERN (23) | `TPattern` | `Data[0..23]` + type | 2 | N/A (index = slot) |
| TRANSECT (24) | `TTransect` | `Data[0..8]` + `Xdata/Ydata` | 2 | Yes — `TRANSECT_*` |
| HYDROGRAPH (25) | `THydrograph` | 3D arrays | 3 | N/A |
| POLLUTANT (26) | `TPollutant` | `Data[0..9]` | 1 | Yes — `POLLUT_*` |
| LANDUSE (27) | `TLanduse` | `Data[0..3]` + nested | 1+2 | Yes — `LANDUSE_*` |
| AQUIFER (28) | `TAquifer` | `Data[0..12]` | 1 | By position |
| CONTROL (29) | `TStringList` | Raw text | 3 | N/A |
| CLIMATOLOGY (30) | `TClimatology` | Named fields | 3 | N/A |
| SNOWPACK (31) | `TSnowpack` | 2D arrays | 3 | N/A |
| LID (32) | `TLid` | 6 layer arrays | 3 | By position |
| STREET (33) | `TStreet` | `Data[0..9]` | 1 | Yes — `STREET_*` |
| INLET (34) | complex | `Uinlet.pas` | 3 | N/A |

---

### Updated `SwmmElementSchema.pas` scope

Based on this inventory, the schema unit covers:

**Phase 2** (originally planned — Tier 1 network elements):
Nodes (4 types) + Links (5 types) + Subcatchment basic fields

**Phase 2b** (add to Phase 2):
RainGage, Pollutant, LandUse, Aquifer, Street, Options

**Phase 3+** (Tier 2 — structured data):
Pattern, all Curve types, TimeSeries, Transect, Groundwater (nested on subcatchment)

**Later phases** (Tier 3 — complex):
LID, Snowpack, Climatology, Hydrograph, ControlRules, NodeInflows

---

## Key Invariants (never break these)

1. **Session line always first** — any command emitting NDJSON to stdout emits `{"kind":"session","pid":N}` as its first line.
2. **Schema is the contract** — `SwmmElementSchema.pas` property names == `[JsonPropertyName(...)]` in C# models. Change both or change neither.
3. **No index constants outside `SwmmElementSchema.pas`** — `SwmmElementCommands.pas` never references `NODE_INVERT_INDEX` directly.
4. **Errors to stderr, data to stdout** — pipeline consumers never see error text mixed into NDJSON.
5. **`--full` required for filter** — `ElementFilterCommand` errors if stdin is in slim (pipe) mode; full property data is needed to evaluate the filter expression.
6. **Never modify existing `.pas` files** — all Agent code lives in `Agent/`. Only `Epaswmm5.dpr` gets a minimal `uses` addition.
