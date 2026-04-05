namespace SwmmCli.IO;

/// <summary>
/// Detects the current output/input mode for NDJSON pipeline support.
/// Used in Phase 3 to switch between pipe, full, and terminal output formats.
/// </summary>
static class OutputMode
{
    /// <summary>True when stdout is redirected (piped to another process).</summary>
    public static bool IsPipeMode => Console.IsOutputRedirected;

    /// <summary>True when the --full flag is set (injected by Program.cs at startup).</summary>
    public static bool ForceFullOutput { get; set; }

    /// <summary>True when stdin is redirected (piped from another process).</summary>
    public static bool HasPipedInput => Console.IsInputRedirected;
}
