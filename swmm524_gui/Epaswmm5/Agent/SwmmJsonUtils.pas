unit SwmmJsonUtils;

{
  SwmmJsonUtils.pas
  -----------------
  Shared JSON helpers and element-type lookup functions used by all Agent
  command units.

  No dependencies on SWMM globals — safe to use from any unit.
}

interface

function JsonStr(const S: string): string;
function OkResult(const DataJson: string): string;
function ErrResult(const Msg: string): string;
function NodeTypeCode(const S: string): Integer;
function LinkTypeCode(const S: string): Integer;

implementation

uses
  System.SysUtils,
  Uglobals,
  Uproject;

// ---------------------------------------------------------------------------
// JSON string escaping
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

// ---------------------------------------------------------------------------
// Response envelope helpers
// ---------------------------------------------------------------------------

function OkResult(const DataJson: string): string;
begin
  Result := '{"ok":true,"data":' + DataJson + '}';
end;

function ErrResult(const Msg: string): string;
begin
  Result := '{"ok":false,"error":' + JsonStr(Msg) + '}';
end;

// ---------------------------------------------------------------------------
// Element type lookup
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

initialization

finalization

end.
