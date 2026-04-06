# swmm_cli element filter

Filter a piped element list by testing one property against a value; use this command whenever you need a subset of elements that meet a condition — for example, all junctions above a given invert elevation, or all conduits tagged with a particular label. Multiple filters can be chained in sequence to AND conditions together.

## Syntax

```
swmm_cli element list --type <type> [--pid N] | swmm_cli element filter --prop <prop> --op <op> --value <value> [--pid N]
```

`element filter` **must** be piped from `element list` or from a prior `element filter`. It cannot be invoked standalone — it reads the element list from stdin.

## Parameters

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--prop` | string | Yes | Property name to filter on. Must match a field returned by `element get` for the element type (e.g. `invert_elev`, `length`, `tag`). Case-insensitive lookup — both `invert_elev` and `Invert_Elev` work. |
| `--op` | string | Yes | Comparison operator. See operator table below. |
| `--value` | string | Yes | Value to compare against. For numeric operators, both sides are parsed as `double` using invariant culture. For string operators, comparison is case-insensitive. |
| `--pid` | integer | No | PID of the target `Epaswmm5.exe` process. Usually not needed when piping from `process launch` — the PID is extracted from the upstream session line automatically. |

### Operator reference

| `--op` value | Type | Matches when |
|--------------|------|-------------|
| `eq` | string | property value equals `--value` (case-insensitive) |
| `ne` | string | property value does not equal `--value` |
| `contains` | string | property value contains `--value` as a substring |
| `not-contains` | string | property value does not contain `--value` |
| `starts-with` | string | property value starts with `--value` |
| `ends-with` | string | property value ends with `--value` |
| `lt` | numeric | property value < `--value` (parsed as double) |
| `le` | numeric | property value ≤ `--value` |
| `gt` | numeric | property value > `--value` |
| `ge` | numeric | property value ≥ `--value` |

String operators (`eq`, `ne`, `contains`, `not-contains`, `starts-with`, `ends-with`) are always case-insensitive.

Numeric operators (`lt`, `le`, `gt`, `ge`) require both the property value and `--value` to be parseable as a floating-point number. If either side cannot be parsed as a number, the element is excluded from the results (treated as non-matching).

## Response shape

```json
{ "ok": true, "data": { "type": "junction", "ids": ["J2", "J4", "J9"] } }
{ "ok": false, "error": "No element list found in piped input — pipe element list first" }
```

**Success fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `true` on success |
| `data.type` | string | Element type echoed from the input list (e.g. `"junction"`) |
| `data.ids` | array of string | IDs of elements that passed the filter condition. May be empty if no elements matched. |

**Failure fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | bool | Always `false` on failure |
| `error` | string | Human-readable reason: no element list in stdin, unknown operator, pipe error, etc. |

The output format (`{"ok":true,"data":{"type":"...","ids":[...]}}`) is identical to `element list` output, so the result of one `element filter` can be piped directly into another `element filter`.

## How it works internally

For each element ID in the piped list, `element filter`:
1. Calls `element get` on that element via the SWMM named pipe.
2. Looks up the specified `--prop` in the returned data object (case-insensitive).
3. Applies the operator comparison.
4. Includes the element ID in the output only if the comparison is true.

Elements where the property does not exist, or where a numeric parse fails for numeric operators, are silently excluded.

**Last-wins semantics for chained filters:** when two or more `element filter` stages are chained, each stage finds the last element list in its stdin (the previous filter's output), not the first one (the original full list). This ensures each filter operates on the narrowed-down list from the preceding filter.

## How to use it

### Filter junctions above an elevation threshold

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970
```

Example output:
```json
{"kind":"session","pid":18432}
{"ok":true,"data":{"file":"C:\\Models\\model.inp"}}
{"ok":true,"data":{"type":"junction","ids":["J1","J5","J6","J7","J8","J9","J10","J11","J12"]}}
{"ok":true,"data":{"type":"junction","ids":["J6","J7","J8"]}}
```

The last line is the filtered result.

### Filter conduits by tag

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type conduit | \
  swmm_cli element filter --prop tag --op eq --value Swale
```

### Filter elements whose ID contains a substring

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop id --op contains --value "_main"
```

