using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class FileOpenCommand
{
    public static Command Build()
    {
        var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
        var pathOption = new Option<string>("--path", "Full path to the .inp model file") { IsRequired = true };

        var cmd = new Command("open", "Open a model file in the target SWMM process");
        cmd.AddOption(pidOption);
        cmd.AddOption(pathOption);
        cmd.SetHandler(async (int? pid, string path) =>
        {
            try
            {
                int resolvedPid = SessionResolver.ResolvePid(pid);
                string fullPath = Path.GetFullPath(path);
                var req = JsonSerializer.Serialize(new { cmd = "file.open", path = fullPath });
                Environment.Exit(await PipeClient.SendAsync(resolvedPid, req));
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, pathOption);
        return cmd;
    }
}
