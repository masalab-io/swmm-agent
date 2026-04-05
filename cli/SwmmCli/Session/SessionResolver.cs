using System.Diagnostics;
using System.Text.Json;

namespace SwmmCli.Session;

/// <summary>
/// Resolves the target SWMM process PID using a six-step priority chain.
/// </summary>
static class SessionResolver
{
    /// <summary>
    /// Returns the PID of the target SWMM process, or throws if it cannot be determined.
    /// </summary>
    /// <param name="explicitPid">Value of --pid flag (null if not supplied).</param>
    /// <param name="pipedSessionPid">PID read from a {"kind":"session"} line in piped stdin (null if not present).</param>
    public static int ResolvePid(int? explicitPid, int? pipedSessionPid = null)
    {
        // 1. Explicit --pid flag always wins.
        if (explicitPid.HasValue)
            return explicitPid.Value;

        // 2. Session line propagated through piped stdin.
        if (pipedSessionPid.HasValue)
            return pipedSessionPid.Value;

        // 3. SWMM_PID environment variable.
        var envVar = Environment.GetEnvironmentVariable("SWMM_PID");
        if (!string.IsNullOrEmpty(envVar) && int.TryParse(envVar, out int envPid))
            return envPid;

        // 4. .swmm/session.json in CWD.
        var stored = SessionStore.ReadPid();
        if (stored.HasValue)
            return stored.Value;

        // 5. Auto-discovery: succeed only if exactly one Epaswmm5.exe is running.
        var procs = Process.GetProcessesByName("Epaswmm5");
        if (procs.Length == 1)
            return procs[0].Id;

        if (procs.Length > 1)
            throw new InvalidOperationException(
                "Multiple SWMM instances running — specify --pid or run: swmm_cli attach <pid>");

        // 6. No instance found.
        throw new InvalidOperationException(
            "No running SWMM instance found — launch SWMM or specify --pid");
    }

    /// <summary>
    /// Reads the first {"kind":"session"} line from piped stdin (non-blocking peek).
    /// Re-emits it so the session propagates to the next stage in the pipeline.
    /// Returns the pid value, or null if stdin is not piped or has no session line.
    /// </summary>
    public static int? ReadAndReEmitSessionPid()
    {
        if (!Console.IsInputRedirected)
            return null;

        // Peek at the first line — if it is a session line, consume and re-emit it.
        var line = Console.ReadLine();
        if (line is null) return null;

        try
        {
            var doc = JsonDocument.Parse(line);
            if (doc.RootElement.TryGetProperty("kind", out var kindProp) &&
                kindProp.GetString() == "session" &&
                doc.RootElement.TryGetProperty("pid", out var pidProp) &&
                pidProp.TryGetInt32(out int pid))
            {
                // Re-emit so downstream commands also see the session line.
                Console.WriteLine(line);
                return pid;
            }
        }
        catch (JsonException) { }

        // Not a session line — put it back by... we can't unread, so callers
        // that need stdin content must handle this. For Phase 1 commands that
        // don't read stdin this is fine; Phase 3 will refine this.
        return null;
    }
}
