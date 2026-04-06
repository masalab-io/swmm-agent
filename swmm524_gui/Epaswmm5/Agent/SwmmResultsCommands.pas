unit SwmmResultsCommands;

{
  SwmmResultsCommands.pas
  -----------------------
  Handlers for results.* named-pipe commands.

  Called from SwmmAgentAPI.HandleCommand on the VCL main thread.

  Requires a successful simulate.run to have been called first, which
  opens the binary output file and calls Uoutput.GetBasicOutput so that
  Nperiods, StartDateTime, ReportStep and each element's OutFileIndex
  are populated.

  results.get     — full time-series for one element / one variable
  results.summary — max and min across all periods for every variable
                    of the given element type
}

interface

uses
  System.JSON;

function HandleResultsGet(Cmd: TJSONObject): string;
function HandleResultsSummary(Cmd: TJSONObject): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Vcl.Forms,
  Uglobals,
  Uproject,
  Uoutput,
  Fmain,
  Fgraph,
  SwmmJsonUtils,
  SwmmAgentConfig;

// ---------------------------------------------------------------------------
// UI perception helper — briefly open a time series graph for an element,
// then close it.  ObjGroupType is NODES, LINKS, or SUBCATCHMENTS.
// ---------------------------------------------------------------------------

procedure FlashGraphWindow(ObjGroupType: Integer; const ObjId: string;
  VarCode: Integer);
var
  RS:    TReportSelection;
  Items: TStringList;
  GForm: TGraphForm;
begin
  Items := TStringList.Create;
  try
    Items.Add(ObjId);

    RS.ReportType              := TIMESERIESPLOT;
    RS.ObjectType              := ObjGroupType;
    RS.XObjectType             := ObjGroupType;
    RS.StartDateIndex          := 0;
    RS.EndDateIndex            := Nperiods - 1;
    RS.Items                   := Items;
    RS.ItemCount               := 1;
    RS.VariableCount           := 1;
    RS.Variables[0]            := VarCode;
    RS.DateTimeDisplay         := True;
    RS.ReportItems[0].ObjType  := ObjGroupType;
    RS.ReportItems[0].ObjName  := ObjId;
    RS.ReportItems[0].Variable := VarCode;
    RS.ReportItems[0].Axis     := 1;

    GForm := TGraphForm.Create(MainForm);
    try
      if GForm.CreateGraph(RS) then
      begin
        GForm.RefreshGraph;
        GForm.Show;
        GForm.BringToFront;
        Application.ProcessMessages;
        Sleep(UI_FLASH_DELAY_MS);
      end;
    finally
      GForm.Close;  // caFree handles cleanup
    end;
  finally
    Items.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Variable-name → view-variable-code helpers
// (Constants come from viewvars.txt, $Included into Uglobals.pas)
// ---------------------------------------------------------------------------

