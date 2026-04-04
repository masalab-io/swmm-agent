---
name: set-node-property
description: Set a property on a SWMM node. Use when the user wants to change invert elevation, max depth, or other node properties.
---

Set a property on a SWMM node using swmm_cli.

Parse the arguments as: <node_id> <property> <value>

```bash
swmm_cli element set --type junction --id <node_id> --prop <property> --value <value> --pid <pid>
```

Valid properties: invert_elev, max_depth, init_depth, surcharge_depth, ponded_area

After setting, verify with:
```bash
swmm_cli element get --type junction --id <node_id> --pid <pid>
```

Confirm the change was applied successfully.
