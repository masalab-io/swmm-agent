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
        // 1. Explicit env var takes priority
        string? pluginRoot = Environment.GetEnvironmentVariable("CLAUDE_PLUGIN_ROOT");
        if (!string.IsNullOrEmpty(pluginRoot))
        {
            string candidate = Path.Combine(pluginRoot, "dist", "Epaswmm5.exe");
            if (File.Exists(candidate)) return candidate;
        }

        // 2. Fallback: look for ../dist/Epaswmm5.exe relative to swmm_cli.exe
        //    swmm_cli lives in plugin/bin/, Epaswmm5.exe lives in plugin/dist/
        string selfDir = AppContext.BaseDirectory;
        string relative = Path.Combine(selfDir, "..", "dist", "Epaswmm5.exe");
        string full = Path.GetFullPath(relative);
        if (File.Exists(full)) return full;

        throw new FileNotFoundException(
            "Epaswmm5.exe not found. Set CLAUDE_PLUGIN_ROOT to the plugin root directory, " +
            "or ensure Epaswmm5.exe exists at dist/ alongside the swmm_cli binary.");
    }
}
