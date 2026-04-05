using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ElementSetCommand
{
    public static Command Build()
    {
        var pidOption   = new Option<int?>("--pid",   "PID of the target Epaswmm5 process");
        var typeOption  = new Option<string>("--type",  "Element type (e.g. junction, conduit)") { IsRequired = true };
        var idOption    = new Option<string>("--id",    "Element ID") { IsRequired = true };
        var propOption  = new Option<string>("--prop",  "Property name") { IsRequired = true };
        var valueOption = new Option<string>("--value", "Property value") { IsRequired = true };

        var cmd = new Command("set", "Set a property on a node/link element");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.AddOption(idOption);
        cmd.AddOption(propOption);
        cmd.AddOption(valueOption);
        cmd.SetHandler(async (int? pid, string type, string id, string prop, string value) =>
        {
            try
            {
                int resolvedPid = SessionResolver.ResolvePid(pid);
                var req = JsonSerializer.Serialize(new { cmd = "element.set", type, id, prop, value });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption, idOption, propOption, valueOption);
        return cmd;
    }
}
