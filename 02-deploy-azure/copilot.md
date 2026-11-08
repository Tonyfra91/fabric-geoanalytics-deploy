---
title: 02 Deploy Azure - Copilot Fast Pass
description: Review Azure settings with Copilot and create the Azure resources in the portal.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## FP09 Review parameters and load the private Azure template

| Checkpoint | Instruction                                                                                                                                  |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Where      | Chat for parameter review, then Azure portal Custom deployment                                                                               |
| Do         | You enter the reviewed values, select Create, and inspect deployment Outputs                                                                 |
| See        | Azure `Deployment succeeded`, version `1.0`, and the recorded deployment name                                                                |
| Next       | [FP10](../03-finish-fabric/copilot.md#fp10-review-the-initialized-configuration-and-validation) after telling Copilot the actual record name |

Copilot should produce a field-by-field table using your approved values:
subscription, ownership `deploymentName`, region, new group, unique vault,
executing user's `userObjectId`, dedicated private-network names/ranges, and the capacity choice.
An existing capacity remains the default. Review it against your private note.

Open Azure **Custom deployment > Build your own template in the editor > Load file**
and load the checkout's compiled `deploy\azuredeploy.json`. Save, enter the reviewed
fields, and select **Review + create > Create** yourself. Do not use the old
`v0.1.0` release button or change its immutable tag.
The complete field/screen reference is
[manual Step 13](./manual.md#step-13-load-the-private-template-and-enter-the-azure-parameters).
Copilot must not press Create for you or substitute CLI Azure deployment.

See/expect: Azure **Custom deployment**, then deployment progress.
Wait for **Deployment succeeded**. Record the subscription deployment record
name and inspect Outputs as in
[manual Step 14](./manual.md#step-14-record-azure-success-and-the-handoff-outputs).

Tell Copilot:

```text
Azure shows Deployment succeeded. The subscription deployment record name is
<actual-record-name>. Read and verify that deployment; do not redeploy Azure.
```

Replace the placeholder with the actual name; do not use the template ownership
name unless it really is also the record name. Do not send keys/tokens.
If Azure reports a failure, share the error with Copilot after removing
private details. Wait for **Deployment succeeded** before continuing;
a visible vault alone does not mean setup is complete.
