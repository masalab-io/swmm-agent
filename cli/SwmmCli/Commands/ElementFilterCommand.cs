using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ElementFilterCommand
{
    public static Command Build()
    {
        var pidOption   = new Option<int?>("--pid",   "PID of the target Epaswmm5 process");
        var propOption  = new Option<string>("--prop",  "Property name to filter on") { IsRequired = true };
        var opOption    = new Option<string>("--op",    "Operator: eq, ne, lt, le, gt, ge, contains, not-contains, starts-with, ends-with") { IsRequired = true };
        var valueOption = new Option<string>("--value", "Value to compare against") { IsRequired = true };

        var cmd = new Command("filter", "Filter a piped element list by a property condition");
        cmd.AddOption(pidOption);
        cmd.AddOption(propOption);
        cmd.AddOption(opOption);
        cmd.AddOption(valueOption);

        cmd.SetHandler(async (int? pid, string prop, string op, string value) =>
        {
            try
            {
                // Drain stdin: collect session line + prior output, extract pid and element list.
                int? pipedPid = null;
                string? elementType = null;
                List<string> elementIds = new();

                if (Console.IsInputRedirected)
                {
                    string? line;
                    while ((line = Console.ReadLine()) != null)
                    {
                        // Re-emit every upstream line.
                        Console.WriteLine(line);

                        // Extract session pid.
                        if (pipedPid == null)
                            pipedPid = TryParseSessionPid(line);

                        // Always update element list — last one wins so chained filters
                        // each operate on the previous filter's output, not the original full list.
                        TryParseElementList(line, out var parsedType, out var parsedIds);
                        if (parsedType != null)
                        {
                            elementType = parsedType;
                            elementIds  = parsedIds;
                        }
                    }
                }

                int resolvedPid = SessionResolver.ResolvePid(pid, pipedPid);

                if (elementType == null || elementIds.Count == 0)
                {
                    Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = "No element list found in piped input — pipe element list first" }));
                    Environment.Exit(1);
                    return;
                }

                op = op.ToLowerInvariant();

                // Fetch each element and apply the filter.
                var matchedIds = new List<string>();
                foreach (var id in elementIds)
                {
                    var req = JsonSerializer.Serialize(new { cmd = "element.get", type = elementType, id });
                    string raw = await PipeClient.SendRawAsync(resolvedPid, req);

                    using var doc = JsonDocument.Parse(raw);
                    var root = doc.RootElement;

                    if (!root.TryGetProperty("ok", out var okProp) || !okProp.GetBoolean())
                        continue;

                    if (!root.TryGetProperty("data", out var data))
                        continue;

                    if (Matches(data, prop, op, value))
                        matchedIds.Add(id);
                }

                // Emit filtered list in same format as element list.
                var result = new
                {
                    ok = true,
                    data = new { type = elementType, ids = matchedIds }
                };
                Console.WriteLine(JsonSerializer.Serialize(result));
                Environment.Exit(0);
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, propOption, opOption, valueOption);

        return cmd;
    }

    // ---------------------------------------------------------------------------
    // Filter logic
    // ---------------------------------------------------------------------------

    static bool Matches(JsonElement data, string prop, string op, string filterValue)
    {
        // Look for the property; try both exact case and lowercase.
        string? rawValue = null;
        if (data.TryGetProperty(prop, out var propEl))
            rawValue = propEl.ToString();
        else if (data.TryGetProperty(prop.ToLowerInvariant(), out propEl))
            rawValue = propEl.ToString();

        if (rawValue == null) return false;

        // Numeric comparisons.
        if (op is "lt" or "le" or "gt" or "ge")
        {
            if (!double.TryParse(rawValue, System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out double lhs) ||
                !double.TryParse(filterValue, System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out double rhs))
                return false;

            return op switch
            {
                "lt" => lhs < rhs,
                "le" => lhs <= rhs,
                "gt" => lhs > rhs,
                "ge" => lhs >= rhs,
                _    => false
            };
        }

        // String comparisons (case-insensitive).
        string lhsStr = rawValue.ToLowerInvariant();
        string rhsStr = filterValue.ToLowerInvariant();

        return op switch
        {
            "eq"           => lhsStr == rhsStr,
            "ne"           => lhsStr != rhsStr,
            "contains"     => lhsStr.Contains(rhsStr),
            "not-contains" => !lhsStr.Contains(rhsStr),
            "starts-with"  => lhsStr.StartsWith(rhsStr),
            "ends-with"    => lhsStr.EndsWith(rhsStr),
            _              => throw new ArgumentException($"Unknown operator \"{op}\". Valid: eq, ne, lt, le, gt, ge, contains, not-contains, starts-with, ends-with")
        };
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    static int? TryParseSessionPid(string line)
    {
        try
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;
            if (root.TryGetProperty("kind", out var k) && k.GetString() == "session" &&
                root.TryGetProperty("pid", out var p) && p.TryGetInt32(out int pid))
                return pid;
        }
        catch (JsonException) { }
        return null;
    }

    static void TryParseElementList(string line, out string? elementType, out List<string> ids)
    {
        elementType = null;
        ids = new();
        try
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;
            if (!root.TryGetProperty("ok", out var ok) || !ok.GetBoolean()) return;
            if (!root.TryGetProperty("data", out var data)) return;
            if (!data.TryGetProperty("ids", out var idsEl)) return;
            if (!data.TryGetProperty("type", out var typeEl)) return;
            // Must have an "ids" array (not some other data shape that happens to have "type").
            if (idsEl.ValueKind != JsonValueKind.Array) return;

            elementType = typeEl.GetString();
            foreach (var id in idsEl.EnumerateArray())
            {
                var s = id.GetString();
                if (s != null) ids.Add(s);
            }
        }
        catch (JsonException) { }
    }
}
