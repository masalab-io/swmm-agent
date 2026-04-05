unit SwmmSimulateCommands;

{
  SwmmSimulateCommands.pas
  ------------------------
  Handlers for simulate.* named-pipe commands.

  Called from SwmmAgentAPI.HandleCommand on the VCL main thread.

  simulate.run bypasses TSimulationForm entirely: it calls the SWMM DLL
  directly so no GUI dialog is shown and the pipe returns as soon as the
  simulation finishes.  All scenarios (input errors, init errors, engine
  errors, success, warning) are handled and surfaced in the JSON response.
}

interface

function HandleSimulateRun: string;
function HandleSimulateStatus: string;

implementation

uses
  SysUtils,
  Classes,
  Winapi.Windows,
  Vcl.Forms,
  Uglobals,
  Uproject,
  Uutils,
  Uoutput,
  Uexport,
  Swmm5,
  Fmain,
  Fstatus,
  SwmmJsonUtils,
  SwmmAgentConfig;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// Replicate Fmain.TMainForm.CreateTempFiles (private method - reproduced here).
procedure AgentCreateTempFiles;
begin
  Uglobals.TempInputFile  := Uutils.GetTempFile(Uglobals.TempDir, 'swmm');
  Uglobals.TempReportFile := Uutils.GetTempFile(Uglobals.TempDir, 'swmm');
  Uglobals.TempOutputFile := Uutils.GetTempFile(Uglobals.TempDir, 'swmm');
end;

// Replicate Fmain.TMainForm.DeleteTempFiles (private method - reproduced here).
procedure AgentDeleteTempFiles;
begin
  SysUtils.DeleteFile(Uglobals.TempInputFile);
  if not Uglobals.ResultsSaved then
  begin
    SysUtils.DeleteFile(Uglobals.TempReportFile);
    SysUtils.DeleteFile(Uglobals.TempOutputFile);
  end;
end;

function RunStatusString(S: TRunStatus): string;
begin
  case S of
    rsSuccess:      Result := 'success';
    rsWarning:      Result := 'warning';
    rsError:        Result := 'error';
    rsFailed:       Result := 'failed';
    rsStopped:      Result := 'stopped';
    rsShutdown:     Result := 'shutdown';
    rsWrongVersion: Result := 'wrong_version';
    rsImportError:  Result := 'import_error';
    rsNone:         Result := 'none';
  else
    Result := 'unknown';
  end;
end;

function RunStatusMessage(S: TRunStatus): string;
begin
  case S of
    rsSuccess:      Result := 'Run was successful.';
    rsWarning:      Result := 'Run was successful with warnings. See Status Report for details.';
    rsError:        Result := 'Run was unsuccessful. See Status Report for reasons.';
    rsFailed:       Result := 'Run was unsuccessful due to system error.';
    rsStopped:      Result := 'Run was stopped before completion.';
    rsShutdown:     Result := 'Simulator performed an illegal operation and was shut down.';
    rsWrongVersion: Result := 'Run was unsuccessful. Wrong version of simulator.';
    rsImportError:  Result := 'Run was unsuccessful due to an import error.';
    rsNone:         Result := 'Unable to run simulator. Check project data.';
  else
    Result := 'Unknown run status.';
  end;
end;

// ---------------------------------------------------------------------------
// simulate.run
//
// Runs the SWMM DLL directly - no TSimulationForm, no blocking dialogs.
//
// Response (success/warning):
//   {"ok":true,"status":"success","message":"...","continuity_errors":{...}}
//
// Response (failure):
//   {"ok":false,"status":"error","message":"..."}
// ---------------------------------------------------------------------------

function HandleSimulateRun: string;
var
  Err:          Integer;
  ElapsedTime:  Double;
  ErrRunoff,
  ErrFlow,
  ErrQual:      Single;
  Warnings:     Integer;
  S:            TStringList;
  InpFile,
  RptFile,
  OutFile:      AnsiString;
  OldDir:       string;
  StatusStr,
  MsgStr:       string;
  Succeeded:    Boolean;
  Sb:           TStringBuilder;
