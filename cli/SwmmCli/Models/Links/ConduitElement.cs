using System.Text.Json.Serialization;

namespace SwmmCli.Models.Links;

record ConduitElement(
    [property: JsonPropertyName("id")]           string Id,
    [property: JsonPropertyName("type")]         string Type,
    [property: JsonPropertyName("comment")]      string Comment,
    [property: JsonPropertyName("tag")]          string Tag,
    [property: JsonPropertyName("inlet_node")]   string InletNode,
    [property: JsonPropertyName("outlet_node")]  string OutletNode,
    [property: JsonPropertyName("shape")]        string Shape,
    [property: JsonPropertyName("geom1")]        string Geom1,
    [property: JsonPropertyName("geom2")]        string Geom2,
    [property: JsonPropertyName("geom3")]        string Geom3,
    [property: JsonPropertyName("geom4")]        string Geom4,
    [property: JsonPropertyName("length")]       string Length,
    [property: JsonPropertyName("roughness")]    string Roughness,
    [property: JsonPropertyName("in_offset")]    string InOffset,
    [property: JsonPropertyName("out_offset")]   string OutOffset,
    [property: JsonPropertyName("init_flow")]    string InitFlow,
    [property: JsonPropertyName("max_flow")]     string MaxFlow,
    [property: JsonPropertyName("entry_loss")]   string EntryLoss,
    [property: JsonPropertyName("exit_loss")]    string ExitLoss,
    [property: JsonPropertyName("avg_loss")]     string AvgLoss,
    [property: JsonPropertyName("seepage")]      string Seepage,
    [property: JsonPropertyName("check_valve")]  string CheckValve,
    [property: JsonPropertyName("culvert_code")] string CulvertCode,
    [property: JsonPropertyName("barrels")]      string Barrels
);
