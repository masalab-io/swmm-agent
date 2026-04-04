---
description: Connect to a running SWMM instance. Run this once per session before using any SWMM skills.
---

Connect to a running SWMM 5.2.4 process.

1. List running SWMM instances:
```bash
swmm_cli process list
```

2. If no instances found, tell the user: "Please open EPA SWMM 5.2.4 first, then run this command again."

3. If instances are found, report them to the user — show the PID and the open file name for each.

Tell the user they can now use SWMM skills. The PID will be used automatically in subsequent commands.
