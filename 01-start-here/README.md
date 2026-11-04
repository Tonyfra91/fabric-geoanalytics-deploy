---
title: 01 Start here
description: Choose one route, prepare tools and verify access before deployment.
ms.date: 2026-11-03
---

## 01 Start here

This is the first folder to open. You do not need to understand Bicep or
browse the implementation folders before starting.

### Where

Start in your browser. The instructions tell you when to install tools,
clone the repository and open VS Code.
Open the **whole cloned repository** in VS Code, not a numbered subfolder.
These folders organize the reading journey; all terminal commands run from
the repository root containing `deploy.ps1`.

### Do

Choose one route and keep following that route through folders 01-04:

* [Copilot Fast Pass, preferred: FP01-FP08](./copilot.md)
* [Manual alternative: Steps 01-12](./manual.md)

Copilot runs approved repeatable commands; you still complete sign-in,
obtain real administrator approvals, press Azure Create and enter the key.
The manual route reaches the same result without Copilot.
You do not perform both routes.

### See

Your tools work, the correct repository is open, and Azure/Fabric identity,
permissions, capacity, GeoAnalytics enablement, Esri entitlement, networking
and costs are confirmed. Unknown or missing prerequisites mean stop and
contact the named owner. No cloud resources or Spark jobs should be created
in this stage. Do not press the Azure button yet.

### Next

Only after FP08 or manual Step 12 is complete, open
[02 Deploy Azure](../02-deploy-azure/README.md).

[Back to the story and journey overview](../README.md)
