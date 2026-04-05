namespace SwmmCli.Models;

/// <summary>
/// Slim element reference emitted in pipe mode by "element list".
/// JSON: {"kind":"swmm_element","id":"J1","type":"junction"}
/// </summary>
record SwmmElementRef(string Kind, string Id, string Type);
