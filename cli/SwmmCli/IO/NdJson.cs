namespace SwmmCli.IO;

/// <summary>
/// NDJSON write helpers for the pipeline output format.
/// Phase 1: stubs only — full implementation in Phase 3.
/// </summary>
static class NdJson
{
    /// <summary>Emit a session line: {"kind":"session","pid":N}</summary>
    public static void WriteSession(int pid) =>
        Console.WriteLine($"{{\"kind\":\"session\",\"pid\":{pid}}}");

    /// <summary>Emit a slim element ref: {"kind":"swmm_element","id":"...","type":"..."}</summary>
    public static void WriteElement(string id, string type) =>
        Console.WriteLine($"{{\"kind\":\"swmm_element\",\"id\":{System.Text.Json.JsonSerializer.Serialize(id)},\"type\":{System.Text.Json.JsonSerializer.Serialize(type)}}}");

    /// <summary>Emit a full element JSON line as-is.</summary>
    public static void WriteElementFull(string json) =>
        Console.WriteLine(json);

    /// <summary>Emit a status line: {"kind":"status","success":true/false,"count":N}</summary>
    public static void WriteStatus(bool success, int count) =>
        Console.WriteLine($"{{\"kind\":\"status\",\"success\":{(success ? "true" : "false")},\"count\":{count}}}");
}
