using System.Text.Json.Serialization;

namespace SwmmCli.Models.Nodes;

record JunctionElement(
    [property: JsonPropertyName("id")]               string Id,
    [property: JsonPropertyName("type")]             string Type,
    [property: JsonPropertyName("x")]                double X,
    [property: JsonPropertyName("y")]                double Y,
    [property: JsonPropertyName("comment")]          string Comment,
    [property: JsonPropertyName("tag")]              string Tag,
    [property: JsonPropertyName("invert_elev")]      string InvertElev,
    [property: JsonPropertyName("max_depth")]        string MaxDepth,
    [property: JsonPropertyName("init_depth")]       string InitDepth,
    [property: JsonPropertyName("surcharge_depth")]  string SurchargeDepth,
    [property: JsonPropertyName("ponded_area")]      string PondedArea
);
