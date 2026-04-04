using System.CommandLine;
using System.Diagnostics;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static string ErrorJson(string message) =>
    JsonSerializer.Serialize(new { ok = false, error = message });

static async Task<int> SendPipeCommand(int pid, string requestJson)
{
    string pipeName = $"swmm_agent_{pid}";
    try
    {
        using var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut,
            PipeOptions.Asynchronous);

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        try
        {
            await pipe.ConnectAsync(cts.Token);
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine(ErrorJson("Pipe connect timeout — is SWMM running with the agent?"));
            return 1;
        }

        // Send request terminated with newline
        byte[] payload = Encoding.UTF8.GetBytes(requestJson + "\n");
        await pipe.WriteAsync(payload);
        await pipe.FlushAsync();

        // Read response until newline
        var sb = new StringBuilder();
        byte[] buf = new byte[4096];
        while (true)
        {
            int bytesRead = await pipe.ReadAsync(buf);
            if (bytesRead == 0) break;
            string chunk = Encoding.UTF8.GetString(buf, 0, bytesRead);
            sb.Append(chunk);
            if (chunk.Contains('\n')) break;
        }

        Console.WriteLine(sb.ToString().TrimEnd('\n', '\r'));
        return 0;
    }
    catch (Exception ex)
    {
        Console.WriteLine(ErrorJson(ex.Message));
        return 1;
    }
}

static int ProcessList()
{
    try
    {
        var procs = Process.GetProcessesByName("Epaswmm5");
        var entries = procs.Select(p =>
        {
            string pipePath = $@"\\.\pipe\swmm_agent_{p.Id}";
            bool available = File.Exists(pipePath);
            return new
            {
                pid = p.Id,
                pipe = pipePath,
                available
            };
        }).ToArray();

        string json = JsonSerializer.Serialize(new { ok = true, processes = entries });
        Console.WriteLine(json);
        return 0;
    }
    catch (Exception ex)
    {
        Console.WriteLine(ErrorJson(ex.Message));
        return 1;
    }
}

// ---------------------------------------------------------------------------
// Root command
// ---------------------------------------------------------------------------

var rootCommand = new RootCommand("SWMM Agent CLI — connects AI agents to the SWMM named pipe server");

// ---------------------------------------------------------------------------
// process list
// ---------------------------------------------------------------------------

var processCommand = new Command("process", "Commands for discovering SWMM processes");
var processListCommand = new Command("list", "List running Epaswmm5 processes and pipe availability");
processListCommand.SetHandler(() => Environment.Exit(ProcessList()));
processCommand.AddCommand(processListCommand);

// process launch
var processLaunchPathOption = new Option<string>("--path", "Full path to Epaswmm5.exe") { IsRequired = true };
var processLaunchCommand = new Command("launch", "Launch Epaswmm5 and return its PID");
processLaunchCommand.AddOption(processLaunchPathOption);
processLaunchCommand.SetHandler((string path) =>
{
    try
    {
        var p = Process.Start(new ProcessStartInfo(path) { UseShellExecute = true })
            ?? throw new InvalidOperationException("Process.Start returned null");
        System.Threading.Thread.Sleep(500); // let the process initialise
        Console.WriteLine(JsonSerializer.Serialize(new { ok = true, pid = p.Id }));
        Environment.Exit(0);
    }
    catch (Exception ex)
    {
        Console.WriteLine(ErrorJson(ex.Message));
        Environment.Exit(1);
    }
}, processLaunchPathOption);
processCommand.AddCommand(processLaunchCommand);

rootCommand.AddCommand(processCommand);

// ---------------------------------------------------------------------------
// Shared options
// ---------------------------------------------------------------------------

var pidOption = new Option<int>("--pid", "PID of the target Epaswmm5 process") { IsRequired = true };
var typeOption = new Option<string>("--type", "Element type (e.g. junction, conduit)") { IsRequired = true };
var idOption = new Option<string>("--id", "Element ID") { IsRequired = true };
var propOption = new Option<string>("--prop", "Property name") { IsRequired = true };
var valueOption = new Option<string>("--value", "Property value") { IsRequired = true };

// ---------------------------------------------------------------------------
// element get / set / list
// ---------------------------------------------------------------------------

var elementCommand = new Command("element", "Commands for reading and writing SWMM model elements");

