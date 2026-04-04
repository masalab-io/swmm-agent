unit SwmmAgentAPI;

{
  SwmmAgentAPI.pas
  ----------------
  Command handlers for the SWMM named-pipe agent.

  All public entry point:
    function HandleCommand(const Request: string): string;

  This unit runs on the VCL main thread (called via TThread.Synchronize),
  so no additional locking is required when accessing SWMM globals.
}

interface

function HandleCommand(const Request: string): string;

implementation

uses
  System.SysUtils,
  System.JSON,
  Vcl.Forms,
  Uglobals,
  Uproject,
  Uutils,
  Dwelcome,
  Fproped,
  Fmain;

// ---------------------------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------------------------

function JsonStr(const S: string): string;
var
  I: Integer;
  C: Char;
  Buf: TStringBuilder;
begin
  Buf := TStringBuilder.Create;
  try
    Buf.Append('"');
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '"':  Buf.Append('\"');
        '\':  Buf.Append('\\');
        #10:  Buf.Append('\n');
        #13:  Buf.Append('\r');
        #9:   Buf.Append('\t');
      else
        if Ord(C) < 32 then
          Buf.AppendFormat('\u%.4x', [Ord(C)])
        else
          Buf.Append(C);
      end;
    end;
    Buf.Append('"');
    Result := Buf.ToString;
  finally
    Buf.Free;
  end;
end;

function OkResult(const DataJson: string): string;
begin
  Result := '{"ok":true,"data":' + DataJson + '}';
end;

function ErrResult(const Msg: string): string;
begin
  Result := '{"ok":false,"error":' + JsonStr(Msg) + '}';
end;

// ---------------------------------------------------------------------------
// Type lookup helpers
// ---------------------------------------------------------------------------

