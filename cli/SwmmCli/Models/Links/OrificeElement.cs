using System.Text.Json.Serialization;

namespace SwmmCli.Models.Links;

record OrificeElement(
    [property: JsonPropertyName("id")]               string Id,
    [property: JsonPropertyName("type")]             string Type,
    [property: JsonPropertyName("comment")]          string Comment,
    [property: JsonPropertyName("tag")]              string Tag,
    [property: JsonPropertyName("inlet_node")]       string InletNode,
    [property: JsonPropertyName("outlet_node")]      string OutletNode,
    [property: JsonPropertyName("orifice_type")]     string OrificeType,
    [property: JsonPropertyName("shape")]            string Shape,
    [property: JsonPropertyName("height")]           string Height,
    [property: JsonPropertyName("width")]            string Width,
    [property: JsonPropertyName("bottom_height")]    string BottomHeight,
    [property: JsonPropertyName("discharge_coeff")]  string DischargeCoeff,
    [property: JsonPropertyName("flap_gate")]        string FlapGate
);
