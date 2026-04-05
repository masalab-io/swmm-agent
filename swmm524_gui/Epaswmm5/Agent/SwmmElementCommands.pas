unit SwmmElementCommands;

{
  SwmmElementCommands.pas
  -----------------------
  Handlers for element.* named-pipe commands.

  Called from SwmmAgentAPI.HandleCommand on the VCL main thread.

  All Data[] index constants are owned by SwmmElementSchema — this unit
  does not reference Uproject index constants directly.
}

interface

uses
  System.JSON;

function HandleElementGet(Cmd: TJSONObject): string;
function HandleElementSet(Cmd: TJSONObject): string;
function HandleElementList(Cmd: TJSONObject): string;
function HandleElementAdd(Cmd: TJSONObject): string;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Vcl.Forms,
  Uglobals,
  Uproject,
  Uutils,
  Uedit,
  Fproped,
  SwmmJsonUtils,
  SwmmElementSchema,
  SwmmAgentConfig;

// ---------------------------------------------------------------------------
// UI perception helper — briefly show the property editor for an element,
// then restore it to its previous visibility state.
// ---------------------------------------------------------------------------

procedure FlashPropEditor(ObjType, Index: Integer);
var
  WasVisible: Boolean;
begin
  WasVisible := PropEditForm.Visible;
  PropEditForm.Show;
  UpdateEditor(ObjType, Index);
  PropEditForm.BringToFront;
  Application.ProcessMessages;
  Sleep(UI_FLASH_DELAY_MS);
  if not WasVisible then PropEditForm.Hide;
end;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function SubTypeCode(const S: string): Integer;
begin
  if LowerCase(S) = 'subcatchment' then
    Result := SUBCATCH
  else
    Result := -1;
end;

// ---------------------------------------------------------------------------
// element.get
// ---------------------------------------------------------------------------

function HandleElementGet(Cmd: TJSONObject): string;
var
  TypeStr, IdStr: string;
  Ntype, Ltype, Stype, Index, ReqLtype, ReqNtype: Integer;
  Node: TNode;
  Link: TLink;
  Sub: TSubcatch;
begin
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

  // --- Node types ---
  Ntype := NodeTypeCode(TypeStr);
  if Ntype >= 0 then
  begin
    ReqNtype := Ntype;
    if not Project.FindNode(IdStr, Ntype, Index) or (Ntype <> ReqNtype) then
    begin
      Result := ErrResult('Node of type "' + TypeStr + '" not found: ' + IdStr);
      Exit;
    end;

    Node := Project.GetNode(Ntype, Index);
    if not Assigned(Node) then
    begin
      Result := ErrResult('GetNode returned nil for: ' + IdStr);
      Exit;
    end;

    FlashPropEditor(Ntype, Index);
    case Ntype of
      JUNCTION: Result := OkResult(SerializeJunction(Node, TypeStr));
      OUTFALL:  Result := OkResult(SerializeOutfall(Node, TypeStr));
      DIVIDER:  Result := OkResult(SerializeDivider(Node, TypeStr));
      STORAGE:  Result := OkResult(SerializeStorage(Node, TypeStr));
    else
      Result := ErrResult('Unsupported node type: ' + TypeStr);
    end;
    Exit;
  end;

  // --- Link types ---
  Ltype := LinkTypeCode(TypeStr);
  if Ltype >= 0 then
  begin
    ReqLtype := Ltype;
    if not Project.FindLink(IdStr, Ltype, Index) or (Ltype <> ReqLtype) then
    begin
      Result := ErrResult('Link of type "' + TypeStr + '" not found: ' + IdStr);
      Exit;
    end;

    Link := Project.GetLink(Ltype, Index);
    if not Assigned(Link) then
    begin
      Result := ErrResult('GetLink returned nil for: ' + IdStr);
      Exit;
    end;

    FlashPropEditor(Ltype, Index);
    case Ltype of
      CONDUIT: Result := OkResult(SerializeConduit(Link, TypeStr));
      PUMP:    Result := OkResult(SerializePump(Link, TypeStr));
      ORIFICE: Result := OkResult(SerializeOrifice(Link, TypeStr));
      WEIR:    Result := OkResult(SerializeWeir(Link, TypeStr));
      OUTLET:  Result := OkResult(SerializeOutlet(Link, TypeStr));
    else
      Result := ErrResult('Unsupported link type: ' + TypeStr);
    end;
    Exit;
  end;

  // --- Subcatchment ---
  Stype := SubTypeCode(TypeStr);
  if Stype >= 0 then
  begin
    Index := Project.Lists[SUBCATCH].IndexOf(IdStr);
    if Index < 0 then
    begin
      Result := ErrResult('Subcatchment not found: ' + IdStr);
      Exit;
    end;

    Sub := Project.GetSubcatch(SUBCATCH, Index);
    if not Assigned(Sub) then
    begin
      Result := ErrResult('GetSubcatch returned nil for: ' + IdStr);
      Exit;
    end;

    FlashPropEditor(SUBCATCH, Index);
    Result := OkResult(SerializeSubcatch(Sub, TypeStr));
    Exit;
  end;

  Result := ErrResult('Unknown element type: ' + TypeStr);
end;

// ---------------------------------------------------------------------------
// element.set
// ---------------------------------------------------------------------------

function HandleElementSet(Cmd: TJSONObject): string;
var
  TypeStr, IdStr, PropStr, ValueStr: string;
  Ntype, Ltype, Index, PropIndex, ReqLtype, ReqNtype: Integer;
  Node: TNode;
  Link: TLink;