function NodeTypeCode(const S: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if Lower = 'junction' then
    Result := JUNCTION
  else if Lower = 'outfall' then
    Result := OUTFALL
  else if Lower = 'divider' then
    Result := DIVIDER
  else if Lower = 'storage' then
    Result := STORAGE
  else
    Result := -1;
end;

function LinkTypeCode(const S: string): Integer;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if Lower = 'conduit' then
    Result := CONDUIT
  else if Lower = 'pump' then
    Result := PUMP
  else if Lower = 'orifice' then
    Result := ORIFICE
  else if Lower = 'weir' then
    Result := WEIR
  else if Lower = 'outlet' then
    Result := OUTLET
  else
    Result := -1;
end;

// ---------------------------------------------------------------------------
// Command handlers
// ---------------------------------------------------------------------------

function HandleElementGet(Cmd: TJSONObject): string;
var
  TypeStr, IdStr: string;
  Ntype, Ltype, Index: Integer;
  Node: TNode;
  Link: TLink;
  Sb: TStringBuilder;
begin
  // Validate required fields
  if (Cmd.GetValue('type') = nil) or (Cmd.GetValue('id') = nil) then
  begin
    Result := ErrResult('element.get requires "type" and "id" fields');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  TypeStr := Cmd.GetValue('type').Value;
  IdStr   := Cmd.GetValue('id').Value;

  Ntype := NodeTypeCode(TypeStr);
  if Ntype >= 0 then
  begin
    // Node lookup
    if not Project.FindNode(IdStr, Ntype, Index) then
    begin
      Result := ErrResult('Node not found: ' + IdStr);
      Exit;
    end;

    Node := Project.GetNode(Ntype, Index);
    if not Assigned(Node) then
    begin
      Result := ErrResult('GetNode returned nil for: ' + IdStr);
      Exit;
    end;

    Sb := TStringBuilder.Create;
    try
      Sb.Append('{');
      Sb.Append('"id":');           Sb.Append(JsonStr(string(Node.ID)));
      Sb.Append(',"type":');        Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"x":');           Sb.AppendFormat('%.6g', [Node.X]);
      Sb.Append(',"y":');           Sb.AppendFormat('%.6g', [Node.Y]);
      Sb.Append(',"invert_elev":'); Sb.Append(JsonStr(Node.Data[NODE_INVERT_INDEX]));
      if Ntype = JUNCTION then
      begin
        Sb.Append(',"max_depth":');
        Sb.Append(JsonStr(Node.Data[JUNCTION_MAX_DEPTH_INDEX]));
        Sb.Append(',"init_depth":');
        Sb.Append(JsonStr(Node.Data[JUNCTION_INIT_DEPTH_INDEX]));
        Sb.Append(',"surcharge_depth":');
        Sb.Append(JsonStr(Node.Data[JUNCTION_SURCHARGE_DEPTH_INDEX]));
        Sb.Append(',"ponded_area":');
        Sb.Append(JsonStr(Node.Data[JUNCTION_PONDED_AREA_INDEX]));
      end;
      Sb.Append('}');
      Result := OkResult(Sb.ToString);
    finally
      Sb.Free;
    end;
    Exit;
  end;

  Ltype := LinkTypeCode(TypeStr);
  if Ltype >= 0 then
  begin
    // Link lookup
    if not Project.FindLink(IdStr, Ltype, Index) then
    begin
      Result := ErrResult('Link not found: ' + IdStr);
      Exit;
    end;

    Link := Project.GetLink(Ltype, Index);
    if not Assigned(Link) then
    begin
      Result := ErrResult('GetLink returned nil for: ' + IdStr);
      Exit;
    end;

    Sb := TStringBuilder.Create;
    try
      Sb.Append('{');
      Sb.Append('"id":');           Sb.Append(JsonStr(string(Link.ID)));
      Sb.Append(',"type":');        Sb.Append(JsonStr(TypeStr));
      Sb.Append(',"inlet_node":');  Sb.Append(JsonStr(Link.Data[UP_INDEX]));
      Sb.Append(',"outlet_node":'); Sb.Append(JsonStr(Link.Data[DN_INDEX]));
      if Ltype = CONDUIT then
      begin
        Sb.Append(',"length":');
        Sb.Append(JsonStr(Link.Data[CONDUIT_LENGTH_INDEX]));
        Sb.Append(',"roughness":');
        Sb.Append(JsonStr(Link.Data[CONDUIT_ROUGHNESS_INDEX]));
        Sb.Append(',"in_offset":');
        Sb.Append(JsonStr(Link.Data[CONDUIT_INLET_HT_INDEX]));
        Sb.Append(',"out_offset":');
        Sb.Append(JsonStr(Link.Data[CONDUIT_OUTLET_HT_INDEX]));
      end;
      Sb.Append('}');
      Result := OkResult(Sb.ToString);
    finally
      Sb.Free;
    end;
    Exit;
  end;

  Result := ErrResult('Unknown element type: ' + TypeStr);
end;

function HandleElementSet(Cmd: TJSONObject): string;
var
  TypeStr, IdStr, PropStr, ValueStr: string;
  Ntype, Ltype, Index, PropIndex: Integer;
  Node: TNode;
  Link: TLink;
begin
  // Validate required fields
  if (Cmd.GetValue('type') = nil) or (Cmd.GetValue('id') = nil) or
     (Cmd.GetValue('prop') = nil) or (Cmd.GetValue('value') = nil) then
  begin
    Result := ErrResult('element.set requires "type", "id", "prop", and "value" fields');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  TypeStr  := Cmd.GetValue('type').Value;
  IdStr    := Cmd.GetValue('id').Value;
  PropStr  := LowerCase(Cmd.GetValue('prop').Value);
  ValueStr := Cmd.GetValue('value').Value;

  // --- Node path ---
  Ntype := NodeTypeCode(TypeStr);
  if Ntype >= 0 then
  begin
    if not Project.FindNode(IdStr, Ntype, Index) then
    begin
      Result := ErrResult('Node not found: ' + IdStr);
      Exit;
    end;

    Node := Project.GetNode(Ntype, Index);
    if not Assigned(Node) then
    begin
      Result := ErrResult('GetNode returned nil for: ' + IdStr);
      Exit;
    end;

    if PropStr = 'invert_elev' then
      PropIndex := NODE_INVERT_INDEX
    else if PropStr = 'max_depth' then
    begin
      if Ntype <> JUNCTION then
      begin
        Result := ErrResult('max_depth is only supported for junction nodes');
        Exit;
      end;
      PropIndex := JUNCTION_MAX_DEPTH_INDEX;
    end
    else if PropStr = 'init_depth' then
    begin
      if Ntype <> JUNCTION then
      begin
        Result := ErrResult('init_depth is only supported for junction nodes');
        Exit;
      end;
      PropIndex := JUNCTION_INIT_DEPTH_INDEX;
    end
    else if PropStr = 'surcharge_depth' then
    begin
      if Ntype <> JUNCTION then
      begin
        Result := ErrResult('surcharge_depth is only supported for junction nodes');
        Exit;
      end;
      PropIndex := JUNCTION_SURCHARGE_DEPTH_INDEX;
    end
    else if PropStr = 'ponded_area' then
    begin
      if Ntype <> JUNCTION then
      begin
        Result := ErrResult('ponded_area is only supported for junction nodes');
        Exit;
      end;
      PropIndex := JUNCTION_PONDED_AREA_INDEX;
    end
    else
    begin
      Result := ErrResult('Unsupported node property: ' + PropStr);
      Exit;
    end;

    Node.Data[PropIndex] := ValueStr;
    if PropEditForm.Visible then PropEditForm.Hide;
    Result := '{"ok":true}';
    Exit;
  end;

  // --- Link path ---
  Ltype := LinkTypeCode(TypeStr);
  if Ltype >= 0 then
  begin
    if not Project.FindLink(IdStr, Ltype, Index) then
    begin
      Result := ErrResult('Link not found: ' + IdStr);
      Exit;
    end;

    Link := Project.GetLink(Ltype, Index);
    if not Assigned(Link) then
    begin
      Result := ErrResult('GetLink returned nil for: ' + IdStr);
      Exit;
    end;

    if Ltype <> CONDUIT then
    begin
      Result := ErrResult('element.set currently only supports conduit links');
      Exit;
    end;

    if PropStr = 'length' then
      PropIndex := CONDUIT_LENGTH_INDEX
    else if PropStr = 'roughness' then
      PropIndex := CONDUIT_ROUGHNESS_INDEX
    else if PropStr = 'in_offset' then
      PropIndex := CONDUIT_INLET_HT_INDEX
    else if PropStr = 'out_offset' then
      PropIndex := CONDUIT_OUTLET_HT_INDEX
    else
    begin
      Result := ErrResult('Unsupported conduit property: ' + PropStr);
      Exit;
    end;

    Link.Data[PropIndex] := ValueStr;
    if PropEditForm.Visible then PropEditForm.Hide;
    Result := '{"ok":true}';
    Exit;
  end;

  Result := ErrResult('Unknown element type: ' + TypeStr);
end;

function HandleElementList(Cmd: TJSONObject): string;
var
  TypeStr: string;
  Ntype, I: Integer;
  Node: TNode;
  Sb: TStringBuilder;
  First: Boolean;
begin
  if Cmd.GetValue('type') = nil then
  begin
    Result := ErrResult('element.list requires "type" field');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  TypeStr := Cmd.GetValue('type').Value;
  Ntype   := NodeTypeCode(TypeStr);

  if Ntype < 0 then
  begin
    Result := ErrResult('Unknown or unsupported element type: ' + TypeStr);
    Exit;
  end;

  Sb := TStringBuilder.Create;
  try
    Sb.Append('{"type":');
    Sb.Append(JsonStr(TypeStr));
    Sb.Append(',"ids":[');

    First := True;
    if Assigned(Project.Lists[Ntype]) then
    begin
      for I := 0 to Project.Lists[Ntype].Count - 1 do
      begin
        Node := Project.GetNode(Ntype, I);
        if Assigned(Node) then
        begin
          if not First then
            Sb.Append(',');
          Sb.Append(JsonStr(string(Node.ID)));
          First := False;
        end;
      end;
    end;

    Sb.Append(']}');
    Result := OkResult(Sb.ToString);
  finally
    Sb.Free;
  end;
end;

function HandleSimulateRun: string;
begin
  if not Assigned(MainForm) then
  begin
    Result := ErrResult('MainForm is not available');
    Exit;
  end;

  MainForm.MnuProjectRunSimulationClick(nil);
  Result := '{"ok":true,"status":"started"}';
end;

function HandleSimulateStatus: string;
var
  StatusStr: string;
begin
  case RunStatus of
    rsSuccess:      StatusStr := 'success';
    rsWarning:      StatusStr := 'warning';
    rsError:        StatusStr := 'error';
    rsFailed:       StatusStr := 'failed';
    rsStopped:      StatusStr := 'stopped';
    rsNone:         StatusStr := 'none';
  else
    StatusStr := 'unknown';
  end;

  Result := '{"ok":true,"status":' + JsonStr(StatusStr) + '}';
end;

function HandleFileOpen(Cmd: TJSONObject): string;
var
  PathStr: string;
begin
  if Cmd.GetValue('path') = nil then
  begin
    Result := ErrResult('file.open requires "path" field');
    Exit;
  end;

  PathStr := Cmd.GetValue('path').Value;

  if not FileExists(PathStr) then
  begin
    Result := ErrResult('File not found: ' + PathStr);
    Exit;
  end;

  if not Assigned(MainForm) then
  begin
    Result := ErrResult('MainForm is not available');
    Exit;
  end;

  // Clear existing model data, then load the new file.
  // OpenFile is private; we replicate its effect using public methods.
  MainForm.CloseForms;                        // close any open result/graph windows
  if Assigned(Project) then Project.Clear;
  InputFileName := PathStr;
  MainForm.ReadInpFile(PathStr);
  MainForm.RefreshMapForm;

  // Close the Welcome screen if it is still visible (it runs as a modal dialog).
  // It is created as a local instance so we find it via Screen.Forms by class.
  var I: Integer;
  for I := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[I] is TWelcomeForm then
    begin
      Screen.Forms[I].Close;
      Break;
    end;

  Result := OkResult('{"file":' + JsonStr(InputFileName) + '}');
end;

function HandleFileInfo: string;
begin
  Result := OkResult('{"file":' + JsonStr(InputFileName) + '}');
end;

function HandleElementAdd(Cmd: TJSONObject): string;
var
  TypeStr, IdStr: string;
  Ntype, DupIndex, I: Integer;
  N: TNode;
  X, Y: Double;
  XVal, YVal: TJSONValue;
begin
  if (Cmd.GetValue('type') = nil) or (Cmd.GetValue('id') = nil) then
  begin
    Result := ErrResult('element.add requires "type" and "id" fields');
    Exit;
  end;

  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  TypeStr := Cmd.GetValue('type').Value;
  IdStr   := Cmd.GetValue('id').Value;

  Ntype := NodeTypeCode(TypeStr);
  if Ntype < 0 then
  begin
    Result := ErrResult('element.add currently only supports node types (junction, outfall, divider, storage)');
    Exit;
  end;

  // Check for duplicate ID
  if Project.FindNode(IdStr, Ntype, DupIndex) then
  begin
    Result := ErrResult('A node with ID "' + IdStr + '" already exists');
    Exit;
  end;

  // Parse coordinates (default 0 if not supplied)
  X := 0.0;
  Y := 0.0;
  XVal := Cmd.GetValue('x');
  YVal := Cmd.GetValue('y');
  if Assigned(XVal) then X := StrToFloatDef(XVal.Value, 0.0);
  if Assigned(YVal) then Y := StrToFloatDef(YVal.Value, 0.0);

  // Create node, copy default properties, add to project
  N := TNode.Create;
  N.Ntype        := Ntype;
  N.X            := X;
  N.Y            := Y;
  N.OutFileIndex := -1;
  N.RptFileIndex := -1;
  N.ColorIndex   := -1;
  Uutils.CopyStringArray(Project.DefProp[Ntype].Data, N.Data);

  Project.Lists[Ntype].AddObject(IdStr, N);
  I := Project.Lists[Ntype].Count - 1;
  N.ID := PChar(Project.Lists[Ntype].Strings[I]);
  Project.HasItems[Ntype] := True;

  Result := OkResult('{"id":' + JsonStr(IdStr) + ',"type":' + JsonStr(TypeStr) + '}');
end;

// ---------------------------------------------------------------------------
// Main dispatcher
// ---------------------------------------------------------------------------

function HandleCommand(const Request: string): string;
var
  Root: TJSONValue;
  Cmd: TJSONObject;
  CmdStr: string;
begin
  Root := nil;
  try
    try
      Root := TJSONObject.ParseJSONValue(Request);

      if not (Root is TJSONObject) then
      begin
        Result := ErrResult('Request must be a JSON object');
        Exit;
      end;

      Cmd := TJSONObject(Root);

      if Cmd.GetValue('cmd') = nil then
      begin
        Result := ErrResult('Missing "cmd" field');
        Exit;
      end;

      CmdStr := LowerCase(Cmd.GetValue('cmd').Value);

      if CmdStr = 'element.get' then
        Result := HandleElementGet(Cmd)
      else if CmdStr = 'element.set' then
        Result := HandleElementSet(Cmd)
      else if CmdStr = 'element.list' then
        Result := HandleElementList(Cmd)
      else if CmdStr = 'element.add' then
        Result := HandleElementAdd(Cmd)
      else if CmdStr = 'simulate.run' then
        Result := HandleSimulateRun
      else if CmdStr = 'simulate.status' then
        Result := HandleSimulateStatus
      else if CmdStr = 'file.open' then
        Result := HandleFileOpen(Cmd)
      else if CmdStr = 'file.info' then
        Result := HandleFileInfo
      else
        Result := ErrResult('Unknown command: "' + CmdStr + '"');

    except
      on E: Exception do
        Result := ErrResult('Exception: ' + E.Message);
    end;
  finally
    Root.Free;
  end;
end;

initialization

finalization

end.
