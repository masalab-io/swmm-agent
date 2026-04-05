unit SwmmAgentConfig;

{
  SwmmAgentConfig.pas
  -------------------
  Centralised configuration for the SWMM Agent.

  Change UI_FLASH_DELAY_MS here to adjust how long any agent-opened window
  stays visible before being automatically closed.  All three command units
  (SwmmElementCommands, SwmmSimulateCommands, SwmmResultsCommands) read this
  single constant, so one edit updates every command.
}

interface

const
  { Milliseconds that an agent-opened window stays visible before closing. }
  UI_FLASH_DELAY_MS = 1000;

implementation

end.
