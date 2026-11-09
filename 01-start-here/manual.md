---
title: 01 Start here - Manual walkthrough
description: Install the tools and confirm the access needed for Azure and Fabric setup.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.


## Before you begin

Prefer Copilot to run the repeatable commands?
Start with [Copilot Fast Pass](./copilot.md), the preferred guided
route in VS Code. The manual route provides the detailed screen reference
and complete fallback if Copilot is unavailable.

Follow Steps 01-12 here, then use the Next links through folders 02-04.
Do not skip ahead to deployment commands. The primary path uses Windows,
PowerShell 7, and an existing
active Fabric F capacity. An optional new-capacity path is included at Step 13.
You do not need to be an Azure administrator to follow the steps, but you
must receive the required permissions and approvals from the appropriate
administrator. This repo cannot grant you access you do not have.

Each step names where to be before you act, describes what to expect, and
ends with a linked next step. Stay on that step if the expected result is
missing. If Copilot brought you here for click-by-click detail, return to
your current Fast Pass step afterward; do not restart this manual deployment.

Keep these three places open:

* This walkthrough in your browser
* A local **PowerShell 7** terminal for commands
* Browser tabs for the [Azure portal](https://portal.azure.com) and
  [Fabric portal](https://app.fabric.microsoft.com)

Browser sign-in and Azure CLI sign-in are separate. Use the **same work/school
user in the same tenant** for both portals and all commands. Do not switch to
an administrator's account midway through deployment. A helper can approve
permissions, but the actual deployment user must be the user entered into the
template's `userObjectId` field.

Menus can vary between tenants. If you cannot find a named page, use the
alternative shown in the step or ask the administrator identified there.
Do not substitute a similarly named setting.
Use your own account, resource names and IDs wherever an example is shown.

### What this test reproduces

You will run the demo's spatial simulation from an Atlanta starting point:
a grid of hexagonal cells (H3), movement between nearby cells and daily spread.
Step 25 adds real US population and social-vulnerability data.
The first run is smaller than the source demo so you can check the setup
before using more compute.

It does **not** reproduce Sean's optional ArcGIS Online/Enterprise publishing,
GeoParquet-only output presentation, or original inline map. It generates six
results tables with geometry stored as text (WKT) and a run summary instead. No Power BI
report, semantic model, dashboard, or hosted map is deployed.
You will inspect the spatial-model results through Fabric tables and SQL.
The fictional model is a teaching exercise, not an outbreak forecast.
See [demo provenance](../docs/demo-provenance.md) for the source and adapter boundaries.

### Record your nonsecret test values

Keep a private local note. Fill each value when its step supplies it.
Never record the Esri key in this table, Git, screenshots, or shared notes.

| Value to record                                      | Where you get it                                   | Used in                                   |
| ---------------------------------------------------- | -------------------------------------------------- | ----------------------------------------- |
| Deployment user's work/school email                  | Your account owner                                 | Both portals and CLI sign-in              |
| Tenant GUID                                          | Azure subscription's directory; Step 03 CLI output | Azure CLI login and configuration         |
| Subscription GUID and name                           | Azure portal Subscriptions; Step 03                | CLI and Azure Custom deployment subscription selector |
| Deployment user's object GUID                        | `az ad signed-in-user show`; Step 03               | Portal `userObjectId`                     |
| Fabric capacity GUID, name, SKU and region           | Step 09 capacity read                              | Initialization and region choice          |
| Ownership name                                       | Choose at Step 05                                  | Template `deploymentName`                 |
| Dedicated resource group name                        | Choose at Step 05                                  | Template `resourceGroupName`              |
| Globally unique vault name                           | Choose at Step 05                                  | Template `keyVaultName`                   |
| Portal deployment record name                        | Azure deployment page; Step 14                     | `-AzureDeploymentName`                    |
| Workspace, Lakehouse, environment and notebook names | Generated configuration; Step 16                   | Finding the created Fabric items          |
| Run ID and six table names                           | Run output/manifest; Step 23                       | Lakehouse and SQL verification            |

The portal deployment record name is **not** the template's ownership name.
Do not interchange them.

## Prepare your identity and capacity

### Step 01 Install and verify the tools

Where to be: Windows Terminal on your computer, then a PowerShell 7 window.

Do this on your Windows computer, not in Fabric or Azure Cloud Shell.

1. Open **Start**, type **Terminal**, and open Windows Terminal.
2. If your organization allows `winget`, run the commands below for tools
   you do not already have. Installation may ask for agreement acceptance or
   administrator approval; request approval through your organization's process.
3. Otherwise use the official installer links in the table. Do not assume you
   can bypass software-installation policy.

```powershell
winget install --exact --id Microsoft.PowerShell
winget install --exact --id Git.Git
winget install --exact --id Microsoft.AzureCLI
winget install --exact --id Python.Python.3.12
```

| Tool         | Official instructions                                                                                                            | Why you need it                                                               |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| PowerShell 7 | [Install PowerShell on Windows](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) | All accelerator commands require version 7 or later                           |
| Git          | [Git for Windows](https://git-scm.com/downloads/win)                                                                             | Download this repository                                                      |
| Azure CLI    | [Install Azure CLI on Windows](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows)                            | Azure sign-in, deployment reads, and Fabric authentication                    |
| Bicep 0.48.1 | [Install Bicep with Azure CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli)           | Local validation and template freshness check                                 |
| Python 3.12  | [Python downloads](https://www.python.org/downloads/windows/)                                                                    | Offline notebook syntax/output-contract tests; not a local Spark installation |

Close and reopen Terminal after installation so PATH changes take effect.
Open **Start**, search for **PowerShell 7**, and open it.

```powershell
$PSVersionTable.PSVersion
git --version
az version
python --version
az bicep install --version v0.48.1
az bicep version
```

See/expect: PowerShell's `Major` is at least `7`, each tool prints a version,
and Bicep reports `0.48.1`. A command-not-found error is a blocker; reopen
Terminal or ask IT to fix the installation. You do not need local PySpark,
GeoAnalytics, or ArcGIS Python packages.

Next: [Step 02](#step-02-get-the-repository-and-pinned-demo).
Keep this PowerShell 7 window open for the remaining commands.

### Step 02 Get the repository and pinned demo

Where to be: the local PowerShell 7 window; commands below enter the repo folder.

In PowerShell 7, choose a local folder where you have write access.
The following commands create a folder under your user profile:

```powershell
New-Item -ItemType Directory -Path "$HOME\fabric-tests" -Force | Out-Null
Set-Location "$HOME\fabric-tests"
git clone https://github.com/Tonyfra91/fabric-geoanalytics-deploy.git
Set-Location .\fabric-geoanalytics-deploy
Get-Location
Get-ChildItem
.\Get-DemoNotebook.ps1
```

See/expect: the folder contains `deploy.ps1`, `Initialize-Experience.ps1`,
`Get-DemoNotebook.ps1`, `deploy`, and `docs`. The final command prints:

```text
Pinned upstream notebook installed locally. Do not add it or generated notebook state to Git.
```

If it is already present with the correct hash, the message is
`Pinned demo notebook already present.` This download is local source
preparation, not a Fabric import. You have not created cloud resources.
Use the current checkout for this walkthrough and its compiled private Azure
template. The old `v0.1.0` button is not the private Fast Pass entry.

Run the offline checks:

```powershell
.\deploy\tests\Test-Accelerator.ps1
.\deploy\tests\Test-Experience.ps1
.\deploy\scripts\Build-Template.ps1 -Check
```

See/expect: `HTTP compatibility checks passed: 27`, `Offline checks passed: 46`,
`Experience checks passed: 35`, the portal/documentation contract PASS message, and
`Portal template matches Bicep source.` These tests use cloud mocks;
they do not certify your permissions or tenant.

For private-network lifecycle coverage, also run
`.\deploy\tests\Test-ManagedPrivateEndpoint.ps1` and expect
`Managed private endpoint checks passed: 35`.

If PowerShell says a script is blocked because it came from the Internet,
review the repo scripts and ask IT about your organization's script policy.
Where permitted, `Unblock-File` on the reviewed script removes its download
mark. Do not disable organization-enforced execution policy.
If the source download is blocked, ask for an authorized copy and use the
[local-source option](../docs/demo-provenance.md#local-retrieval-and-integrity).

Next: [Step 03](#step-03-choose-the-user-tenant-and-azure-subscription).
Run all subsequent repo commands from this folder.

### Step 03 Choose the user, tenant and Azure subscription

Where to be: Azure portal for account details and local PowerShell for CLI sign-in.

1. Open [Azure portal](https://portal.azure.com).
2. Sign in with the work/school account you will use for the entire test.
3. Use the search box at the top, search **Subscriptions**, and open that service.
4. Select the subscription approved for the test. On **Overview**, record its
   subscription name and **Subscription ID**.
5. If the subscription is absent, stop. Ask its administrator to confirm
   your tenant and grant access. Creating a free account or changing directory
   is not a substitute for access to the approved subscription.
6. Obtain that subscription's tenant GUID from the administrator if you do not
   already have it. Enter the GUID, not the tenant's display name, below.

In PowerShell 7, replace the text between angle brackets with your actual GUIDs.
Do not type the angle brackets themselves:

```powershell
az login --tenant '<tenant-guid>'
az account set --subscription '<subscription-guid>'
az account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name,userType:user.type}' --output json
az ad signed-in-user show --query '{displayName:displayName,userPrincipalName:userPrincipalName,objectId:id}' --output json
```

During `az login`, follow the displayed browser or Windows account-selection
prompt, sign in as the same user, and complete MFA if required. If the CLI
displays a subscription-selection prompt, select the approved subscription.
The subsequent `az account set` selects it explicitly.
If browser login cannot start, use the CLI's
`az login --tenant '<tenant-guid>' --use-device-code` option and follow its
displayed URL/code. Do not share that code with another person.

See/expect: the subscription/tenant match your note; `userType` is `user`;
the second command shows your own account and a GUID in `objectId`.
Record that object GUID for the portal template.
If Microsoft Entra directory reads or sign-in are denied, ask your identity
administrator to resolve them. Do not substitute an app/client ID.

Next: [Step 04](#step-04-confirm-azure-deployment-and-role-assignment-permissions).

### Step 04 Confirm Azure deployment and role-assignment permissions

Where to be: Azure portal, in the approved subscription's Access control (IAM).

1. In Azure portal, open **Subscriptions** and select the approved subscription.
2. Open **Access control (IAM)**.
3. On **Check access**, select **View my access**. If the PIM-integrated view
   is displayed, inspect your role assignments there instead.
4. Ask the Azure administrator to confirm you can create the dedicated resource
   group, deploy Key Vault, run subscription deployments, and create the vault's
   role assignment. If creating capacity, they must also authorize that resource.

Expected permission evidence: an appropriately scoped **Owner** role, or an
approved combination of resource deployment permissions and
`Microsoft.Authorization/roleAssignments/write`, such as **Contributor**
plus **Role Based Access Control Administrator**. Custom roles, conditions,
Azure Policy, and deny assignments need administrator review.
Contributor alone is insufficient to grant the vault role.

If your role is eligible through Privileged Identity Management, select
**Activate role**, complete its approval/MFA requirements, and wait for it to
become active before continuing. See
[Check your Azure access](https://learn.microsoft.com/en-us/azure/role-based-access-control/check-access).

Do not assume a subscription Reader role, successful portal login, or an
Azure subscription of your own authorizes this deployment.
If a role is missing, stop and send the administrator request at the end of
the prerequisite section. Azure deployment will not repair missing permissions.

Next: [Step 05](#step-05-confirm-providers-and-choose-fresh-azure-names).

### Step 05 Confirm providers and choose fresh Azure names

Where to be: local PowerShell 7, signed into the approved Azure subscription.

In PowerShell:

```powershell
az provider show --namespace Microsoft.KeyVault --query registrationState --output tsv
az provider show --namespace Microsoft.Network --query registrationState --output tsv
```

See/expect: each prints `Registered`. If not, ask the Azure administrator to
open **Subscriptions > your subscription > Resource providers**, search each
namespace, and register it. The repo's validator does not register providers.
Wait until both commands print `Registered`. Only if an administrator approves
creating a **new** capacity, also check/register `Microsoft.Fabric`:

```powershell
az provider show --namespace Microsoft.Fabric --query registrationState --output tsv
```

Choose these names and record them:

| Value                      | Allowed form                                                                                    | Example to adapt, not reuse blindly |
| -------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------- |
| Ownership `deploymentName` | 3-41 characters; lowercase letter first, then lowercase letters, numbers or hyphens             | `geo-atlanta-youralias-01`          |
| `resourceGroupName`        | Letters, numbers, underscore or hyphen; maximum 90 characters                                   | `rg-geo-atlanta-youralias-01`       |
| `keyVaultName`             | Globally unique, 3-24 characters; letter first; alphanumerics/single hyphens; alphanumeric last | `kv-geo-youralias-01`               |

Check the group and vault before deploying the private template:

```powershell
az group exists --name '<your-new-resource-group-name>' --output tsv
az keyvault check-name --name '<your-new-vault-name>' --query '{available:nameAvailable,reason:reason,message:message}' --output json
```

See/expect: group result `false`, and vault result `"available": true`.
If either name is already in use, choose a different name and check again.
Do not retag an existing resource or put the deployment in a shared group.
Azure Custom deployment does not run the repo's ownership/conflict validator
before deployment, and ARM can update existing named resources.

Next: [Step 06](#step-06-sign-into-fabric-and-verify-your-account).

### Step 06 Sign into Fabric and verify your account

Where to be: the Fabric portal browser tab, not Azure portal.

1. Open [Fabric portal](https://app.fabric.microsoft.com).
2. Sign in with the same user as Step 03.
3. Use the profile/account menu to verify the signed-in work/school account
   and organization. If you are in another organization, switch to the
   deployment tenant before proceeding.
4. Expect the Fabric home page and navigation containing **Workspaces** and
   **OneLake catalog**. Do not start a trial or create items yet.

If you cannot sign in, are redirected to a licensing/signup flow, or cannot
access the approved tenant, stop and contact the Fabric administrator.
Azure portal access does not prove Fabric access.
A Fabric/Power BI per-user license does not supply Spark capacity by itself.
The accelerator requires an active supported F capacity in addition to user access.

Next: [Step 07](#step-07-confirm-permission-to-create-fabric-items).
Leave Fabric open; you return here after automated setup.

### Step 07 Confirm permission to create Fabric items

Where to be: Fabric portal with your administrator, or an approval request to them.

Ask the Fabric administrator to verify this setting for **your user/security
group and selected capacity**, not merely that it is enabled for someone else:

1. Open [Fabric](https://app.fabric.microsoft.com).
2. Select **OneLake catalog > Govern > Configurations > Tenant settings**.
3. Under **Microsoft Fabric**, expand **Users can create Fabric items**.
4. Ensure it is enabled for your user, including any security-group scope or
   exclusions, and select **Apply** if they changed it.
5. Check the selected capacity's override at
   **OneLake catalog > Govern > Capacities > capacity's More options >
   Settings > Delegated tenant settings > Microsoft Fabric >
   Users can create Fabric items**.

See/expect: the administrator confirms the effective setting allows your user
on that capacity. If **Govern** or the setting is unavailable to you, that is
not a command failure: you are not the appropriate administrator.
Forward the request instead of trying to grant yourself the role.
Older tenants may expose the same settings through **Settings > Admin portal**.

This setting allows Lakehouse/Environment/Notebook creation; it is not the
GeoAnalytics integration setting.
Reference: [Enable Fabric](https://learn.microsoft.com/en-us/fabric/admin/fabric-switch).

Next: [Step 08](#step-08-confirm-permission-to-create-the-dedicated-workspace).

### Step 08 Confirm permission to create the dedicated workspace

Where to be: Fabric portal's Workspaces pane; inspect and cancel, do not create.

1. In Fabric's navigation, select **Workspaces**.
2. Look for **New workspace** at the bottom of the workspace pane.
3. If available, you may open it to inspect the **Create a workspace** form,
   then close/cancel it. **Do not select Apply and do not manually create the
   accelerator's workspace.** The finish command creates and marks its own workspace.
4. Ask the Fabric administrator to confirm that the **Create workspaces**
   tenant setting and any allowed security-group scope include your user.

See/expect: a visible new-workspace action and administrator confirmation.
The visible form alone is not proof a creation request will succeed.
If the action is missing/disabled, resolve the policy or user permission
before proceeding.
Reference: [Create a workspace](https://learn.microsoft.com/en-us/fabric/fundamentals/create-workspaces)
and the [tenant settings index](https://learn.microsoft.com/en-us/fabric/admin/tenant-settings-index).

Your user must become **Admin** of the new workspace. The script verifies
this after creation; it does not silently add other people or grant extra roles.

Next: [Step 09](#step-09-confirm-capacity-access-assignment-rights-and-region).

### Step 09 Confirm capacity access, assignment rights and region

Where to be: local PowerShell 7, with the approved capacity owner's confirmation.

From PowerShell 7:

```powershell
az rest --method get --url https://api.fabric.microsoft.com/v1/capacities --resource https://api.fabric.microsoft.com --query 'value[].{name:displayName,id:id,sku:sku,state:state,region:region}' --output table
```

See/expect: a row for the capacity approved by its owner, with:

* `state` equal to `Active`
* `sku` an F SKU such as `F2` or `F64`
* Its Fabric GUID in `id`
* Its region

An empty list, HTTP 401/403, or missing capacity is a blocker. Ask the capacity
administrator to confirm the capacity and your access. Do not choose a
different customer's capacity to make the command succeed.
The script deliberately accepts F SKUs, not PPU/shared capacity or a
trial-only shortcut, even though Fabric supports other capacity types elsewhere.

Ask the owner to confirm you have **capacity Contributor or capacity Admin**
permission to assign a new workspace to it. This is a Fabric capacity
permission, not Azure subscription Contributor. Being able to list the
capacity does not prove assignment rights. You also need workspace Admin,
which the script verifies after creation.
Reference: [Assign workspace to capacity](https://learn.microsoft.com/en-us/rest/api/fabric/core/workspaces/assign-to-capacity).

Record the capacity's GUID, name, SKU and region. Use that region as the
template's `location`. For example, `Central US` becomes `centralus`,
`West Europe` becomes `westeurope`.
Confirm an unfamiliar region identifier with the owner rather than guessing.
Do not promise that F2 has enough headroom because it is visible and active.

If no capacity is available, stop until an administrator provides one or
explicitly approves the new-capacity option, cost, region and quota at Step 13.

Next: [Step 10](#step-10-confirm-arcgis-geoanalytics-is-enabled).

### Step 10 Confirm ArcGIS GeoAnalytics is enabled

Where to be: Fabric portal with the tenant/capacity administrator, or their request.

Ask the Fabric tenant or capacity administrator to do this:

1. Open [Fabric](https://app.fabric.microsoft.com).
2. For tenant-wide configuration, go to **OneLake catalog > Govern >
   Configurations > Tenant settings**.
3. Find **ArcGIS GeoAnalytics for Fabric Runtime** and enable it for the
   relevant scope.
4. For the selected capacity, go to **OneLake catalog > Govern > Capacities**,
   choose the capacity, then inspect **Delegated tenant settings >
   Integration settings > ArcGIS GeoAnalytics for Fabric Runtime**.
5. Confirm the effective capacity setting does not disable the integration.

See/expect: the administrator confirms it is enabled on the selected capacity.
Use the official
[GeoAnalytics setup page and its setting screenshots](https://learn.microsoft.com/en-us/fabric/data-engineering/spark-arcgis-geoanalytics#enable-arcgis-geoanalytics)
if your tenant has the older **Admin portal** layout.
Do not enable **Use ArcGIS Maps for Power BI** as a substitute; that is a
different feature.

The repo supplies Runtime **1.3** and disables **Native Execution Engine**.
Do not manually install GeoAnalytics using `pip` or choose another runtime
to skip tenant enablement. The included library still needs Esri authorization.

Next: [Step 11](#step-11-obtain-the-correct-esri-entitlement-and-api-key).

### Step 11 Obtain the correct Esri entitlement and API key

Where to be: your approved private channel with the Esri subscription owner.

1. Ask your organization's Esri subscription owner whether it has an active
   **ArcGIS GeoAnalytics for Microsoft Fabric** entitlement.
2. If not, send the owner the
   [Esri Marketplace offering](https://go.esri.com/arcgis-geoanalytics-for-fabric-marketplace)
   and ask them to arrange purchase/evaluation and authorization with Esri.
   Do not accept purchase terms or incur subscription charges without approval.
3. Ask that owner/Esri representative to provide an **API key authorized for
   that active GeoAnalytics for Fabric subscription**, through your organization's
   approved secret-sharing channel.
4. Keep the key in an approved secret manager until the secure Azure field at Step 20.

See/expect: explicit entitlement confirmation and a usable key available to you.
The authoritative authorization requirement is documented at
[Esri GeoAnalytics for Fabric authorization](https://developers.arcgis.com/geoanalytics-fabric/authorization/).

The key-provisioning process depends on your Esri subscription, so ask the
subscription owner for the correct route. A generic basemap/location-services
key, ArcGIS Online login or Azure key will not authorize GeoAnalytics.
If the owner supplies only username/password, ask for the API-key route:
this accelerator supports an API key supplied through secure ARM input, not password-based auth.

Stop here if the entitlement/key is missing. This is an external prerequisite,
not something the Azure foundation creates. Enter the key only in Step 20's
masked secure deployment field, never template code, configuration JSON, Git,
Copilot chat, generated files or notebook content.

Next: [Step 12](#step-12-confirm-networking-costs-and-administrator-approvals).

### Step 12 Confirm networking, costs and administrator approvals

Where to be: your approval conversation with Azure, Fabric and network owners.

Ask your Azure/Fabric/network owners to confirm:

* The private-only Key Vault, dedicated VNet/subnet, private endpoint and DNS
  are permitted. Approved IPv4 ranges do not overlap existing networks.
  Public Key Vault access remains Disabled.
* Your computer can reach Microsoft Entra, Azure management APIs, Fabric APIs
  and raw GitHub content.
* Fabric Spark can reach the vault through its approved managed private endpoint
  and can reach the Esri authorization service.
* Only for optional Step 25, Spark can reach the public ArcGIS census/SVI endpoints, including
  `services.arcgis.com` and `services3.arcgis.com`.
* The selected capacity can run Spark and its owner approves the test workload.
* Azure Key Vault operations, Fabric compute, optional new capacity, and Esri
  licensing costs are approved.
* A dedicated group and globally unique vault name from Step 05 are approved.

See/expect: confirmations from the owners. Provider metadata and capacity
visibility do not prove Azure quota, deny-policy clearance, licensing or
runtime network access. A synthetic run avoids census/SVI reads, but **still
requires the Esri entitlement, GeoAnalytics enablement, and runtime vault access**.

Use this request if you are missing approvals:

> I am testing the Fabric GeoAnalytics deployment accelerator as
> `<my-work-account>` in tenant `<tenant-guid>` and subscription
> `<subscription-guid>`. Please confirm or arrange: subscription deployment
> and dedicated resource-group/Key Vault permissions; vault
> `roleAssignments/write`; KeyVault and Network providers registered (Fabric
> provider only for new capacity); permission for
> my user to create a workspace and Fabric items; workspace assignment to
> `<capacity-name/GUID>` with capacity Contributor/Admin permission; effective
> GeoAnalytics enablement on that capacity; an active Esri GeoAnalytics for
> Fabric entitlement and approved API-key delivery; required Spark/network
> access; and cost/policy approval. Please identify which check is blocked.

Do not include the key in that request.
You may only move to Step 13 when these prerequisites are confirmed.
Allow time for administrator work; this cannot be guaranteed to complete
on the day of the test if approvals are missing.

Next: [Step 13](../02-deploy-azure/manual.md#step-13-load-the-private-template-and-enter-the-azure-parameters).
**This is when you load the private Azure template.**
