using System.Text.Json.Serialization;

namespace SwmmCli.Models.Nodes;

record StorageElement(
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
    [property: JsonPropertyName("evap_factor")]      string EvapFactor,
    [property: JsonPropertyName("seepage")]          string Seepage,
    [property: JsonPropertyName("geometry")]         string Geometry,
    [property: JsonPropertyName("coeff0")]           string Coeff0,
    [property: JsonPropertyName("coeff1")]           string Coeff1,
    [property: JsonPropertyName("coeff2")]           string Coeff2,
    [property: JsonPropertyName("area_table")]       string AreaTable
);
