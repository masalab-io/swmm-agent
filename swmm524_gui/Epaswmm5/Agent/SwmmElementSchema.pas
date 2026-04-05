unit SwmmElementSchema;

{
  SwmmElementSchema.pas
  ---------------------
  Authoritative index-to-name mapping for all SWMM element types.

  Rules:
    - All Data[] index constants live HERE. No other Agent unit may reference
      Uproject index constants directly.
    - Serialize* functions return a raw JSON object string (no ok/data envelope).
      Callers wrap with OkResult() as needed.
    - NodePropIndex / LinkPropIndex map a JSON property name back to a Data[]
      index for element.set. Return -1 for unknown or read-only fields.
}

interface

uses
  Uproject;

// ---------------------------------------------------------------------------
// Serializers — one per element type
// ---------------------------------------------------------------------------

function SerializeJunction(Node: TNode; const TypeStr: string): string;
function SerializeOutfall(Node: TNode; const TypeStr: string): string;
function SerializeDivider(Node: TNode; const TypeStr: string): string;
function SerializeStorage(Node: TNode; const TypeStr: string): string;

function SerializeConduit(Link: TLink; const TypeStr: string): string;
function SerializePump(Link: TLink; const TypeStr: string): string;
function SerializeOrifice(Link: TLink; const TypeStr: string): string;
function SerializeWeir(Link: TLink; const TypeStr: string): string;
function SerializeOutlet(Link: TLink; const TypeStr: string): string;

function SerializeSubcatch(Sub: TSubcatch; const TypeStr: string): string;

// ---------------------------------------------------------------------------
// Reverse-lookup for element.set
// ---------------------------------------------------------------------------

function NodePropIndex(Ntype: Integer; const PropName: string): Integer;
function LinkPropIndex(Ltype: Integer; const PropName: string): Integer;

// Post-creation initialisation: sets Data[] fields that CopyStringArray leaves nil.
procedure InitNodeDefaults(N: TNode; Ntype: Integer);

implementation

uses
  System.SysUtils,
  SwmmJsonUtils;

// ---------------------------------------------------------------------------
// Internal: shared node header fields
// ---------------------------------------------------------------------------

procedure AppendNodeHeader(Sb: TStringBuilder; Node: TNode; const TypeStr: string);
begin
  Sb.Append('"id":');           Sb.Append(JsonStr(string(Node.ID)));
  Sb.Append(',"type":');        Sb.Append(JsonStr(TypeStr));
  Sb.Append(',"x":');           Sb.AppendFormat('%.6g', [Node.X]);
  Sb.Append(',"y":');           Sb.AppendFormat('%.6g', [Node.Y]);
  Sb.Append(',"comment":');     Sb.Append(JsonStr(Node.Data[COMMENT_INDEX]));
  Sb.Append(',"tag":');         Sb.Append(JsonStr(Node.Data[TAG_INDEX]));
  Sb.Append(',"invert_elev":'); Sb.Append(JsonStr(Node.Data[NODE_INVERT_INDEX]));
end;

// ---------------------------------------------------------------------------
// Internal: shared link header fields
// ---------------------------------------------------------------------------

procedure AppendLinkHeader(Sb: TStringBuilder; Link: TLink; const TypeStr: string);
var
  Node1Id, Node2Id: string;
begin
  if Assigned(Link.Node1) then Node1Id := string(Link.Node1.ID) else Node1Id := '';
  if Assigned(Link.Node2) then Node2Id := string(Link.Node2.ID) else Node2Id := '';

  Sb.Append('"id":');           Sb.Append(JsonStr(string(Link.ID)));
  Sb.Append(',"type":');        Sb.Append(JsonStr(TypeStr));
  Sb.Append(',"comment":');     Sb.Append(JsonStr(Link.Data[COMMENT_INDEX]));
  Sb.Append(',"tag":');         Sb.Append(JsonStr(Link.Data[TAG_INDEX]));
  Sb.Append(',"inlet_node":');  Sb.Append(JsonStr(Node1Id));
  Sb.Append(',"outlet_node":'); Sb.Append(JsonStr(Node2Id));
