using System.Text.Json.Serialization;

namespace SwmmCli.Models.Links;

record WeirElement(
    [property: JsonPropertyName("id")]                string Id,
    [property: JsonPropertyName("type")]              string Type,
    [property: JsonPropertyName("comment")]           string Comment,
    [property: JsonPropertyName("tag")]               string Tag,
    [property: JsonPropertyName("inlet_node")]        string InletNode,
    [property: JsonPropertyName("outlet_node")]       string OutletNode,
    [property: JsonPropertyName("weir_type")]         string WeirType,
    [property: JsonPropertyName("height")]            string Height,
    [property: JsonPropertyName("length")]            string Length,
    [property: JsonPropertyName("side_slope")]        string SideSlope,
    [property: JsonPropertyName("discharge_coeff")]   string DischargeCoeff,
    [property: JsonPropertyName("flap_gate")]         string FlapGate,
    [property: JsonPropertyName("end_contractions")]  string EndContractions,
    [property: JsonPropertyName("end_coeff")]         string EndCoeff
);
