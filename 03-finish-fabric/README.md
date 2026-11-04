---
title: 03 Finish Fabric
description: Create the Fabric workspace items and store your Esri key safely.
ms.date: 2026-11-04
---

## 03 Finish Fabric

Complete [02 Deploy Azure](../02-deploy-azure/README.md) first.
This step uses the Azure resources you just created.

### Where

Use VS Code Chat and your local PowerShell 7 terminal at the repository root.
Open the Fabric browser tab when instructed to inspect the created items.
Enter the Esri key only in your own visible terminal's hidden prompt.

### Do

Continue the route you selected:

* [Copilot Fast Pass: FP10-FP12](./copilot.md)
* [Manual alternative: Steps 15-20](./manual.md)

Review the settings file and confirm the five permissions and licensing
approvals. Once the checks pass, approve Fabric setup.
When prompted, run the key-entry command yourself and enter the key in the
terminal. Keep it out of Chat and configuration files.

### See

Your Fabric workspace contains a Lakehouse, environment and notebook.
The status command reports `Configured` and runtime `1.3`, with the notebook
connected to the expected items. The key-entry command confirms that the
key was stored.
You have not run the model yet. The next step checks that Fabric can use
the key before running the simulation.

### Next

Open [04 Run and verify](../04-run-and-verify/README.md).
You will review the small sample run and approve it separately.

[Previous: 02 Deploy Azure](../02-deploy-azure/README.md)
