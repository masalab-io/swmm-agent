using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ResultsSummaryCommand
{
    public static Command Build()
    {
        var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
        var typeOption = new Option<string>("--type", "Element type (node, link, subcatchment)") { IsRequired = true };
        var idOption   = new Option<string>("--id",   "Element ID") { IsRequired = true };

        var cmd = new Command("summary", "Get max/min for all variables of one element after a simulation run");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.AddOption(idOption);
        cmd.SetHandler(async (int? pid, string type, string id) =>
        {
            try
            {
                int? pipedPid = SessionResolver.ReadAndReEmitSessionPid();
                int resolvedPid = SessionResolver.ResolvePid(pid, pipedPid);
                var req = JsonSerializer.Serialize(new { cmd = "results.summary", type, id });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption, idOption);
        return cmd;
    }
}
