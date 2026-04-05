using System.Text.Json.Serialization;

namespace SwmmCli.Models.Links;

record PumpElement(
    [property: JsonPropertyName("id")]            string Id,
    [property: JsonPropertyName("type")]          string Type,
    [property: JsonPropertyName("comment")]       string Comment,
    [property: JsonPropertyName("tag")]           string Tag,
    [property: JsonPropertyName("inlet_node")]    string InletNode,
    [property: JsonPropertyName("outlet_node")]   string OutletNode,
    [property: JsonPropertyName("pump_curve")]    string PumpCurve,
    [property: JsonPropertyName("init_status")]   string InitStatus,
    [property: JsonPropertyName("startup_depth")] string StartupDepth,
    [property: JsonPropertyName("shutoff_depth")] string ShutoffDepth
);
