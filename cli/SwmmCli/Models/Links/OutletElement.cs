using System.Text.Json.Serialization;

namespace SwmmCli.Models.Links;

record OutletElement(
    [property: JsonPropertyName("id")]               string Id,
    [property: JsonPropertyName("type")]             string Type,
    [property: JsonPropertyName("comment")]          string Comment,
    [property: JsonPropertyName("tag")]              string Tag,
    [property: JsonPropertyName("inlet_node")]       string InletNode,
    [property: JsonPropertyName("outlet_node")]      string OutletNode,
    [property: JsonPropertyName("offset_height")]    string OffsetHeight,
    [property: JsonPropertyName("flap_gate")]        string FlapGate,
    [property: JsonPropertyName("outlet_type")]      string OutletType,
    [property: JsonPropertyName("discharge_curve")]  string DischargeCurve
);
