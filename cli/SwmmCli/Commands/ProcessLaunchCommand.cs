using System.CommandLine;
using System.Diagnostics;
using System.Text.Json;

namespace SwmmCli.Commands;

static class ProcessLaunchCommand
{
    public static Command Build()
    {
        var cmd = new Command("launch", "Launch the bundled Epaswmm5.exe and return its PID");
        cmd.SetHandler(() =>
        {
            try
            {
                string exePath = ResolveBundledExe();
                var p = Process.Start(new ProcessStartInfo(exePath) { UseShellExecute = true })
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
        });
        return cmd;
    }

    private static string ResolveBundledExe()
    {
        string? pluginRoot = Environment.GetEnvironmentVariable("CLAUDE_PLUGIN_ROOT");
        if (!string.IsNullOrEmpty(pluginRoot))
        {
            string candidate = Path.Combine(pluginRoot, "dist", "Epaswmm5.exe");
            if (File.Exists(candidate)) return candidate;
        }
        throw new FileNotFoundException(
            "Epaswmm5.exe not found. CLAUDE_PLUGIN_ROOT is not set or dist/Epaswmm5.exe is missing.");
    }
}