end;

// ---------------------------------------------------------------------------
// Junction
// ---------------------------------------------------------------------------

function SerializeJunction(Node: TNode; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendNodeHeader(Sb, Node, TypeStr);
    Sb.Append(',"max_depth":');       Sb.Append(JsonStr(Node.Data[JUNCTION_MAX_DEPTH_INDEX]));
    Sb.Append(',"init_depth":');      Sb.Append(JsonStr(Node.Data[JUNCTION_INIT_DEPTH_INDEX]));
    Sb.Append(',"surcharge_depth":'); Sb.Append(JsonStr(Node.Data[JUNCTION_SURCHARGE_DEPTH_INDEX]));
    Sb.Append(',"ponded_area":');     Sb.Append(JsonStr(Node.Data[JUNCTION_PONDED_AREA_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Outfall
// ---------------------------------------------------------------------------

function SerializeOutfall(Node: TNode; const TypeStr: string): string;
var
  Sb: TStringBuilder;
  OutType, StageData: string;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendNodeHeader(Sb, Node, TypeStr);
    Sb.Append(',"tide_gate":');   Sb.Append(JsonStr(Node.Data[OUTFALL_TIDE_GATE_INDEX]));
    Sb.Append(',"route_to":');    Sb.Append(JsonStr(Node.Data[OUTFALL_ROUTETO_INDEX]));

    OutType := Node.Data[OUTFALL_TYPE_INDEX];
    Sb.Append(',"outfall_type":'); Sb.Append(JsonStr(OutType));

    // stage_data is the relevant data value for the chosen outfall type
    if SameText(OutType, 'FIXED') then
      StageData := Node.Data[OUTFALL_FIXED_STAGE_INDEX]
    else if SameText(OutType, 'TIDAL') then
      StageData := Node.Data[OUTFALL_TIDE_TABLE_INDEX]
    else if SameText(OutType, 'TIMESERIES') then
      StageData := Node.Data[OUTFALL_TIME_SERIES_INDEX]
    else
      StageData := '';

    Sb.Append(',"stage_data":'); Sb.Append(JsonStr(StageData));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

function SerializeDivider(Node: TNode; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendNodeHeader(Sb, Node, TypeStr);
    Sb.Append(',"max_depth":');       Sb.Append(JsonStr(Node.Data[DIVIDER_MAX_DEPTH_INDEX]));
    Sb.Append(',"init_depth":');      Sb.Append(JsonStr(Node.Data[DIVIDER_INIT_DEPTH_INDEX]));
    Sb.Append(',"surcharge_depth":'); Sb.Append(JsonStr(Node.Data[DIVIDER_SURCHARGE_DEPTH_INDEX]));
    Sb.Append(',"ponded_area":');     Sb.Append(JsonStr(Node.Data[DIVIDER_PONDED_AREA_INDEX]));
    Sb.Append(',"divider_link":');    Sb.Append(JsonStr(Node.Data[DIVIDER_LINK_INDEX]));
    Sb.Append(',"divider_type":');    Sb.Append(JsonStr(Node.Data[DIVIDER_TYPE_INDEX]));
    Sb.Append(',"cutoff_flow":');     Sb.Append(JsonStr(Node.Data[DIVIDER_CUTOFF_INDEX]));
    Sb.Append(',"qmin":');            Sb.Append(JsonStr(Node.Data[DIVIDER_QMIN_INDEX]));
    Sb.Append(',"dmax":');            Sb.Append(JsonStr(Node.Data[DIVIDER_DMAX_INDEX]));
    Sb.Append(',"qcoeff":');          Sb.Append(JsonStr(Node.Data[DIVIDER_QCOEFF_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

function SerializeStorage(Node: TNode; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendNodeHeader(Sb, Node, TypeStr);
    Sb.Append(',"max_depth":');       Sb.Append(JsonStr(Node.Data[STORAGE_MAX_DEPTH_INDEX]));
    Sb.Append(',"init_depth":');      Sb.Append(JsonStr(Node.Data[STORAGE_INIT_DEPTH_INDEX]));
    Sb.Append(',"surcharge_depth":'); Sb.Append(JsonStr(Node.Data[STORAGE_SURCHARGE_DEPTH_INDEX]));
    Sb.Append(',"evap_factor":');     Sb.Append(JsonStr(Node.Data[STORAGE_EVAP_FACTOR_INDEX]));
    Sb.Append(',"seepage":');         Sb.Append(JsonStr(Node.Data[STORAGE_SEEPAGE_INDEX]));
    Sb.Append(',"geometry":');        Sb.Append(JsonStr(Node.Data[STORAGE_GEOMETRY_INDEX]));
    Sb.Append(',"coeff0":');          Sb.Append(JsonStr(Node.Data[STORAGE_COEFF0_INDEX]));
    Sb.Append(',"coeff1":');          Sb.Append(JsonStr(Node.Data[STORAGE_COEFF1_INDEX]));
    Sb.Append(',"coeff2":');          Sb.Append(JsonStr(Node.Data[STORAGE_COEFF2_INDEX]));
    Sb.Append(',"area_table":');      Sb.Append(JsonStr(Node.Data[STORAGE_ATABLE_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Conduit
// ---------------------------------------------------------------------------

function SerializeConduit(Link: TLink; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendLinkHeader(Sb, Link, TypeStr);
    Sb.Append(',"shape":');       Sb.Append(JsonStr(Link.Data[CONDUIT_SHAPE_INDEX]));
    Sb.Append(',"geom1":');       Sb.Append(JsonStr(Link.Data[CONDUIT_GEOM1_INDEX]));
    Sb.Append(',"geom2":');       Sb.Append(JsonStr(Link.Data[CONDUIT_GEOM2_INDEX]));
    Sb.Append(',"geom3":');       Sb.Append(JsonStr(Link.Data[CONDUIT_GEOM3_INDEX]));
    Sb.Append(',"geom4":');       Sb.Append(JsonStr(Link.Data[CONDUIT_GEOM4_INDEX]));
    Sb.Append(',"length":');      Sb.Append(JsonStr(Link.Data[CONDUIT_LENGTH_INDEX]));
    Sb.Append(',"roughness":');   Sb.Append(JsonStr(Link.Data[CONDUIT_ROUGHNESS_INDEX]));
    Sb.Append(',"in_offset":');   Sb.Append(JsonStr(Link.Data[CONDUIT_INLET_HT_INDEX]));
    Sb.Append(',"out_offset":');  Sb.Append(JsonStr(Link.Data[CONDUIT_OUTLET_HT_INDEX]));
    Sb.Append(',"init_flow":');   Sb.Append(JsonStr(Link.Data[CONDUIT_INIT_FLOW_INDEX]));
    Sb.Append(',"max_flow":');    Sb.Append(JsonStr(Link.Data[CONDUIT_MAX_FLOW_INDEX]));
    Sb.Append(',"entry_loss":');  Sb.Append(JsonStr(Link.Data[CONDUIT_ENTRY_LOSS_INDEX]));
    Sb.Append(',"exit_loss":');   Sb.Append(JsonStr(Link.Data[CONDUIT_EXIT_LOSS_INDEX]));
    Sb.Append(',"avg_loss":');    Sb.Append(JsonStr(Link.Data[CONDUIT_AVG_LOSS_INDEX]));
    Sb.Append(',"seepage":');     Sb.Append(JsonStr(Link.Data[CONDUIT_SEEPAGE_INDEX]));
    Sb.Append(',"check_valve":'); Sb.Append(JsonStr(Link.Data[CONDUIT_CHECK_VALVE_INDEX]));
    Sb.Append(',"culvert_code":'); Sb.Append(JsonStr(Link.Data[CONDUIT_CULVERT_INDEX]));
    Sb.Append(',"barrels":');     Sb.Append(JsonStr(Link.Data[CONDUIT_BARRELS_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Pump
// ---------------------------------------------------------------------------

function SerializePump(Link: TLink; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendLinkHeader(Sb, Link, TypeStr);
    Sb.Append(',"pump_curve":');    Sb.Append(JsonStr(Link.Data[PUMP_CURVE_INDEX]));
    Sb.Append(',"init_status":');   Sb.Append(JsonStr(Link.Data[PUMP_STATUS_INDEX]));
    Sb.Append(',"startup_depth":'); Sb.Append(JsonStr(Link.Data[PUMP_STARTUP_INDEX]));
    Sb.Append(',"shutoff_depth":'); Sb.Append(JsonStr(Link.Data[PUMP_SHUTOFF_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Orifice
// ---------------------------------------------------------------------------

function SerializeOrifice(Link: TLink; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendLinkHeader(Sb, Link, TypeStr);
    Sb.Append(',"orifice_type":');   Sb.Append(JsonStr(Link.Data[ORIFICE_TYPE_INDEX]));
    Sb.Append(',"shape":');          Sb.Append(JsonStr(Link.Data[ORIFICE_SHAPE_INDEX]));
    Sb.Append(',"height":');         Sb.Append(JsonStr(Link.Data[ORIFICE_HEIGHT_INDEX]));
    Sb.Append(',"width":');          Sb.Append(JsonStr(Link.Data[ORIFICE_WIDTH_INDEX]));
    Sb.Append(',"bottom_height":');  Sb.Append(JsonStr(Link.Data[ORIFICE_BOTTOM_HT_INDEX]));
    Sb.Append(',"discharge_coeff":'); Sb.Append(JsonStr(Link.Data[ORIFICE_COEFF_INDEX]));
    Sb.Append(',"flap_gate":');      Sb.Append(JsonStr(Link.Data[ORIFICE_FLAPGATE_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Weir
// ---------------------------------------------------------------------------

function SerializeWeir(Link: TLink; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendLinkHeader(Sb, Link, TypeStr);
    Sb.Append(',"weir_type":');       Sb.Append(JsonStr(Link.Data[WEIR_TYPE_INDEX]));
    Sb.Append(',"height":');          Sb.Append(JsonStr(Link.Data[WEIR_HEIGHT_INDEX]));
    Sb.Append(',"length":');          Sb.Append(JsonStr(Link.Data[WEIR_WIDTH_INDEX]));
    Sb.Append(',"side_slope":');      Sb.Append(JsonStr(Link.Data[WEIR_SLOPE_INDEX]));
    Sb.Append(',"discharge_coeff":'); Sb.Append(JsonStr(Link.Data[WEIR_COEFF_INDEX]));
    Sb.Append(',"flap_gate":');       Sb.Append(JsonStr(Link.Data[WEIR_FLAPGATE_INDEX]));
    Sb.Append(',"end_contractions":'); Sb.Append(JsonStr(Link.Data[WEIR_CONTRACT_INDEX]));
    Sb.Append(',"end_coeff":');       Sb.Append(JsonStr(Link.Data[WEIR_END_COEFF_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Outlet
// ---------------------------------------------------------------------------

function SerializeOutlet(Link: TLink; const TypeStr: string): string;
var
  Sb: TStringBuilder;
  OutType, DischargeCurve: string;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    AppendLinkHeader(Sb, Link, TypeStr);
    Sb.Append(',"offset_height":'); Sb.Append(JsonStr(Link.Data[OUTLET_CREST_INDEX]));
    Sb.Append(',"flap_gate":');     Sb.Append(JsonStr(Link.Data[OUTLET_FLAPGATE_INDEX]));

    OutType := Link.Data[OUTLET_TYPE_INDEX];
    Sb.Append(',"outlet_type":'); Sb.Append(JsonStr(OutType));

    // discharge_curve is the tabular curve name (TABULAR type), empty otherwise
    if SameText(OutType, 'TABULAR/DEPTH') or SameText(OutType, 'TABULAR/HEAD') then
      DischargeCurve := Link.Data[OUTLET_QTABLE_INDEX]
    else
      DischargeCurve := '';

    Sb.Append(',"discharge_curve":'); Sb.Append(JsonStr(DischargeCurve));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Subcatchment
// ---------------------------------------------------------------------------

function SerializeSubcatch(Sub: TSubcatch; const TypeStr: string): string;
var
  Sb: TStringBuilder;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    Sb.Append('"id":');       Sb.Append(JsonStr(string(Sub.ID)));
    Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
    Sb.Append(',"comment":'); Sb.Append(JsonStr(Sub.Data[COMMENT_INDEX]));
    Sb.Append(',"tag":');     Sb.Append(JsonStr(Sub.Data[TAG_INDEX]));
    Sb.Append(',"rain_gage":');   Sb.Append(JsonStr(Sub.Data[SUBCATCH_RAINGAGE_INDEX]));
    Sb.Append(',"outlet":');      Sb.Append(JsonStr(Sub.Data[SUBCATCH_OUTLET_INDEX]));
    Sb.Append(',"area":');        Sb.Append(JsonStr(Sub.Data[SUBCATCH_AREA_INDEX]));
    Sb.Append(',"width":');       Sb.Append(JsonStr(Sub.Data[SUBCATCH_WIDTH_INDEX]));
    Sb.Append(',"slope":');       Sb.Append(JsonStr(Sub.Data[SUBCATCH_SLOPE_INDEX]));
    Sb.Append(',"imperv":');      Sb.Append(JsonStr(Sub.Data[SUBCATCH_IMPERV_INDEX]));
    Sb.Append(',"imperv_n":');    Sb.Append(JsonStr(Sub.Data[SUBCATCH_IMPERV_N_INDEX]));
    Sb.Append(',"perv_n":');      Sb.Append(JsonStr(Sub.Data[SUBCATCH_PERV_N_INDEX]));
    Sb.Append(',"imperv_ds":');   Sb.Append(JsonStr(Sub.Data[SUBCATCH_IMPERV_DS_INDEX]));
    Sb.Append(',"perv_ds":');     Sb.Append(JsonStr(Sub.Data[SUBCATCH_PERV_DS_INDEX]));
    Sb.Append(',"pct_zero":');    Sb.Append(JsonStr(Sub.Data[SUBCATCH_PCTZERO_INDEX]));
    Sb.Append(',"route_to":');    Sb.Append(JsonStr(Sub.Data[SUBCATCH_ROUTE_TO_INDEX]));
    Sb.Append(',"pct_routed":');  Sb.Append(JsonStr(Sub.Data[SUBCATCH_PCT_ROUTED_INDEX]));
    Sb.Append(',"infil_model":'); Sb.Append(JsonStr(Sub.Data[SUBCATCH_INFIL_INDEX]));
    Sb.Append(',"groundwater":'); Sb.Append(JsonStr(Sub.Data[SUBCATCH_GWATER_INDEX]));
    Sb.Append(',"snowpack":');    Sb.Append(JsonStr(Sub.Data[SUBCATCH_SNOWPACK_INDEX]));
    Sb.Append('}');
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// NodePropIndex — JSON name → Data[] index for element.set
// Returns -1 for unknown or read-only properties.
// ---------------------------------------------------------------------------

function NodePropIndex(Ntype: Integer; const PropName: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(PropName);
  Result := -1;

  // Shared across all node types
  if Lower = 'invert_elev' then
  begin
    Result := NODE_INVERT_INDEX;
    Exit;
  end;

  case Ntype of
    JUNCTION:
    begin
      if Lower = 'max_depth'       then Result := JUNCTION_MAX_DEPTH_INDEX
      else if Lower = 'init_depth'      then Result := JUNCTION_INIT_DEPTH_INDEX
      else if Lower = 'surcharge_depth' then Result := JUNCTION_SURCHARGE_DEPTH_INDEX
      else if Lower = 'ponded_area'     then Result := JUNCTION_PONDED_AREA_INDEX;
    end;

    OUTFALL:
    begin
      if Lower = 'tide_gate'   then Result := OUTFALL_TIDE_GATE_INDEX
      else if Lower = 'route_to'    then Result := OUTFALL_ROUTETO_INDEX
      else if Lower = 'outfall_type' then Result := OUTFALL_TYPE_INDEX;
      // stage_data is not directly writable via a single index
    end;

    DIVIDER:
    begin
      if Lower = 'max_depth'        then Result := DIVIDER_MAX_DEPTH_INDEX
      else if Lower = 'init_depth'       then Result := DIVIDER_INIT_DEPTH_INDEX
      else if Lower = 'surcharge_depth'  then Result := DIVIDER_SURCHARGE_DEPTH_INDEX
      else if Lower = 'ponded_area'      then Result := DIVIDER_PONDED_AREA_INDEX
      else if Lower = 'divider_link'     then Result := DIVIDER_LINK_INDEX
      else if Lower = 'divider_type'     then Result := DIVIDER_TYPE_INDEX
      else if Lower = 'cutoff_flow'      then Result := DIVIDER_CUTOFF_INDEX
      else if Lower = 'qmin'             then Result := DIVIDER_QMIN_INDEX
      else if Lower = 'dmax'             then Result := DIVIDER_DMAX_INDEX
      else if Lower = 'qcoeff'           then Result := DIVIDER_QCOEFF_INDEX;
    end;

    STORAGE:
    begin
      if Lower = 'max_depth'        then Result := STORAGE_MAX_DEPTH_INDEX
      else if Lower = 'init_depth'       then Result := STORAGE_INIT_DEPTH_INDEX
      else if Lower = 'surcharge_depth'  then Result := STORAGE_SURCHARGE_DEPTH_INDEX
      else if Lower = 'evap_factor'      then Result := STORAGE_EVAP_FACTOR_INDEX
      else if Lower = 'seepage'          then Result := STORAGE_SEEPAGE_INDEX
      else if Lower = 'geometry'         then Result := STORAGE_GEOMETRY_INDEX
      else if Lower = 'coeff0'           then Result := STORAGE_COEFF0_INDEX
      else if Lower = 'coeff1'           then Result := STORAGE_COEFF1_INDEX
      else if Lower = 'coeff2'           then Result := STORAGE_COEFF2_INDEX
      else if Lower = 'area_table'       then Result := STORAGE_ATABLE_INDEX;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// LinkPropIndex — JSON name → Data[] index for element.set
// Returns -1 for unknown or read-only properties.
// ---------------------------------------------------------------------------

function LinkPropIndex(Ltype: Integer; const PropName: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(PropName);
  Result := -1;

  case Ltype of
    CONDUIT:
    begin
      if Lower = 'shape'        then Result := CONDUIT_SHAPE_INDEX
      else if Lower = 'geom1'        then Result := CONDUIT_GEOM1_INDEX
      else if Lower = 'geom2'        then Result := CONDUIT_GEOM2_INDEX
      else if Lower = 'geom3'        then Result := CONDUIT_GEOM3_INDEX
      else if Lower = 'geom4'        then Result := CONDUIT_GEOM4_INDEX
      else if Lower = 'length'       then Result := CONDUIT_LENGTH_INDEX
      else if Lower = 'roughness'    then Result := CONDUIT_ROUGHNESS_INDEX
      else if Lower = 'in_offset'    then Result := CONDUIT_INLET_HT_INDEX
      else if Lower = 'out_offset'   then Result := CONDUIT_OUTLET_HT_INDEX
      else if Lower = 'init_flow'    then Result := CONDUIT_INIT_FLOW_INDEX
      else if Lower = 'max_flow'     then Result := CONDUIT_MAX_FLOW_INDEX
      else if Lower = 'entry_loss'   then Result := CONDUIT_ENTRY_LOSS_INDEX
      else if Lower = 'exit_loss'    then Result := CONDUIT_EXIT_LOSS_INDEX
      else if Lower = 'avg_loss'     then Result := CONDUIT_AVG_LOSS_INDEX
      else if Lower = 'seepage'      then Result := CONDUIT_SEEPAGE_INDEX
      else if Lower = 'check_valve'  then Result := CONDUIT_CHECK_VALVE_INDEX
      else if Lower = 'culvert_code' then Result := CONDUIT_CULVERT_INDEX
      else if Lower = 'barrels'      then Result := CONDUIT_BARRELS_INDEX;
    end;

    PUMP:
    begin
      if Lower = 'pump_curve'    then Result := PUMP_CURVE_INDEX
      else if Lower = 'init_status'   then Result := PUMP_STATUS_INDEX
      else if Lower = 'startup_depth' then Result := PUMP_STARTUP_INDEX
      else if Lower = 'shutoff_depth' then Result := PUMP_SHUTOFF_INDEX;
    end;

    ORIFICE:
    begin
      if Lower = 'orifice_type'    then Result := ORIFICE_TYPE_INDEX
      else if Lower = 'shape'           then Result := ORIFICE_SHAPE_INDEX
      else if Lower = 'height'          then Result := ORIFICE_HEIGHT_INDEX
      else if Lower = 'width'           then Result := ORIFICE_WIDTH_INDEX
      else if Lower = 'bottom_height'   then Result := ORIFICE_BOTTOM_HT_INDEX
      else if Lower = 'discharge_coeff' then Result := ORIFICE_COEFF_INDEX
      else if Lower = 'flap_gate'       then Result := ORIFICE_FLAPGATE_INDEX;
    end;

    WEIR:
    begin
      if Lower = 'weir_type'       then Result := WEIR_TYPE_INDEX
      else if Lower = 'height'          then Result := WEIR_HEIGHT_INDEX
      else if Lower = 'length'          then Result := WEIR_WIDTH_INDEX
      else if Lower = 'side_slope'      then Result := WEIR_SLOPE_INDEX
      else if Lower = 'discharge_coeff' then Result := WEIR_COEFF_INDEX
      else if Lower = 'flap_gate'       then Result := WEIR_FLAPGATE_INDEX
      else if Lower = 'end_contractions' then Result := WEIR_CONTRACT_INDEX
      else if Lower = 'end_coeff'       then Result := WEIR_END_COEFF_INDEX;
    end;

    OUTLET:
    begin
      if Lower = 'offset_height'   then Result := OUTLET_CREST_INDEX
      else if Lower = 'flap_gate'       then Result := OUTLET_FLAPGATE_INDEX
      else if Lower = 'outlet_type'     then Result := OUTLET_TYPE_INDEX
      else if Lower = 'discharge_curve' then Result := OUTLET_QTABLE_INDEX;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// InitNodeDefaults — post-creation fix-up for Data[] fields that
// Uutils.CopyStringArray leaves nil when DefProp has a short array.
// Call after CopyStringArray when creating a new node via element.add.
// ---------------------------------------------------------------------------

procedure InitNodeDefaults(N: TNode; Ntype: Integer);
begin
  case Ntype of
    JUNCTION:
    begin
      if N.Data[JUNCTION_PONDED_AREA_INDEX] = '' then
        N.Data[JUNCTION_PONDED_AREA_INDEX] := '0';
    end;
  end;
end;

initialization

finalization

end.
