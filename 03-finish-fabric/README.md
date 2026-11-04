---
title: 03 Finish Fabric
description: Initialize configuration, validate, finish Fabric and enter the key safely.
ms.date: 2026-11-03
---

## 03 Finish Fabric

Complete [02 Deploy Azure](../02-deploy-azure/README.md) first.
This stage uses the existing Azure deployment; it must not submit another one.

### Where

Use VS Code Chat and your local PowerShell 7 terminal at the repository root.
Open the Fabric browser tab when instructed to inspect the created items.
Enter the Esri key only in your own visible terminal's hidden prompt.

### Do

Continue the route you selected:

* [Copilot Fast Pass: FP10-FP12](./copilot.md)
* [Manual alternative: Steps 15-20](./manual.md)

Review the generated configuration and five genuine confirmations.
Validation must pass before you approve Fabric setup.
You run the secret-entry command yourself; never paste the key into Chat.

### See

Status reports `Configured`, runtime `1.3` and verified notebook bindings.
The named workspace contains the expected Lakehouse, environment and notebook.
The secret command reports successful storage and metadata verification.
Runtime secret access is not proven until the next stage's preflight.
No simulation should have been run yet.

### Next

Open [04 Run and verify](../04-run-and-verify/README.md).
Fabric setup and secret storage do not authorize a compute run; approve it
separately after reviewing the target and bounded inputs.

[Previous: 02 Deploy Azure](../02-deploy-azure/README.md)
