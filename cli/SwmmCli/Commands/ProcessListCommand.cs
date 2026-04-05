using System.CommandLine;
using System.Diagnostics;
using System.Text.Json;

namespace SwmmCli.Commands;

static class ProcessListCommand
{
    public static Command Build()
    {
        var cmd = new Command("list", "List running Epaswmm5 processes and pipe availability");
        cmd.SetHandler(() => Environment.Exit(Run()));
        return cmd;
    }

    private static int Run()
    {
        try
        {
            var procs = Process.GetProcessesByName("Epaswmm5");
            var entries = procs.Select(p =>
            {
                string pipePath = $@"\\.\pipe\swmm_agent_{p.Id}";
                bool available = File.Exists(pipePath);
                return new { pid = p.Id, pipe = pipePath, available };
            }).ToArray();

            Console.WriteLine(JsonSerializer.Serialize(new { ok = true, processes = entries }));
            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
            return 1;
        }
    }
}
