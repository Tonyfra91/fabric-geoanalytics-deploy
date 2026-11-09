---
title: 02 Deploy Azure
description: Create the Azure resources and save the details needed for Fabric setup.
ms.date: 2026-11-08
---

## 02 Deploy Azure

Complete [01 Start here](../01-start-here/README.md) first.
You are now ready to load the current compiled private template in Azure.

### Where

Use your Azure portal browser tab. In the Copilot route, review parameters
in VS Code Chat first. All terminal commands still run at the repository root.

### Do

Continue the route you selected:

* [Copilot Fast Pass: FP09](./copilot.md)
* [Manual alternative: Steps 13-14](./manual.md)

At Step 13, use the preferred **Deploy to Azure** button to load the commit-pinned
private compiled template in **Custom deployment**. Manual **Load file** using
the same checkout's compiled JSON remains the supported fallback.
Enter the reviewed parameters, review costs and select **Create**.
Copilot does not press Create for you.

### See

Azure reports **Deployment succeeded**, with private-only Key Vault, VNet/subnet,
private endpoint and private DNS. Public vault access remains **Disabled**.
The guide shows you where to find
the deployment name and Key Vault details to save for the next step.
Use the name shown on the deployment page; it may differ from the
`deploymentName` you entered in the form.
Fabric setup comes next, so you do not need to create its items yourself.

### Next

After verifying Azure success and outputs, open
[03 Finish Fabric](../03-finish-fabric/README.md).
If Azure reports an error, resolve it before continuing. The guide explains
which details to check and when to ask your administrator for help.

[Previous: 01 Start here](../01-start-here/README.md)
