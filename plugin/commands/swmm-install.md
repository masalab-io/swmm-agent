---
description: Install the SWMM Agent exe into your EPA SWMM installation. Run this once after installing the plugin.
---

Install the SWMM Agent executable into the user's EPA SWMM 5.2.4 installation folder.

## Steps

1. Find the SWMM installation directory by checking common locations:
```bash
ls "C:/Program Files/EPA SWMM 5.2.4/" 2>/dev/null || \
ls "C:/Program Files (x86)/EPA SWMM 5.2.4/" 2>/dev/null || \
ls "C:/Program Files/EPA SWMM 5.2/" 2>/dev/null || \
echo "NOT FOUND"
```

If not found, ask the user: "Where is your EPA SWMM 5.2.4 installed?"

2. Back up the existing exe:
```bash
cp "<swmm_dir>/Epaswmm5.exe" "<swmm_dir>/Epaswmm5.exe.bak"
```

3. Copy the 3 files from the plugin's dist/ folder:
```bash
cp "${CLAUDE_PLUGIN_ROOT}/dist/Epaswmm5.exe" "<swmm_dir>/Epaswmm5.exe"
cp "${CLAUDE_PLUGIN_ROOT}/dist/runswmm.exe"  "<swmm_dir>/runswmm.exe"
cp "${CLAUDE_PLUGIN_ROOT}/dist/swmm5.dll"    "<swmm_dir>/swmm5.dll"
```

4. Confirm success:
```bash
ls "<swmm_dir>/Epaswmm5.exe"
```

Report success to the user. Tell them to launch SWMM normally — the agent pipe server starts automatically. They can now use `/swmm-agent:attach` to connect.
