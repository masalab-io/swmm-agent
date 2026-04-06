using System.CommandLine;
using System.CommandLine.Builder;
using System.CommandLine.Parsing;
using System.Diagnostics;
using System.Text.Json;
using SwmmCli.Commands;
using SwmmCli.IO;
using SwmmCli.Session;

// ---------------------------------------------------------------------------
// Root command — session emitter
//   swmm_cli --pid 1234      → emits {"kind":"session","pid":1234}
//   swmm_cli --auto          → auto-discovers single SWMM instance, emits session line
// ---------------------------------------------------------------------------

var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
var autoOption = new Option<bool>("--auto", "Auto-discover the single running SWMM instance");

var rootCommand = new RootCommand("SWMM Agent CLI — connects AI agents to the SWMM named pipe server");
rootCommand.AddOption(pidOption);
rootCommand.AddOption(autoOption);

rootCommand.SetHandler((int? pid, bool auto) =>
{
    if (pid.HasValue || auto)
    {
        try
        {
            int resolvedPid = SessionResolver.ResolvePid(auto ? null : pid);
            NdJson.WriteSession(resolvedPid);
        }
        catch (Exception ex)
        {
            Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
            Environment.Exit(1);
        }
    }
    // No options: fall through to show help (System.CommandLine default behaviour).
}, pidOption, autoOption);

// ---------------------------------------------------------------------------
// process
// ---------------------------------------------------------------------------

var processCommand = new Command("process", "Commands for discovering SWMM processes");
processCommand.AddCommand(ProcessListCommand.Build());
processCommand.AddCommand(ProcessLaunchCommand.Build());
rootCommand.AddCommand(processCommand);

// ---------------------------------------------------------------------------
// attach
// ---------------------------------------------------------------------------

rootCommand.AddCommand(AttachCommand.Build());

// ---------------------------------------------------------------------------
// element
// ---------------------------------------------------------------------------

var elementCommand = new Command("element", "Commands for reading and writing SWMM model elements");
elementCommand.AddCommand(ElementGetCommand.Build());
elementCommand.AddCommand(ElementSetCommand.Build());
elementCommand.AddCommand(ElementListCommand.Build());
elementCommand.AddCommand(ElementAddCommand.Build());
elementCommand.AddCommand(ElementFilterCommand.Build());
rootCommand.AddCommand(elementCommand);

// ---------------------------------------------------------------------------
// simulate
// ---------------------------------------------------------------------------

var simulateCommand = new Command("simulate", "Commands for running and monitoring SWMM simulations");
simulateCommand.AddCommand(SimulateRunCommand.Build());
simulateCommand.AddCommand(SimulateStatusCommand.Build());
rootCommand.AddCommand(simulateCommand);

// ---------------------------------------------------------------------------
// results
// ---------------------------------------------------------------------------

var resultsCommand = new Command("results", "Commands for reading simulation results");
resultsCommand.AddCommand(ResultsGetCommand.Build());
resultsCommand.AddCommand(ResultsSummaryCommand.Build());
rootCommand.AddCommand(resultsCommand);

// ---------------------------------------------------------------------------
// file
// ---------------------------------------------------------------------------

var fileCommand = new Command("file", "Commands for inspecting the open SWMM project file");
fileCommand.AddCommand(FileInfoCommand.Build());
fileCommand.AddCommand(FileOpenCommand.Build());
rootCommand.AddCommand(fileCommand);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

// Middleware: when root --pid is supplied alongside a subcommand, propagate
// it via SWMM_PID so SessionResolver picks it up at priority step 3.
// This makes `swmm_cli --pid 1234 file info` behave as expected.
return await new CommandLineBuilder(rootCommand)
    .UseDefaults()
    .AddMiddleware(async (context, next) =>
    {
        var rootPid = context.ParseResult.GetValueForOption(pidOption);
        if (rootPid.HasValue && context.ParseResult.CommandResult.Command != rootCommand)
            Environment.SetEnvironmentVariable("SWMM_PID", rootPid.Value.ToString());
        await next(context);
    })
    .Build()
    .InvokeAsync(args);
