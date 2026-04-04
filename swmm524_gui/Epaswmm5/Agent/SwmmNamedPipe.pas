unit SwmmNamedPipe;

{
  SwmmNamedPipe.pas
  -----------------
  Background thread that listens on a Windows named pipe and dispatches
  JSON commands to SwmmAgentAPI.HandleCommand.

  Pipe name: \\.\pipe\swmm_agent_<PID>   (one server instance per process)

  The thread loops continuously:
    CreateNamedPipeA → ConnectNamedPipe → ServeClient → DisconnectNamedPipe → repeat

  All SWMM data access is marshalled to the VCL main thread via
  TThread.Synchronize, so SwmmAgentAPI requires no additional locking.
}

interface

uses
  System.Classes,
  Winapi.Windows,
  System.SysUtils,
  SwmmAgentAPI;

type
  TSwmmPipeThread = class(TThread)
  private
    FPipeName: string;
    FRequest:  string;
    FResponse: string;

    procedure ExecuteCommand;
    procedure ServeClient(hPipe: THandle);
  protected
    procedure Execute; override;
  public
    constructor Create(const APipeName: string);
  end;

procedure StartPipeServer;

implementation

const
  READ_BUFFER_SIZE = 65536;

var
  GPipeThread: TSwmmPipeThread = nil;

// ---------------------------------------------------------------------------
// TSwmmPipeThread
// ---------------------------------------------------------------------------

constructor TSwmmPipeThread.Create(const APipeName: string);
begin
  inherited Create(True {CreateSuspended});
  FPipeName      := APipeName;
  FreeOnTerminate := False;
end;

procedure TSwmmPipeThread.ExecuteCommand;
begin
  // Runs on the VCL main thread via Synchronize.
  FResponse := HandleCommand(FRequest);
end;

procedure TSwmmPipeThread.ServeClient(hPipe: THandle);
var
  Buffer:    array[0..READ_BUFFER_SIZE - 1] of AnsiChar;
  BytesRead: DWORD;
  RawIn:     AnsiString;
  Response:  AnsiString;
  Written:   DWORD;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);

  // Read the incoming request (one newline-terminated JSON line).
  if not ReadFile(hPipe, Buffer, READ_BUFFER_SIZE - 1, BytesRead, nil) then
    Exit;

  if BytesRead = 0 then
    Exit;

  // Convert to a Delphi string, stripping trailing CR/LF.
  SetString(RawIn, PAnsiChar(@Buffer[0]), BytesRead);
  RawIn := AnsiString(Trim(string(RawIn)));

  FRequest := string(RawIn);

  // Dispatch to the API on the main thread.
  Synchronize(ExecuteCommand);

  // Write the response back, appending a newline.
  Response := AnsiString(FResponse) + #10;
  WriteFile(hPipe, Response[1], Length(Response), Written, nil);
  // Block until the client has read the data before DisconnectNamedPipe is
  // called.  Without this, DisconnectNamedPipe discards the unread buffer and
  // fast commands (element.get, file.info, etc.) return blank to the client.
  FlushFileBuffers(hPipe);
end;

procedure TSwmmPipeThread.Execute;
var
  hPipe: THandle;
  SecurityAttr: TSecurityAttributes;
begin
  // Default security attributes (inheritable, default descriptor).
  FillChar(SecurityAttr, SizeOf(SecurityAttr), 0);
  SecurityAttr.nLength        := SizeOf(SecurityAttr);
  SecurityAttr.bInheritHandle := False;

  while not Terminated do
  begin
    hPipe := CreateNamedPipeA(
      PAnsiChar(AnsiString(FPipeName)),
      PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_WAIT,
      PIPE_UNLIMITED_INSTANCES,
      READ_BUFFER_SIZE,
      READ_BUFFER_SIZE,
      0,               // default timeout (50 ms)
      @SecurityAttr
    );

    if hPipe = INVALID_HANDLE_VALUE then
    begin
      // Back off briefly before retrying so we do not spin-lock on error.
      Sleep(500);
      Continue;
    end;

    try
      // Block until a client connects (or the thread is terminated).
      if ConnectNamedPipe(hPipe, nil) or
         (GetLastError = ERROR_PIPE_CONNECTED) then
      begin
        if not Terminated then
          ServeClient(hPipe);
      end;
    finally
      DisconnectNamedPipe(hPipe);
      CloseHandle(hPipe);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// StartPipeServer
// ---------------------------------------------------------------------------

procedure StartPipeServer;
var
  PipeName: string;
begin
  if Assigned(GPipeThread) then
    Exit;

  PipeName := Format('\\.\pipe\swmm_agent_%d', [GetCurrentProcessId]);

  GPipeThread := TSwmmPipeThread.Create(PipeName);
  GPipeThread.Start;
end;

// ---------------------------------------------------------------------------
// Unit lifecycle
// ---------------------------------------------------------------------------

initialization
  StartPipeServer;

finalization
  if Assigned(GPipeThread) then
  begin
    GPipeThread.Terminate;
    // Wake the thread if it is blocked inside ConnectNamedPipe by opening a
    // transient client connection to the pipe.  We ignore errors here because
    // the pipe may not exist yet if the thread never successfully created it.
    CloseHandle(
      CreateFileA(
        PAnsiChar(AnsiString(Format('\\.\pipe\swmm_agent_%d', [GetCurrentProcessId]))),
        GENERIC_READ or GENERIC_WRITE,
        0,
        nil,
        OPEN_EXISTING,
        0,
        0
      )
    );
    GPipeThread.WaitFor;
    FreeAndNil(GPipeThread);
  end;

end.