begin
  if not Assigned(Project) then
  begin
    Result := ErrResult('No project is currently open');
    Exit;
  end;

  // --- 1. Reset state -------------------------------------------------------
  Uoutput.ClearOutput;
  Uglobals.RunStatus  := rsNone;
  Uglobals.RunFlag    := False;
  Uglobals.UpdateFlag := False;

  // --- 2. Cycle temp files --------------------------------------------------
  Uglobals.ResultsSaved := False;
  AgentDeleteTempFiles;
  AgentCreateTempFiles;

  // --- 3. Export project data to the input temp file ------------------------
  GetDir(0, OldDir);
  ChDir(Uglobals.TempDir);
  S := TStringList.Create;
  try
    try
      Uexport.ExportProject(S, '');
      Uexport.ExportTempDir(S);
      S.SaveToFile(Uglobals.TempInputFile);
    except
      on E: Exception do
      begin
        ChDir(OldDir);
        Result := ErrResult('Failed to export project: ' + E.Message);
        Exit;
      end;
    end;
  finally
    S.Free;
  end;

  // --- 4. Run the SWMM engine via DLL ---------------------------------------
  ErrRunoff := 0;
  ErrFlow   := 0;
  ErrQual   := 0;
  Warnings  := 0;

  InpFile := AnsiString(Uglobals.TempInputFile);
  RptFile := AnsiString(Uglobals.TempReportFile);
  OutFile := AnsiString(Uglobals.TempOutputFile);

  Err := swmm_open(PAnsiChar(InpFile), PAnsiChar(RptFile), PAnsiChar(OutFile));
  if Err = 0 then
    Err := swmm_start(1);

  if Err = 0 then
  begin
    repeat
      Err := swmm_step(ElapsedTime);
    until (ElapsedTime = 0) or (Err > 0);

    swmm_end;
    swmm_getMassBalErr(ErrRunoff, ErrFlow, ErrQual);
    Warnings := swmm_getWarnings;
  end;

  swmm_close;
  ChDir(OldDir);

  // --- 5. Determine final RunStatus -----------------------------------------
  if Uutils.GetFileSize(Uglobals.TempReportFile) <= 0 then
    Uglobals.RunStatus := rsFailed
  else
    Uglobals.RunStatus := Uoutput.CheckRunStatus(Uglobals.TempOutputFile);

  if (Uglobals.RunStatus = rsSuccess) and (Warnings > 0) then
    Uglobals.RunStatus := rsWarning;

  // --- 6. Load output if run produced results --------------------------------
  Succeeded := Uglobals.RunStatus in [rsSuccess, rsWarning];
  Uglobals.RunFlag := Succeeded;
  if Succeeded then
    Uoutput.GetBasicOutput;

  // --- 6a. UI perception — briefly show the status report on success ---------
  if Succeeded then
  begin
    var TempStatus: TStatusForm;
    TempStatus := TStatusForm.Create(MainForm);
    TempStatus.Caption := 'Status Report';
    TempStatus.RefreshStatusReport;
    TempStatus.Show;
    TempStatus.BringToFront;
    Application.ProcessMessages;
    Sleep(UI_FLASH_DELAY_MS);
    TempStatus.Close;  // caFree handles cleanup
  end;

  // --- 7. Build JSON response ------------------------------------------------
  StatusStr := RunStatusString(Uglobals.RunStatus);
  MsgStr    := RunStatusMessage(Uglobals.RunStatus);

  Sb := TStringBuilder.Create;
  try
    Sb.Append('{');
    Sb.Append('"status":');    Sb.Append(JsonStr(StatusStr));
    Sb.Append(',"message":');  Sb.Append(JsonStr(MsgStr));

    if Succeeded then
    begin
      Sb.Append(',"continuity_errors":{');
      Sb.Append('"surface_runoff":');
      Sb.AppendFormat('%.4f', [ErrRunoff]);
      Sb.Append(',"flow_routing":');
      Sb.AppendFormat('%.4f', [ErrFlow]);
      Sb.Append(',"quality_routing":');
      Sb.AppendFormat('%.4f', [ErrQual]);
      Sb.Append('}');
    end;

    Sb.Append('}');

    if Succeeded then
      Result := OkResult(Sb.ToString)
    else
      Result := '{"ok":false,"data":' + Sb.ToString + '}';
  finally
    Sb.Free;
  end;
end;

// ---------------------------------------------------------------------------
// simulate.status
// ---------------------------------------------------------------------------

function HandleSimulateStatus: string;
var
  StatusStr: string;
begin
  StatusStr := RunStatusString(RunStatus);
  Result := '{"ok":true,"status":' + JsonStr(StatusStr) + '}';
end;

initialization

finalization

end.
