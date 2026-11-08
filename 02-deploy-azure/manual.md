---
title: 02 Deploy Azure - Manual walkthrough
description: Load the current private Azure template and save the Fabric handoff details.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## Deploy the Azure foundation

### Step 13 Load the private template and enter the Azure parameters

Where to be: Azure portal's Custom deployment template editor.

Why now: your access, names, capacity, licensing and network approvals are
confirmed. This creates the private Azure foundation, not the spatial results.

1. In Azure portal, search **Deploy a custom template** and open **Custom deployment**.
2. Select **Build your own template in the editor > Load file**, select the
   checked-out [deploy/azuredeploy.json](../deploy/azuredeploy.json), then **Save**.
   Use the compiled JSON, not Bicep or the credential template. Sign in with the
   same Step 03 account. Do not use the old public-access `v0.1.0` button.
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
| `virtualNetworkName` | Keep derived `vnet-<deploymentName>` or use an approved dedicated name |
| `virtualNetworkAddressPrefix` | Approved nonoverlapping IPv4 range; default `10.0.0.0/16` |
| `privateEndpointSubnetName` | Dedicated subnet; default `snet-private-endpoints` |
| `privateEndpointSubnetPrefix` | Subnet within that range; default `10.0.0.0/24` |
| `privateEndpointName` | Keep derived `pe-<keyVaultName>` |
| `privateEndpointNetworkInterfaceName` | Keep derived `nic-<privateEndpointName>` |
| `privateDnsLinkName` | Keep derived `<virtualNetworkName>-vault` |

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
private-only RBAC-enabled Key Vault, dedicated VNet/subnet, vault private endpoint,
private DNS integration, and Key Vault Secrets Officer assignment to your user,
plus new capacity only if opted in.
No Esri key is created or accepted, and no notebook is executed.

> [!NOTE]
> Key Vault public access stays **Disabled**. The Azure private endpoint does not
> connect your computer or Fabric automatically; Stage 3 establishes the Fabric
> managed endpoint. The revised template-selection UI is repository-tested
> guidance awaiting new-customer validation. Stop if the form is not
> subscription-scoped. Never redeploy an existing validated foundation just to
> change the entry UI.

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
6. Verify `virtualNetworkId`, `keyVaultPrivateEndpointId` and `keyVaultPrivateDnsZoneId`
   refer to the expected dedicated resources. In Key Vault **Networking**, confirm
   public access is **Disabled**. Review its Azure private endpoint connection.

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
