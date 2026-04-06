using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ResultsGetCommand
{
    public static Command Build()
    {
        var pidOption      = new Option<int?>("--pid",      "PID of the target Epaswmm5 process");
        var typeOption     = new Option<string>("--type",   "Element type (node, link, subcatchment)") { IsRequired = true };
        var idOption       = new Option<string>("--id",     "Element ID") { IsRequired = true };
        var variableOption = new Option<string>("--variable", "Variable name (e.g. depth, flow, runoff)") { IsRequired = true };

        var cmd = new Command("get", "Get a time-series for one element/variable after a simulation run");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.AddOption(idOption);
        cmd.AddOption(variableOption);
        cmd.SetHandler(async (int? pid, string type, string id, string variable) =>
        {
            try
            {
                int? pipedPid = SessionResolver.ReadAndReEmitSessionPid();
                int resolvedPid = SessionResolver.ResolvePid(pid, pipedPid);
                var req = JsonSerializer.Serialize(new { cmd = "results.get", type, id, variable });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption, idOption, variableOption);
        return cmd;
    }
}
