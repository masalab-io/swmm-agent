using System.CommandLine;
using System.Diagnostics;
using System.Text.Json;

namespace SwmmCli.Commands;

static class ProcessLaunchCommand
{
    public static Command Build()
    {
        var pathOption = new Option<string>("--path", "Full path to Epaswmm5.exe") { IsRequired = true };
        var cmd = new Command("launch", "Launch Epaswmm5 and return its PID");
        cmd.AddOption(pathOption);
        cmd.SetHandler((string path) =>
        {
            try
            {
                var p = Process.Start(new ProcessStartInfo(path) { UseShellExecute = true })
                    ?? throw new InvalidOperationException("Process.Start returned null");
                System.Threading.Thread.Sleep(500);
                Console.WriteLine(JsonSerializer.Serialize(new { ok = true, pid = p.Id }));
                Environment.Exit(0);
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pathOption);
        return cmd;
    }
}
