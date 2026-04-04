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

## Key Invariants (never break these)

1. **Session line always first** — any command emitting NDJSON to stdout emits `{"kind":"session","pid":N}` as its first line.
2. **Schema is the contract** — `SwmmElementSchema.pas` property names == `[JsonPropertyName(...)]` in C# models. Change both or change neither.
3. **No index constants outside `SwmmElementSchema.pas`** — `SwmmElementCommands.pas` never references `NODE_INVERT_INDEX` directly.
4. **Errors to stderr, data to stdout** — pipeline consumers never see error text mixed into NDJSON.
5. **`--full` required for filter** — `ElementFilterCommand` errors if stdin is in slim (pipe) mode; full property data is needed to evaluate the filter expression.
6. **Never modify existing `.pas` files** — all Agent code lives in `Agent/`. Only `Epaswmm5.dpr` gets a minimal `uses` addition.
