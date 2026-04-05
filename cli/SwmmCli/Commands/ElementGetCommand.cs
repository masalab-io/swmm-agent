using System.CommandLine;
using System.Text.Json;
using SwmmCli.IO;
using SwmmCli.Models;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class ElementGetCommand
{
    static readonly JsonSerializerOptions _pretty = new() { WriteIndented = true };

    public static Command Build()
    {
        var pidOption  = new Option<int?>("--pid",  "PID of the target Epaswmm5 process");
        var typeOption = new Option<string>("--type", "Element type (e.g. junction, conduit)") { IsRequired = true };
        var idOption   = new Option<string>("--id",   "Element ID") { IsRequired = true };

        var cmd = new Command("get", "Get a node/link element's properties");
        cmd.AddOption(pidOption);
        cmd.AddOption(typeOption);
        cmd.AddOption(idOption);
        cmd.SetHandler(async (int? pid, string type, string id) =>
        {
            try
            {
                int resolvedPid = SessionResolver.ResolvePid(pid);
                var req = JsonSerializer.Serialize(new { cmd = "element.get", type, id });
                string raw = await PipeClient.SendRawAsync(resolvedPid, req);

                using var doc = JsonDocument.Parse(raw);
                var root = doc.RootElement;

                if (!root.TryGetProperty("ok", out var okProp) || !okProp.GetBoolean())
                {
                    Console.WriteLine(raw);
                    Environment.Exit(1);
                    return;
                }

                if (root.TryGetProperty("data", out var data))
                {
                    var typed = SwmmElementDeserializer.Deserialize(data);
                    if (typed is not null)
                        Console.WriteLine(JsonSerializer.Serialize(typed, typed.GetType(), _pretty));
                    else
                        Console.WriteLine(JsonSerializer.Serialize(data, _pretty));
                }
                else
                {
                    Console.WriteLine(raw);
                }

                Environment.Exit(0);
            }
            catch (Exception ex)
            {
                Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
                Environment.Exit(1);
            }
        }, pidOption, typeOption, idOption);
        return cmd;
    }
}
