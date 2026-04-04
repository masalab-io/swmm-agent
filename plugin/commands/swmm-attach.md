---
description: Attach the SWMM Agent plugin to a running SWMM instance. Run this once before using any SWMM skills.
---

Attach the SWMM Agent to a running SWMM 5.2.4 process.

1. List running SWMM instances:
```bash
swmm_cli process list
```

2. If no instances found, ask the user to open SWMM first.

3. If the plugin is not yet injected, run the loader:
```bash
swmm_agent_loader.exe
```

4. Confirm the connection:
```bash
swmm_cli process list
```

Report which SWMM instance(s) are now available and their PIDs. The user can now use SWMM skills.
