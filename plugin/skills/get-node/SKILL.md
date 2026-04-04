---
name: get-node
description: Get properties of a SWMM node (junction, outfall, storage) by ID. Use when the user asks about node data, invert elevation, max depth, or coordinates.
---

Get the properties of a SWMM node using the swmm_cli tool.

First, find the SWMM process PID if not already known:
```bash
swmm_cli process list
```

Then retrieve the node:
```bash
swmm_cli element get --type junction --id "$ARGUMENTS" --pid <pid>
```

Return the JSON result to the user, highlighting the key properties: invert elevation, max depth, and X/Y coordinates.
