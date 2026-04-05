using System.Text.Json.Serialization;

namespace SwmmCli.Models.Nodes;

record OutfallElement(
    [property: JsonPropertyName("id")]           string Id,
    [property: JsonPropertyName("type")]         string Type,
    [property: JsonPropertyName("x")]            double X,
    [property: JsonPropertyName("y")]            double Y,
    [property: JsonPropertyName("comment")]      string Comment,
    [property: JsonPropertyName("tag")]          string Tag,
    [property: JsonPropertyName("invert_elev")]  string InvertElev,
    [property: JsonPropertyName("tide_gate")]    string TideGate,
    [property: JsonPropertyName("route_to")]     string RouteTo,
    [property: JsonPropertyName("outfall_type")] string OutfallType,
    [property: JsonPropertyName("stage_data")]   string StageData
);
