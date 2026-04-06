# swmm_cli simulate status

Query the status of the most recent simulation run. Rarely needed — `simulate run` already returns the final status.

## Syntax

```
swmm_cli simulate status [--pid N]
```

## Response

```json
{"ok":true,"status":"success"}
```

Values: `none`, `running`, `success`, `warning`, `error`, `failed`.

## When to use it

- Checking the outcome of a run from a **previous session**.
- Querying state **without triggering a new run**.

Do NOT use it to poll after `simulate run` — that command blocks and returns the result directly.

## Notes specific to this command

- **`none`**: no simulation has been run yet in this session.
- **`warning` is valid**: results are available. Retrieve normally.
- **No progress info**: only coarse status strings, no percentage-complete.