begin
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

  Ntype := NodeTypeCode(TypeStr);
  if Ntype >= 0 then
  begin
    ReqNtype := Ntype;
    if not Project.FindNode(IdStr, Ntype, Index) or (Ntype <> ReqNtype) then
    begin
      Result := ErrResult('Node of type "' + TypeStr + '" not found: ' + IdStr);
      Exit;
    end;

    Node := Project.GetNode(Ntype, Index);
    if not Assigned(Node) then
    begin
      Result := ErrResult('GetNode returned nil for: ' + IdStr);
      Exit;
    end;

    PropIndex := NodePropIndex(Ntype, PropStr);
    if PropIndex < 0 then
    begin
      Result := ErrResult('Unsupported property "' + PropStr + '" for type "' + TypeStr + '"');
      Exit;
    end;

    Node.Data[PropIndex] := ValueStr;
    FlashPropEditor(Ntype, Index);
    Result := '{"ok":true}';
    Exit;
  end;

  Ltype := LinkTypeCode(TypeStr);
  if Ltype >= 0 then
  begin
    ReqLtype := Ltype;
    if not Project.FindLink(IdStr, Ltype, Index) or (Ltype <> ReqLtype) then
    begin
      Result := ErrResult('Link of type "' + TypeStr + '" not found: ' + IdStr);
      Exit;
    end;

    Link := Project.GetLink(Ltype, Index);
    if not Assigned(Link) then
    begin
      Result := ErrResult('GetLink returned nil for: ' + IdStr);
      Exit;
    end;

    PropIndex := LinkPropIndex(Ltype, PropStr);
    if PropIndex < 0 then
    begin
      Result := ErrResult('Unsupported property "' + PropStr + '" for type "' + TypeStr + '"');
      Exit;
    end;

    Link.Data[PropIndex] := ValueStr;
    FlashPropEditor(Ltype, Index);
    Result := '{"ok":true}';
    Exit;
  end;

  Result := ErrResult('Unknown element type: ' + TypeStr);
end;

// ---------------------------------------------------------------------------
// element.list
// ---------------------------------------------------------------------------

function HandleElementList(Cmd: TJSONObject): string;
var
  TypeStr: string;
  Ntype, Ltype, Stype, I: Integer;
  Node: TNode;
  Link: TLink;
  Sub: TSubcatch;
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

  Sb := TStringBuilder.Create;
  try
    Sb.Append('{"type":');
    Sb.Append(JsonStr(TypeStr));
    Sb.Append(',"ids":[');
    First := True;

    Ntype := NodeTypeCode(TypeStr);
    if Ntype >= 0 then
    begin
      if Assigned(Project.Lists[Ntype]) then
      begin
        for I := 0 to Project.Lists[Ntype].Count - 1 do
        begin
          Node := Project.GetNode(Ntype, I);
          if Assigned(Node) then
          begin
            if not First then Sb.Append(',');
            Sb.Append(JsonStr(string(Node.ID)));
            First := False;
          end;
        end;
      end;
      Sb.Append(']}');
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    Ltype := LinkTypeCode(TypeStr);
    if Ltype >= 0 then
    begin
      if Assigned(Project.Lists[Ltype]) then
      begin
        for I := 0 to Project.Lists[Ltype].Count - 1 do
        begin
          Link := Project.GetLink(Ltype, I);
          if Assigned(Link) then
          begin
            if not First then Sb.Append(',');
            Sb.Append(JsonStr(string(Link.ID)));
            First := False;
          end;
        end;
      end;
      Sb.Append(']}');
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    Stype := SubTypeCode(TypeStr);
    if Stype >= 0 then
    begin
      if Assigned(Project.Lists[SUBCATCH]) then
      begin
        for I := 0 to Project.Lists[SUBCATCH].Count - 1 do
        begin
          Sub := Project.GetSubcatch(SUBCATCH, I);
          if Assigned(Sub) then
          begin
            if not First then Sb.Append(',');
            Sb.Append(JsonStr(string(Sub.ID)));
            First := False;
          end;
        end;
      end;
      Sb.Append(']}');
      Result := OkResult(Sb.ToString);
      Exit;
    end;

    Result := ErrResult('Unknown or unsupported element type: ' + TypeStr);
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// element.add
// ---------------------------------------------------------------------------

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

  // FindNode is a var-parameter function that overwrites Ntype with the found type.
  // Save and restore so the add uses the originally requested type.
  DupIndex := Ntype;
  if Project.FindNode(IdStr, Ntype, DupIndex) then
  begin
    Result := ErrResult('A node with ID "' + IdStr + '" already exists');
    Exit;
  end;
  Ntype := NodeTypeCode(TypeStr); // restore — FindNode overwrote it

  X := 0.0;
  Y := 0.0;
  XVal := Cmd.GetValue('x');
  YVal := Cmd.GetValue('y');
  if Assigned(XVal) then X := StrToFloatDef(XVal.Value, 0.0);
  if Assigned(YVal) then Y := StrToFloatDef(YVal.Value, 0.0);

  N := TNode.Create;
  N.Ntype        := Ntype;
  N.X            := X;
  N.Y            := Y;
  N.OutFileIndex := -1;
  N.RptFileIndex := -1;
  N.ColorIndex   := -1;
  Uutils.CopyStringArray(Project.DefProp[Ntype].Data, N.Data);
  InitNodeDefaults(N, Ntype);

  Project.Lists[Ntype].AddObject(IdStr, N);
  I := Project.Lists[Ntype].Count - 1;
  N.ID := PChar(Project.Lists[Ntype].Strings[I]);
  Project.HasItems[Ntype] := True;

  Result := OkResult('{"id":' + JsonStr(IdStr) + ',"type":' + JsonStr(TypeStr) + '}');
end;

initialization

finalization

end.
