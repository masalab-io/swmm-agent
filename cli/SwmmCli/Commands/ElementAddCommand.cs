using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ElementAddCommand
{
    public static Command Build()
    {
        var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
        var typeOption = new Option<string>("--type", "Element type (junction, outfall, divider, storage)") { IsRequired = true };
        var idOption   = new Option<string>("--id",   "New element ID") { IsRequired = true };
        var xOption    = new Option<double>("--x",    "X coordinate (default 0)");
        var yOption    = new Option<double>("--y",    "Y coordinate (default 0)");

        var cmd = new Command("add", "Add a new node element to the model");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.AddOption(idOption);
        cmd.AddOption(xOption);
        cmd.AddOption(yOption);
        cmd.SetHandler(async (int? pid, string type, string id, double x, double y) =>
        {
            try
            {
                int resolvedPid = SessionResolver.ResolvePid(pid);
                var req = JsonSerializer.Serialize(new { cmd = "element.add", type, id, x, y });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption, idOption, xOption, yOption);
        return cmd;
    }
}
