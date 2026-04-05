unit SwmmFileCommands;

{
  SwmmFileCommands.pas
  --------------------
  Handlers for file.* named-pipe commands.

  Called from SwmmAgentAPI.HandleCommand on the VCL main thread.
}

interface

uses
  System.JSON;

function HandleFileOpen(Cmd: TJSONObject): string;
function HandleFileInfo: string;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  Uglobals,
  Fmain,
  Dwelcome,
  SwmmJsonUtils;

function HandleFileOpen(Cmd: TJSONObject): string;
var
  PathStr: string;
  I: Integer;
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

initialization

finalization

end.
