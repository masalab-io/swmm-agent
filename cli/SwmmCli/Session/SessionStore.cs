using System.Text.Json;

namespace SwmmCli.Session;

/// <summary>
/// Persists the active SWMM PID to/from .swmm/session.json in the working directory.
/// Written by "swmm_cli attach &lt;pid&gt;"; read by SessionResolver as fallback step 4.
/// </summary>
static class SessionStore
{
    private static string SessionFile =>
        Path.Combine(Directory.GetCurrentDirectory(), ".swmm", "session.json");

    public static int? ReadPid()
    {
        try
        {
            if (!File.Exists(SessionFile)) return null;
            var json = File.ReadAllText(SessionFile);
            var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("pid", out var pidProp) &&
                pidProp.TryGetInt32(out int pid))
                return pid;
            return null;
        }
        catch
        {
            return null;
        }
    }

    public static void WritePid(int pid)
    {
        var dir = Path.GetDirectoryName(SessionFile)!;
        Directory.CreateDirectory(dir);
        File.WriteAllText(SessionFile, JsonSerializer.Serialize(new { pid }));
    }
}
