unit SwmmAgentAPI;

{
  SwmmAgentAPI.pas
  ----------------
  Dispatcher: routes incoming JSON commands to the appropriate handler unit.

  Public entry point:
    function HandleCommand(const Request: string): string;

  This unit runs on the VCL main thread (called via TThread.Synchronize),
  so no additional locking is required when accessing SWMM globals.

  Handler units:
    SwmmElementCommands   — element.get, set, list, add
    SwmmSimulateCommands  — simulate.run, status
    SwmmFileCommands      — file.open, info
}

interface

function HandleCommand(const Request: string): string;

implementation

uses
  System.SysUtils,
  System.JSON,
  SwmmJsonUtils,
  SwmmElementCommands,
  SwmmSimulateCommands,
  SwmmFileCommands,
  SwmmResultsCommands;

function HandleCommand(const Request: string): string;
var
  Root:   TJSONValue;
  Cmd:    TJSONObject;
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
      else if CmdStr = 'results.get' then
        Result := HandleResultsGet(Cmd)
      else if CmdStr = 'results.summary' then
        Result := HandleResultsSummary(Cmd)
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
