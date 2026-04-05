using System.Text.Json.Serialization;

namespace SwmmCli.Models.Nodes;

record DividerElement(
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
    [property: JsonPropertyName("ponded_area")]      string PondedArea,
    [property: JsonPropertyName("divider_link")]     string DividerLink,
    [property: JsonPropertyName("divider_type")]     string DividerType,
    [property: JsonPropertyName("cutoff_flow")]      string CutoffFlow,
    [property: JsonPropertyName("qmin")]             string Qmin,
    [property: JsonPropertyName("dmax")]             string Dmax,
    [property: JsonPropertyName("qcoeff")]           string Qcoeff
);
