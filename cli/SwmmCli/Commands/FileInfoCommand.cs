using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class FileInfoCommand
{
    public static Command Build()
    {
        var pidOption = new Option<int?>("--pid", "PID of the target Epaswmm5 process");

        var cmd = new Command("info", "Get information about the currently open project file");
        cmd.AddOption(pidOption);
        cmd.SetHandler(async (int? pid) =>
        {
            try
            {
                int resolvedPid = SessionResolver.ResolvePid(pid);
                var req = JsonSerializer.Serialize(new { cmd = "file.info" });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption);
        return cmd;
    }
}
