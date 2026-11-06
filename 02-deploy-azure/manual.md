---
title: 02 Deploy Azure - Manual walkthrough
description: Use the Azure button and save the deployment details needed for Fabric setup.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## Deploy the Azure foundation

### Step 13 Press the blue button and enter the Azure parameters

Where to be: this guide's button, then Azure portal's Custom deployment form.

Why now: your access, names, capacity, licensing and network approvals are
confirmed. The button creates the Azure foundation, not the spatial results.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTonyfra91%2Ffabric-geoanalytics-deploy%2Fv0.1.0%2Fdeploy%2Fazuredeploy.json)

1. Select **Deploy to Azure** above or on the repository's main README.
2. Expect Azure portal to open a **Custom deployment** template form. If asked
   to sign in, use the same Step 03 account. Do not build/upload another template.
3. Select your approved subscription. This is a **subscription-scoped**
   deployment; the template creates its own resource group.
4. Fill the template fields using the table below. Azure may display camelCase
   names with spaces, such as “Deployment Name”.
5. If Azure displays a separate deployment metadata **Region/Location** field,
   choose the approved deployment region there too. The template's `location`
   parameter controls the actual resource/capacity region.
6. Select **Review + create**, review validation, subscription, names, resources
   and cost implications, then select **Create** only if they match your note.

| Template field           | Enter/select this for the existing-capacity path                             |
| ------------------------ | ---------------------------------------------------------------------------- |
| `deploymentName`         | Your approved ownership name from Step 05                                    |
| `location`               | Azure region identifier matching the capacity from Step 09                   |
| `resourceGroupName`      | Fresh dedicated group name from Step 05                                      |
| `keyVaultName`           | Available globally unique vault name from Step 05                            |
| `userObjectId`           | The GUID from Step 03 `az ad signed-in-user show`                            |
| `shouldCreateCapacity`   | `false`                                                                      |
| `capacityName`           | Leave the optional value null/unset; do not type an existing capacity's name |
| `capacitySku`            | Leave default `F2`; ignored when `shouldCreateCapacity=false`                |
| `capacityAdministrators` | Leave the empty JSON array `[]`; do not enter the Esri key here              |

Do not manually type the literal string `"null"` for a nullable value.
Do not enter your email, application/client ID, or subscription ID in `userObjectId`.

For an administrator-approved **new capacity**, set `shouldCreateCapacity=true`,
enter a new lowercase alphanumeric `capacityName` beginning with a letter
(3-63 characters), choose the approved F SKU, and enter administrator UPNs
as a JSON array, for example `["capacity.admin@customer.example"]`.
You must have cost/quota/region approval and the executing user's required
capacity access. New-capacity creation does not bypass Fabric/Esri prerequisites.
Do not use this option to adopt or change existing customer capacity.

See/expect: Azure deployment starts. The resources are a dedicated group,
RBAC-enabled Key Vault, and Key Vault Secrets Officer assignment to your user,
plus new capacity only if opted in.
No Esri key is created or accepted, and no notebook is executed.

> [!NOTE]
> The unchanged button uses the released `v0.1.0` template. The current local
> Bicep and generated template add a private-only Key Vault network foundation
> for a future release. See the [private foundation reference](../deploy/README.md#private-key-vault-foundation)
> for its additional parameters and remaining Fabric/secret-setup stages.
> Do not rerun Azure deployment over an existing manually validated foundation.

If review/deployment reports invalid parameters, permissions, policy, name
conflicts or quota, stop and inspect the error. Do not repeatedly click Create
or select unrelated existing resources to get past it.

Next: [Step 14](#step-14-record-azure-success-and-the-handoff-outputs).
Stay in Azure until deployment has succeeded.

### Step 14 Record Azure success and the handoff outputs

Where to be: Azure subscription deployment Overview/Outputs, then local PowerShell.

1. On the Azure deployment overview, wait for **Deployment succeeded**.
2. Record the deployment's record name shown on that page, often
   `Microsoft.Template-...`. This is the name for `-AzureDeploymentName`.
3. Open **Outputs** on the deployment page.
4. Verify `experienceVersion` is `1.0`, `keyVaultUri` is an HTTPS
   `*.vault.azure.net/` endpoint, and `keyVaultId` belongs to your subscription,
   group and vault.
5. If you created capacity, verify `capacityResourceId` refers to that new capacity.

If you closed the deployment page: Azure search **Subscriptions > your
subscription > Deployments > select this deployment > Outputs**.
Do not look only in the resource group's deployment list: the handoff reads
the **subscription** deployment record.

In PowerShell, verify the recorded name:

```powershell
az deployment sub show --name '<portal-deployment-record-name>' --query '{state:properties.provisioningState,outputs:properties.outputs}' --output json
```

See/expect: `"state": "Succeeded"` and those same outputs.
If the name cannot be found, verify the active subscription and use the exact
record name, not the template `deploymentName`.
If Azure failed, inspect its error/operations details and resolve the failure
before initialization. Resources may remain after partial failure.

At this point, **Fabric is not deployed yet**. Do not manually import the
original notebook or create a Lakehouse.

Next: [Step 15](../03-finish-fabric/manual.md#step-15-generate-the-nonsecret-local-configuration).
Return to local PowerShell, not a Fabric notebook or Azure Cloud Shell.
