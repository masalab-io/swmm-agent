using System.Text.Json;
using SwmmCli.Models.Links;
using SwmmCli.Models.Nodes;
using SwmmCli.Models.Subcatchments;

namespace SwmmCli.Models;

static class SwmmElementDeserializer
{
    static readonly JsonSerializerOptions _opts = new() { PropertyNameCaseInsensitive = true };

    /// <summary>
    /// Reads the "type" field from <paramref name="root"/> and deserializes to the
    /// matching strongly-typed record. Returns null if the type is unrecognised.
    /// </summary>
    public static object? Deserialize(JsonElement root)
    {
        if (!root.TryGetProperty("type", out var typeProp))
            return null;

        return typeProp.GetString()?.ToLowerInvariant() switch
        {
            "junction"     => root.Deserialize<JunctionElement>(_opts),
            "outfall"      => root.Deserialize<OutfallElement>(_opts),
            "divider"      => root.Deserialize<DividerElement>(_opts),
            "storage"      => root.Deserialize<StorageElement>(_opts),
            "conduit"      => root.Deserialize<ConduitElement>(_opts),
            "pump"         => root.Deserialize<PumpElement>(_opts),
            "orifice"      => root.Deserialize<OrificeElement>(_opts),
            "weir"         => root.Deserialize<WeirElement>(_opts),
            "outlet"       => root.Deserialize<OutletElement>(_opts),
            "subcatchment" => root.Deserialize<SubcatchmentElement>(_opts),
            _              => null,
        };
    }
}