// element get
var elementGetCommand = new Command("get", "Get a node/link element's properties");
elementGetCommand.AddOption(pidOption);
elementGetCommand.AddOption(typeOption);
elementGetCommand.AddOption(idOption);
elementGetCommand.SetHandler(async (int pid, string type, string id) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "element.get", type, id });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption, typeOption, idOption);

// element set
var elementSetCommand = new Command("set", "Set a property on a node/link element");
elementSetCommand.AddOption(pidOption);
elementSetCommand.AddOption(typeOption);
elementSetCommand.AddOption(idOption);
elementSetCommand.AddOption(propOption);
elementSetCommand.AddOption(valueOption);
elementSetCommand.SetHandler(async (int pid, string type, string id, string prop, string value) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "element.set", type, id, prop, value });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption, typeOption, idOption, propOption, valueOption);

// element list
var elementListCommand = new Command("list", "List all elements of a given type");
elementListCommand.AddOption(pidOption);
elementListCommand.AddOption(typeOption);
elementListCommand.SetHandler(async (int pid, string type) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "element.list", type });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption, typeOption);

// element add
var elementAddTypeOption = new Option<string>("--type", "Element type (junction, outfall, divider, storage)") { IsRequired = true };
var elementAddIdOption   = new Option<string>("--id",   "New element ID") { IsRequired = true };
var elementAddXOption    = new Option<double>("--x",    "X coordinate (default 0)");
var elementAddYOption    = new Option<double>("--y",    "Y coordinate (default 0)");
var elementAddCommand = new Command("add", "Add a new node element to the model");
elementAddCommand.AddOption(pidOption);
elementAddCommand.AddOption(elementAddTypeOption);
elementAddCommand.AddOption(elementAddIdOption);
elementAddCommand.AddOption(elementAddXOption);
elementAddCommand.AddOption(elementAddYOption);
elementAddCommand.SetHandler(async (int pid, string type, string id, double x, double y) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "element.add", type, id, x, y });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption, elementAddTypeOption, elementAddIdOption, elementAddXOption, elementAddYOption);

elementCommand.AddCommand(elementGetCommand);
elementCommand.AddCommand(elementSetCommand);
elementCommand.AddCommand(elementListCommand);
elementCommand.AddCommand(elementAddCommand);
rootCommand.AddCommand(elementCommand);

// ---------------------------------------------------------------------------
// simulate run / status
// ---------------------------------------------------------------------------

var simulateCommand = new Command("simulate", "Commands for running and monitoring SWMM simulations");

// simulate run
var simulateRunCommand = new Command("run", "Trigger a simulation run");
simulateRunCommand.AddOption(pidOption);
simulateRunCommand.SetHandler(async (int pid) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "simulate.run" });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption);

// simulate status
var simulateStatusCommand = new Command("status", "Get the current simulation status");
simulateStatusCommand.AddOption(pidOption);
simulateStatusCommand.SetHandler(async (int pid) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "simulate.status" });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption);

simulateCommand.AddCommand(simulateRunCommand);
simulateCommand.AddCommand(simulateStatusCommand);
rootCommand.AddCommand(simulateCommand);

// ---------------------------------------------------------------------------
// file info
// ---------------------------------------------------------------------------

var fileCommand = new Command("file", "Commands for inspecting the open SWMM project file");

var fileInfoCommand = new Command("info", "Get information about the currently open project file");
fileInfoCommand.AddOption(pidOption);
fileInfoCommand.SetHandler(async (int pid) =>
{
    var req = JsonSerializer.Serialize(new { cmd = "file.info" });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption);

// file open
var fileOpenPathOption = new Option<string>("--path", "Full path to the .inp model file") { IsRequired = true };
var fileOpenCommand = new Command("open", "Open a model file in the target SWMM process");
fileOpenCommand.AddOption(pidOption);
fileOpenCommand.AddOption(fileOpenPathOption);
fileOpenCommand.SetHandler(async (int pid, string path) =>
{
    string fullPath = Path.GetFullPath(path); // resolve relative paths before sending
    var req = JsonSerializer.Serialize(new { cmd = "file.open", path = fullPath });
    Environment.Exit(await SendPipeCommand(pid, req));
}, pidOption, fileOpenPathOption);

fileCommand.AddCommand(fileInfoCommand);
fileCommand.AddCommand(fileOpenCommand);
rootCommand.AddCommand(fileCommand);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

return await rootCommand.InvokeAsync(args);