## PID resolution for this command

`element filter` uses the standard six-step resolution chain. In pipeline mode the PID is extracted from the `{"kind":"session","pid":N}` line in stdin — no `--pid` flag needed. In standalone use (with a pre-existing session or `SWMM_PID` env var), `--pid` can be omitted if a session file exists or exactly one SWMM instance is running.

| Priority | Source |
|----------|--------|
| 1 | `--pid` flag |
| 2 | `{"kind":"session","pid":N}` line in piped stdin |
| 3 | `SWMM_PID` environment variable |
| 4 | `.swmm/session.json` in CWD |
| 5 | Auto-discovery (exactly one `Epaswmm5.exe`) |
| 6 | Error |

## How to chain it

### Chaining multiple filters (AND logic)

Each chained filter narrows the list further. This implements AND semantics — an element must pass every filter to appear in the final output.

```bash
# Conduits tagged "Swale" AND longer than 200 ft AND ID does not contain "2"
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type conduit | \
  swmm_cli element filter --prop tag --op eq --value Swale | \
  swmm_cli element filter --prop length --op gt --value 200 | \
  swmm_cli element filter --prop id --op not-contains --value 2
```

```bash
# Junctions above elevation 4970 AND max_depth greater than 2
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970 | \
  swmm_cli element filter --prop max_depth --op gt --value 2
```

### Extracting just the matched IDs with jq

The last line of stdout is the filter result. Extract it with `tail -1 | jq`:

```bash
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type junction | \
  swmm_cli element filter --prop invert_elev --op gt --value 4970 | \
  tail -1 | jq '.data.ids'
```

### Full workflow: filter → inspect each matched element

```bash
# Find all conduits longer than 300 ft
swmm_cli process launch | \
  swmm_cli file open --path "C:/Models/model.inp" | \
  swmm_cli element list --type conduit | \
  swmm_cli element filter --prop length --op gt --value 300 | \
  tail -1 | jq -r '.data.ids[]' | while read ID; do
    swmm_cli element get --type conduit --id "$ID"
  done
```

## Gotchas and caveats for agents

- **Must be piped from element list or element filter**: `element filter` has no `--type` flag and cannot discover elements on its own. It reads the element type and ID list from `{"ok":true,"data":{"type":"...","ids":[...]}}` in stdin. If stdin contains no such line, the command exits 1 with `"No element list found in piped input"`.

- **Fetches every element via pipe**: the filter calls `element get` for every ID in the input list to read the property value. For a list of 100 elements, this is 100 named-pipe round-trips. For large models, consider pre-filtering by type to reduce the list before applying property filters.

- **Properties not present → excluded**: if an element does not have the requested property (e.g., filtering conduits on `invert_elev`, which is a node property), those elements are silently excluded. The result may be an empty list without any error.

- **Numeric parse failure → excluded**: for numeric operators (`lt`, `le`, `gt`, `ge`), if the property value or `--value` cannot be parsed as a floating-point number, the element is excluded silently. Check the property spelling and ensure `--value` is a valid number.

- **Empty result is valid**: `{"ok":true,"data":{"type":"junction","ids":[]}}` is a successful response meaning no elements matched the condition. It is not an error. An empty list can be piped into further filters, which will also return empty lists.

- **Unknown operator**: passing an unrecognised `--op` value (e.g., `--op regex`) throws `ArgumentException` and the command exits 1 with an error listing valid operators.

- **Stale session store causes timeouts**: if `.swmm/session.json` points to a dead SWMM process and no session line is in stdin, each `element get` call will time out after 5 seconds. With 12 elements that is 60 seconds of waiting. Always use full-chain pipelines starting from `process launch` to ensure the PID is valid.

- **Output accumulates upstream lines**: the command re-emits every upstream line before appending its own output. In a terminal, you will see the session line, the `file open` result, the `element list` result, and then the filter result — all on stdout. To extract only the filter result, use `tail -1` after the last filter stage.

- **Case-insensitive property lookup**: the property name in `--prop` is matched against the element data object using exact case first, then lowercase fallback. Both `invert_elev` and `Invert_Elev` work correctly.
