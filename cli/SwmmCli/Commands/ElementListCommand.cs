using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ElementListCommand
{
    public static Command Build()
    {
        var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
        var typeOption = new Option<string>("--type", "Element type (e.g. junction, conduit)") { IsRequired = true };

        var cmd = new Command("list", "List all elements of a given type");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.SetHandler(async (int? pid, string type) =>
        {
            try
            {
                int? pipedPid = SessionResolver.ReadAndReEmitSessionPid();
                int resolvedPid = SessionResolver.ResolvePid(pid, pipedPid);
                var req = JsonSerializer.Serialize(new { cmd = "element.list", type });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption);
        return cmd;
    }
}
