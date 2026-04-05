using System.Text.Json.Serialization;

namespace SwmmCli.Models.Subcatchments;

record SubcatchmentElement(
    [property: JsonPropertyName("id")]           string Id,
    [property: JsonPropertyName("type")]         string Type,
    [property: JsonPropertyName("comment")]      string Comment,
    [property: JsonPropertyName("tag")]          string Tag,
    [property: JsonPropertyName("rain_gage")]    string RainGage,
    [property: JsonPropertyName("outlet")]       string Outlet,
    [property: JsonPropertyName("area")]         string Area,
    [property: JsonPropertyName("width")]        string Width,
    [property: JsonPropertyName("slope")]        string Slope,
    [property: JsonPropertyName("imperv")]       string Imperv,
    [property: JsonPropertyName("imperv_n")]     string ImpervN,
    [property: JsonPropertyName("perv_n")]       string PervN,
    [property: JsonPropertyName("imperv_ds")]    string ImpervDs,
    [property: JsonPropertyName("perv_ds")]      string PervDs,
    [property: JsonPropertyName("pct_zero")]     string PctZero,
    [property: JsonPropertyName("route_to")]     string RouteTo,
    [property: JsonPropertyName("pct_routed")]   string PctRouted,
    [property: JsonPropertyName("infil_model")]  string InfilModel,
    [property: JsonPropertyName("groundwater")]  string Groundwater,
    [property: JsonPropertyName("snowpack")]     string Snowpack
);
