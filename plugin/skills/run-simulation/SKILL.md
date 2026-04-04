---
name: run-simulation
description: Run the SWMM simulation and wait for it to complete. Use when the user asks to run, execute, or simulate the model.
---

Run the SWMM simulation using swmm_cli.

```bash
swmm_cli simulate run --pid <pid>
swmm_cli simulate status --pid <pid>
```

Report the run status to the user (success, warning, error). If successful, offer to retrieve results.