function NodeVarCode(const S: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if      Lower = 'depth'          then Result := NODEDEPTH
  else if Lower = 'head'           then Result := HEAD
  else if Lower = 'volume'         then Result := VOLUME
  else if Lower = 'lateral_inflow' then Result := LATFLOW
  else if Lower = 'total_inflow'   then Result := INFLOW
  else if Lower = 'flooding'       then Result := OVERFLOW
  else
    Result := -1;
end;

function LinkVarCode(const S: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if      Lower = 'flow'     then Result := FLOW
  else if Lower = 'depth'    then Result := LINKDEPTH
  else if Lower = 'velocity' then Result := VELOCITY
  else if Lower = 'volume'   then Result := LINKVOLUME
  else if Lower = 'capacity' then Result := CAPACITY
  else
    Result := -1;
end;

function SubcatchVarCode(const S: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if      Lower = 'rainfall'     then Result := RAINFALL
  else if Lower = 'snow_depth'   then Result := SNOWDEPTH
  else if Lower = 'evaporation'  then Result := EVAP
  else if Lower = 'infiltration' then Result := INFIL
  else if Lower = 'runoff'       then Result := RUNOFF
  else if Lower = 'gw_flow'      then Result := GW_FLOW
  else if Lower = 'gw_elev'      then Result := GW_ELEV
  else if Lower = 'soil_moisture' then Result := GW_MOIST
  else
    Result := -1;
end;

// ---------------------------------------------------------------------------
// ISO-8601 datetime helper
// ---------------------------------------------------------------------------

function IsoDateTime(DT: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', DT);
end;

// ---------------------------------------------------------------------------
// Units string for a node variable
// ---------------------------------------------------------------------------

function NodeVarUnits(VarCode: Integer): string;
begin
  if (VarCode >= NODEOUTVAR1) and (VarCode <= NODEVIEWS) then
    Result := NodeUnits[VarCode].Units
  else
    Result := '';
end;

function LinkVarUnits(VarCode: Integer): string;
begin
  if (VarCode >= LINKOUTVAR1) and (VarCode <= LINKVIEWS) then
    Result := LinkUnits[VarCode].Units
  else
    Result := '';
end;

function SubcatchVarUnits(VarCode: Integer): string;
begin
  if (VarCode >= SUBCATCHOUTVAR1) and (VarCode <= SUBCATCHVIEWS) then
    Result := SubcatchUnits[VarCode].Units
  else
    Result := '';
end;

// ---------------------------------------------------------------------------
// results.get
// ---------------------------------------------------------------------------

function HandleResultsGet(Cmd: TJSONObject): string;
var
  TypeStr, IdStr, VarStr: string;
  VarCode, SrcIdx, Zindex, P: Integer;
  Val: Single;
  Sb: TStringBuilder;
  First: Boolean;

  // Node path
  Ntype, NodeIndex: Integer;
  Node: TNode;

  // Link path
  Ltype, LinkIndex, RequestedLtype: Integer;
  Link: TLink;

  // Subcatch path
  SubIndex: Integer;
  Sub: TSubcatch;

begin
  if (Cmd.GetValue('type') = nil) or (Cmd.GetValue('id') = nil) or
     (Cmd.GetValue('variable') = nil) then
  begin
    Result := ErrResult('results.get requires "type", "id", and "variable" fields');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  if not RunFlag or (Nperiods <= 0) then
  begin
    Result := ErrResult('No simulation results available — run simulate.run first');
    Exit;
  end;

  TypeStr := LowerCase(Cmd.GetValue('type').Value);
  IdStr   := Cmd.GetValue('id').Value;
  VarStr  := Cmd.GetValue('variable').Value;

  Sb := TStringBuilder.Create;
  try
    // ---- Node ----
    Ntype := NodeTypeCode(TypeStr);
    if Ntype >= 0 then
    begin
      VarCode := NodeVarCode(VarStr);
      if VarCode < 0 then
      begin
        Result := ErrResult('Unknown node variable: "' + VarStr +
          '". Valid: depth, head, volume, lateral_inflow, total_inflow, flooding');
        Exit;
      end;

      if not Project.FindNode(IdStr, Ntype, NodeIndex) then
      begin
        Result := ErrResult('Node not found: ' + IdStr);
        Exit;
      end;

      Node := Project.GetNode(Ntype, NodeIndex);
      Zindex := Node.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for node: ' + IdStr +
          ' (not included in reporting)');
        Exit;
      end;

      SrcIdx := GetVarIndex(VarCode, NODES);

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"variable":'); Sb.Append(JsonStr(VarStr));
      Sb.Append(',"units":');   Sb.Append(JsonStr(NodeVarUnits(VarCode)));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(',"start_datetime":'); Sb.Append(JsonStr(IsoDateTime(StartDateTime)));
      Sb.Append(',"report_step":'); Sb.Append(IntToStr(ReportStep));
      Sb.Append(',"values":[');

      First := True;
      for P := 0 to Nperiods - 1 do
      begin
        if not First then Sb.Append(',');
        Val := GetNodeOutVal(SrcIdx, P, Zindex);
        if Val <= MISSING then
          Sb.Append('null')
        else
          Sb.AppendFormat('%.6g', [Val]);
        First := False;
      end;

      Sb.Append(']}');
      FlashGraphWindow(NODES, IdStr, VarCode);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    // ---- Link ----
    Ltype := LinkTypeCode(TypeStr);
    if Ltype >= 0 then
    begin
      VarCode := LinkVarCode(VarStr);
      if VarCode < 0 then
      begin
        Result := ErrResult('Unknown link variable: "' + VarStr +
          '". Valid: flow, depth, velocity, volume, capacity');
        Exit;
      end;

      // FindLink overwrites Ltype — save the requested type to validate
      RequestedLtype := Ltype;
      if not Project.FindLink(IdStr, Ltype, LinkIndex) or (Ltype <> RequestedLtype) then
      begin
        Result := ErrResult('Link of type "' + TypeStr + '" not found: ' + IdStr);
        Exit;
      end;

      Link := Project.GetLink(Ltype, LinkIndex);
      Zindex := Link.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for link: ' + IdStr +
          ' (not included in reporting)');
        Exit;
      end;

      SrcIdx := GetVarIndex(VarCode, LINKS);

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"variable":'); Sb.Append(JsonStr(VarStr));
      Sb.Append(',"units":');   Sb.Append(JsonStr(LinkVarUnits(VarCode)));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(',"start_datetime":'); Sb.Append(JsonStr(IsoDateTime(StartDateTime)));
      Sb.Append(',"report_step":'); Sb.Append(IntToStr(ReportStep));
      Sb.Append(',"values":[');

      First := True;
      for P := 0 to Nperiods - 1 do
      begin
        if not First then Sb.Append(',');
        Val := GetLinkOutVal(SrcIdx, P, Zindex);
        if Val <= MISSING then
          Sb.Append('null')
        else
          Sb.AppendFormat('%.6g', [Val]);
        First := False;
      end;

      Sb.Append(']}');
      FlashGraphWindow(LINKS, IdStr, VarCode);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    // ---- Subcatchment ----
    if LowerCase(TypeStr) = 'subcatchment' then
    begin
      VarCode := SubcatchVarCode(VarStr);
      if VarCode < 0 then
      begin
        Result := ErrResult('Unknown subcatchment variable: "' + VarStr +
          '". Valid: rainfall, snow_depth, evaporation, infiltration, ' +
          'runoff, gw_flow, gw_elev, soil_moisture');
        Exit;
      end;

      SubIndex := Project.Lists[SUBCATCH].IndexOf(IdStr);
      if SubIndex < 0 then
      begin
        Result := ErrResult('Subcatchment not found: ' + IdStr);
        Exit;
      end;

      Sub := Project.GetSubcatch(SUBCATCH, SubIndex);
      Zindex := Sub.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for subcatchment: ' + IdStr +
          ' (not included in reporting)');
        Exit;
      end;

      SrcIdx := GetVarIndex(VarCode, SUBCATCHMENTS);

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"variable":'); Sb.Append(JsonStr(VarStr));
      Sb.Append(',"units":');   Sb.Append(JsonStr(SubcatchVarUnits(VarCode)));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(',"start_datetime":'); Sb.Append(JsonStr(IsoDateTime(StartDateTime)));
      Sb.Append(',"report_step":'); Sb.Append(IntToStr(ReportStep));
      Sb.Append(',"values":[');

      First := True;
      for P := 0 to Nperiods - 1 do
      begin
        if not First then Sb.Append(',');
        Val := GetSubcatchOutVal(SrcIdx, P, Zindex);
        if Val <= MISSING then
          Sb.Append('null')
        else
          Sb.AppendFormat('%.6g', [Val]);
        First := False;
      end;

      Sb.Append(']}');
      FlashGraphWindow(SUBCATCHMENTS, IdStr, VarCode);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    Result := ErrResult('Unknown element type: "' + TypeStr +
      '". Valid: junction, outfall, storage, divider, conduit, pump, ' +
      'orifice, weir, outlet, subcatchment');
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// results.summary — max/min for every output variable of the element
// ---------------------------------------------------------------------------

// Append one variable's max/min scan into Sb.
// VarCode = view variable constant; ObjType = NODES/LINKS/SUBCATCHMENTS.
procedure AppendVarSummary(Sb: TStringBuilder; const VarName: string;
  VarCode, ObjType, Zindex: Integer);
var
  P, SrcIdx: Integer;
  Val, MaxVal, MinVal: Single;
begin
  SrcIdx := GetVarIndex(VarCode, ObjType);
  MaxVal := -1.0e30;
  MinVal :=  1.0e30;

  for P := 0 to Nperiods - 1 do
  begin
    case ObjType of
      NODES:        Val := GetNodeOutVal(SrcIdx, P, Zindex);
      LINKS:        Val := GetLinkOutVal(SrcIdx, P, Zindex);
      SUBCATCHMENTS: Val := GetSubcatchOutVal(SrcIdx, P, Zindex);
    else
      Val := MISSING;
    end;

    if Val > MISSING then
    begin
      if Val > MaxVal then MaxVal := Val;
      if Val < MinVal then MinVal := Val;
    end;
  end;

  Sb.Append(JsonStr(VarName));
  Sb.Append(':{"max":');
  if MaxVal > -1.0e30 then
    Sb.AppendFormat('%.6g', [MaxVal])
  else
    Sb.Append('null');
  Sb.Append(',"min":');
  if MinVal < 1.0e30 then
    Sb.AppendFormat('%.6g', [MinVal])
  else
    Sb.Append('null');
  Sb.Append('}');
end;

function HandleResultsSummary(Cmd: TJSONObject): string;
var
  TypeStr, IdStr: string;
  Zindex: Integer;
  Sb: TStringBuilder;

  Ntype, NodeIndex: Integer;
  Node: TNode;

  Ltype, LinkIndex, ReqLtype: Integer;
  Link: TLink;

  SubIndex: Integer;
  Sub: TSubcatch;

begin
  if (Cmd.GetValue('type') = nil) or (Cmd.GetValue('id') = nil) then
  begin
    Result := ErrResult('results.summary requires "type" and "id" fields');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  if not RunFlag or (Nperiods <= 0) then
  begin
    Result := ErrResult('No simulation results available — run simulate.run first');
    Exit;
  end;

  TypeStr := LowerCase(Cmd.GetValue('type').Value);
  IdStr   := Cmd.GetValue('id').Value;

  Sb := TStringBuilder.Create;
  try
    // ---- Node ----
    Ntype := NodeTypeCode(TypeStr);
    if Ntype >= 0 then
    begin
      if not Project.FindNode(IdStr, Ntype, NodeIndex) then
      begin
        Result := ErrResult('Node not found: ' + IdStr);
        Exit;
      end;

      Node := Project.GetNode(Ntype, NodeIndex);
      Zindex := Node.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for node: ' + IdStr);
        Exit;
      end;

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(','); AppendVarSummary(Sb, 'depth',          NODEDEPTH, NODES, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'head',           HEAD,      NODES, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'volume',         VOLUME,    NODES, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'lateral_inflow', LATFLOW,   NODES, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'total_inflow',   INFLOW,    NODES, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'flooding',       OVERFLOW,  NODES, Zindex);
      Sb.Append('}');
      FlashGraphWindow(NODES, IdStr, NODEDEPTH);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    // ---- Link ----
    Ltype := LinkTypeCode(TypeStr);
    if Ltype >= 0 then
    begin
      ReqLtype := Ltype;
      if not Project.FindLink(IdStr, Ltype, LinkIndex) or (Ltype <> ReqLtype) then
      begin
        Result := ErrResult('Link of type "' + TypeStr + '" not found: ' + IdStr);
        Exit;
      end;

      Link := Project.GetLink(Ltype, LinkIndex);
      Zindex := Link.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for link: ' + IdStr);
        Exit;
      end;

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(','); AppendVarSummary(Sb, 'flow',     FLOW,       LINKS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'depth',    LINKDEPTH,  LINKS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'velocity', VELOCITY,   LINKS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'volume',   LINKVOLUME, LINKS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'capacity', CAPACITY,   LINKS, Zindex);
      Sb.Append('}');
      FlashGraphWindow(LINKS, IdStr, FLOW);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    // ---- Subcatchment ----
    if LowerCase(TypeStr) = 'subcatchment' then
    begin
      SubIndex := Project.Lists[SUBCATCH].IndexOf(IdStr);
      if SubIndex < 0 then
      begin
        Result := ErrResult('Subcatchment not found: ' + IdStr);
        Exit;
      end;

      Sub := Project.GetSubcatch(SUBCATCH, SubIndex);
      Zindex := Sub.OutFileIndex;
      if Zindex < 0 then
      begin
        Result := ErrResult('No output results for subcatchment: ' + IdStr);
        Exit;
      end;

      Sb.Append('{');
      Sb.Append('"id":');       Sb.Append(JsonStr(IdStr));
      Sb.Append(',"type":');    Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"nperiods":'); Sb.Append(IntToStr(Nperiods));
      Sb.Append(','); AppendVarSummary(Sb, 'rainfall',     RAINFALL,  SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'snow_depth',   SNOWDEPTH, SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'evaporation',  EVAP,      SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'infiltration', INFIL,     SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'runoff',       RUNOFF,    SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'gw_flow',      GW_FLOW,   SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'gw_elev',      GW_ELEV,   SUBCATCHMENTS, Zindex);
      Sb.Append(','); AppendVarSummary(Sb, 'soil_moisture',GW_MOIST,  SUBCATCHMENTS, Zindex);
      Sb.Append('}');
      FlashGraphWindow(SUBCATCHMENTS, IdStr, RUNOFF);
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    Result := ErrResult('Unknown element type: "' + TypeStr + '"');
  finally
    Sb.Free;
  end;
end;

initialization

finalization

end.
