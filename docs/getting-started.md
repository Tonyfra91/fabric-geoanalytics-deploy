---
title: Deploy Azure and finish Fabric setup
description: A numbered first-test walkthrough with every prerequisite, manual approval, screen, command, expected result, and next action.
ms.date: 2026-10-31
---

## Before you begin

Follow this page from top to bottom. Do not run the README's quick commands
out of order. The primary path uses Windows, PowerShell 7, and an existing
active Fabric F capacity. An optional new-capacity path is included at Step 13.
You do not need to be an Azure administrator to follow the steps, but you
must receive the required permissions and approvals from the appropriate
administrator. This repo cannot grant you access you do not have.

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

UI labels below follow the linked Microsoft/Esri guidance checked on
2026-10-31. Your tenant may have an older navigation layout. If a named page
is unavailable, use the documented alternative or ask the named owner;
do not substitute a similarly named setting. Expected examples below are not
screenshots or evidence of a completed live deployment.

### What this test reproduces

The accelerator retains the pinned upstream demo's spatial simulation logic:
Atlanta origin, H3 grid, neighborhood graph, daily spread, and, in Step 25,
US census/SVI enrichment. It starts smaller than the source demo so you can
verify setup before spending more compute.

It does **not** reproduce Sean's optional ArcGIS Online/Enterprise publishing,
GeoParquet-only output presentation, or original inline map. It generates six
Delta tables with WKT geometry and a verification receipt instead. No Power BI
report, semantic model, dashboard, or hosted map is deployed.
You will inspect the spatial-model results through Fabric tables and SQL.
The fictional model is a teaching exercise, not an outbreak forecast.
See [demo provenance](./demo-provenance.md) for the source and adapter boundaries.

### Record your nonsecret test values

Keep a private local note. Fill each value when its step supplies it.
Never record the Esri key in this table, Git, screenshots, or shared notes.

| Value to record | Where you get it | Used in |
|---|---|---|
| Deployment user's work/school email | Your account owner | Both portals and CLI sign-in |
| Tenant GUID | Azure subscription's directory; Step 03 CLI output | Azure CLI login and configuration |
| Subscription GUID and name | Azure portal Subscriptions; Step 03 | CLI and blue-button subscription selector |
| Deployment user's object GUID | `az ad signed-in-user show`; Step 03 | Portal `userObjectId` |
| Fabric capacity GUID, name, SKU and region | Step 09 capacity read | Initialization and region choice |
| Ownership name | Choose at Step 05 | Template `deploymentName` |
| Dedicated resource group name | Choose at Step 05 | Template `resourceGroupName` |
| Globally unique vault name | Choose at Step 05 | Template `keyVaultName` |
| Portal deployment record name | Azure deployment page; Step 14 | `-AzureDeploymentName` |
| Workspace, Lakehouse, environment and notebook names | Generated configuration; Step 16 | Finding the created Fabric items |
| Run ID and six table names | Run output/manifest; Step 23 | Lakehouse and SQL verification |

The portal deployment record name is **not** the template's ownership name.
Do not interchange them.

## 1 Prepare your identity and capacity

### Step 01 Install and verify the tools

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

| Tool | Official instructions | Why you need it |
|---|---|---|
| PowerShell 7 | [Install PowerShell on Windows](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) | All accelerator commands require version 7 or later |
| Git | [Git for Windows](https://git-scm.com/downloads/win) | Download this repository |
| Azure CLI | [Install Azure CLI on Windows](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows) | Azure sign-in, deployment reads, and Fabric authentication |
| Bicep 0.48.1 | [Install Bicep with Azure CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli) | Local validation and template freshness check |
| Python 3.12 | [Python downloads](https://www.python.org/downloads/windows/) | Offline notebook syntax/output-contract tests; not a local Spark installation |

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

Next: Step 02. Keep this PowerShell 7 window open for the remaining commands.

### Step 02 Get the repository and pinned demo

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
Use `main` to obtain this updated walkthrough and its real-run configuration;
the blue button still pins the unchanged `v0.1.0` Azure template.

Run the offline checks:

```powershell
.\deploy\tests\Test-Accelerator.ps1
.\deploy\tests\Test-Experience.ps1
.\deploy\scripts\Build-Template.ps1 -Check
```

See/expect: `Offline checks passed: 39`, `Experience checks passed: 22`,
the portal/documentation contract PASS message, and
`Portal template matches Bicep source.` These tests use cloud mocks;
they do not certify your permissions or tenant.

If PowerShell says a script is blocked because it came from the Internet,
review the repo scripts and ask IT about your organization's script policy.
Where permitted, `Unblock-File` on the reviewed script removes its download
mark. Do not disable organization-enforced execution policy.
If the source download is blocked, ask for an authorized copy and use the
[local-source option](./demo-provenance.md#local-retrieval-and-integrity).

Next: Step 03. Run all subsequent repo commands from this folder.

### Step 03 Choose the user, tenant and Azure subscription

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

Next: Step 04.

### Step 04 Confirm Azure deployment and role-assignment permissions

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
the prerequisite section. The blue button will not repair missing permissions.

Next: Step 05.

### Step 05 Confirm providers and choose fresh Azure names

In PowerShell:

```powershell
az provider show --namespace Microsoft.KeyVault --query registrationState --output tsv
az provider show --namespace Microsoft.Fabric --query registrationState --output tsv
```

See/expect: each prints `Registered`. If not, ask the Azure administrator to
open **Subscriptions > your subscription > Resource providers**, search each
namespace, and register it. The repo's validator does not register providers.
Wait until both commands print `Registered`.

Choose these names and record them:

| Value | Allowed form | Example to adapt, not reuse blindly |
|---|---|---|
| Ownership `deploymentName` | 3-41 characters; lowercase letter first, then lowercase letters, numbers or hyphens | `geo-atlanta-youralias-01` |
| `resourceGroupName` | Letters, numbers, underscore or hyphen; maximum 90 characters | `rg-geo-atlanta-youralias-01` |
| `keyVaultName` | Globally unique, 3-24 characters; letter first; alphanumerics/single hyphens; alphanumeric last | `kv-geo-youralias-01` |

Check the group and vault before the button:

```powershell
az group exists --name '<your-new-resource-group-name>' --output tsv
az keyvault check-name --name '<your-new-vault-name>' --query '{available:nameAvailable,reason:reason,message:message}' --output json
```

See/expect: group result `false`, and vault result `"available": true`.
If either name is already in use, choose a different name and check again.
Do not retag an existing resource or put the deployment in a shared group.
The portal button does not run the repo's ownership/conflict validator
before deployment, and ARM can update existing named resources.

Next: Step 06.

### Step 06 Sign into Fabric and verify your account

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

Next: Step 07. Leave Fabric open; you return here after automated setup.

### Step 07 Confirm permission to create Fabric items

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

Next: Step 08.

### Step 08 Confirm permission to create the dedicated workspace

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

Next: Step 09.

### Step 09 Confirm capacity access, assignment rights and region

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

Next: Step 10.

### Step 10 Confirm ArcGIS GeoAnalytics is enabled

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

Next: Step 11.

### Step 11 Obtain the correct Esri entitlement and API key

1. Ask your organization's Esri subscription owner whether it has an active
   **ArcGIS GeoAnalytics for Microsoft Fabric** entitlement.
2. If not, send the owner the
   [Esri Marketplace offering](https://go.esri.com/arcgis-geoanalytics-for-fabric-marketplace)
   and ask them to arrange purchase/evaluation and authorization with Esri.
   Do not accept purchase terms or incur subscription charges without approval.
3. Ask that owner/Esri representative to provide an **API key authorized for
   that active GeoAnalytics for Fabric subscription**, through your organization's
   approved secret-sharing channel.
4. Keep the key in an approved secret manager until the hidden prompt at Step 20.

See/expect: explicit entitlement confirmation and a usable key available to you.
The authoritative authorization requirement is documented at
[Esri GeoAnalytics for Fabric authorization](https://developers.arcgis.com/geoanalytics-fabric/authorization/).

There is no verified universal self-service “generate key” screen documented
by this repo for every Esri entitlement path. Do not guess an ArcGIS Online
or ArcGIS developer API-key screen. A generic basemap/location-services key,
ArcGIS Online login, or Azure key is not proof of GeoAnalytics authorization.
If the owner supplies only username/password, ask for the API-key route:
this accelerator supports a hidden API-key prompt, not password-based auth.

Stop here if the entitlement/key is missing. This is an external prerequisite,
not something the Azure button creates. No secret should be pasted into the
portal template, configuration JSON, Git, or a notebook cell.

Next: Step 12.

### Step 12 Confirm networking, costs and administrator approvals

Ask your Azure/Fabric/network owners to confirm:

* Public-network Key Vault is permitted for this POC. The template enables
  public access with RBAC; it does not deploy private endpoints or a VNet.
* Your computer can reach Microsoft Entra, Azure APIs, Fabric APIs, Key Vault
  and raw GitHub content.
* Fabric Spark can reach the vault and the Esri authorization service.
* For Step 25, Spark can reach the public ArcGIS census/SVI endpoints, including
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
> `roleAssignments/write`; both resource providers registered; permission for
> my user to create a workspace and Fabric items; workspace assignment to
> `<capacity-name/GUID>` with capacity Contributor/Admin permission; effective
> GeoAnalytics enablement on that capacity; an active Esri GeoAnalytics for
> Fabric entitlement and approved API-key delivery; required Spark/network
> access; and cost/policy approval. Please identify which check is blocked.

Do not include the key in that request.
You may only move to Step 13 when these prerequisites are confirmed.
Allow time for administrator work; this cannot be guaranteed to complete
on the day of the test if approvals are missing.

Next: Step 13. **This is when you press the blue button.**

## 2 Deploy the Azure foundation

### Step 13 Press the blue button and enter the Azure parameters

Why now: your access, names, capacity, licensing and network approvals are
confirmed. The button creates the Azure foundation, not the spatial results.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTonyfra91%2Ffabric-geoanalytics-deploy%2Fv0.1.0%2Fdeploy%2Fazuredeploy.json)

1. Select **Deploy to Azure** above or on the README.
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

| Template field | Enter/select this for the existing-capacity path |
|---|---|
| `deploymentName` | Your approved ownership name from Step 05 |
| `location` | Azure region identifier matching the capacity from Step 09 |
| `resourceGroupName` | Fresh dedicated group name from Step 05 |
| `keyVaultName` | Available globally unique vault name from Step 05 |
| `userObjectId` | The GUID from Step 03 `az ad signed-in-user show` |
| `shouldCreateCapacity` | `false` |
| `capacityName` | Leave the optional value null/unset; do not type an existing capacity's name |
| `capacitySku` | Leave default `F2`; ignored when `shouldCreateCapacity=false` |
| `capacityAdministrators` | Leave the empty JSON array `[]`; do not enter the Esri key here |

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

If review/deployment reports invalid parameters, permissions, policy, name
conflicts or quota, stop and inspect the error. Do not repeatedly click Create
or select unrelated existing resources to get past it.

Next: Step 14. Stay in Azure until deployment has succeeded.

### Step 14 Record Azure success and the handoff outputs

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
original notebook or create a Lakehouse. Return to PowerShell for Step 15.

## 3 Initialize the local handoff

### Step 15 Generate the nonsecret local configuration

Make sure PowerShell is still in the cloned repository folder:

```powershell
Get-Location
Test-Path .\Initialize-Experience.ps1
```

Expect `True` from the second command.
For the existing-capacity path:

```powershell
.\Initialize-Experience.ps1 -AzureDeploymentName '<portal-deployment-record-name>' -ExistingCapacityId '<fabric-capacity-guid>'
```

For the approved new-capacity path, omit the existing GUID:

```powershell
.\Initialize-Experience.ps1 -AzureDeploymentName '<portal-deployment-record-name>'
```

See/expect: `Created ...customer.json. Review all administrator confirmations
before running validate.` It reads Azure state and creates a local file only.
All five approval flags start as `false`.
It verifies successful Azure state, handoff version, signed-in user, and vault
outputs. It does not overwrite existing configuration or create Fabric items.

If it says configuration already exists, inspect it at Step 16. Do not delete
it reflexively. For a separate approved test, use a separate clone/config path,
and supply that `-ConfigPath` to every subsequent command.
If it reports user/tenant/output mismatch, correct the sign-in or deployment
record; do not edit IDs to evade the check.

Next: Step 16.

### Step 16 Review names and enter the five genuine confirmations

Open the generated local file:

```powershell
notepad .\deploy\config\customer.json
```

See/expect: JSON containing subscription/tenant GUIDs, Azure names, Fabric item
names, a `capacity` object, and the following `confirmations` object.
Compare the GUIDs/Azure names to your note. Keep the derived values unless
you have reviewed a deliberate change.

For ownership name `geo-atlanta-youralias-01`, generated names are:

| JSON field | Expected generated name |
|---|---|
| `workspaceName` | `geo-atlanta-youralias-01 GeoAnalytics` |
| `lakehouseName` | `Geo_geo_atlanta_youralias_01` |
| `environmentName` | `geo-atlanta-youralias-01 Runtime 1.3` |
| `notebookName` | `geo-atlanta-youralias-01 Demo` |

Record your actual four names. Names change with your ownership name.
Use fresh names; unowned existing workspaces/items cannot be adopted.

Change each flag to `true` **only** when its preceding approval was obtained:

| Confirmation field | What must actually be confirmed |
|---|---|
| `geoAnalyticsEnabled` | Step 10 effective tenant/capacity integration setting |
| `esriEntitlement` | Step 11 active entitlement and the correct API key available |
| `workspaceCreationAllowed` | Steps 07-08 your user's allowed workspace/item creation |
| `capacityAssignmentAllowed` | Step 09 capacity assignment rights for your user |
| `azureDeploymentAllowed` | Steps 04 and 12 deployment, RBAC, policy and cost approval |

After those confirmations, this part of the file is:

```json
"confirmations": {
  "geoAnalyticsEnabled": true,
  "esriEntitlement": true,
  "workspaceCreationAllowed": true,
  "capacityAssignmentAllowed": true,
  "azureDeploymentAllowed": true
}
```

Use JSON booleans `true`, not strings `"true"`. Keep commas between properties;
do not add a trailing comma after the last property. Do not paste the Esri key
anywhere into this file. Save with **File > Save**, then close Notepad.

Next: Step 17.

### Step 17 Run prerequisite validation and read the result

```powershell
.\deploy.ps1 validate
$LASTEXITCODE
```

See/expect: a table with columns `Check`, `Status`, `Detail`. Automated checks
should show `Pass`; the five approvals should show `Confirmed`.
The exit code must be `0` before continuing.

| Exit/result | Do this |
|---|---|
| `0` | Continue to Step 18 |
| `2` or `Manual` rows | Return to Steps 04-12; obtain missing approvals, then update only their flags |
| `1` or `Fail` rows | Read that row's detail; resolve the named tool, sign-in, provider, region, capacity, ownership or API-access problem |
| JSON parse error | Reopen `customer.json`, fix JSON syntax, and rerun |
| Azure/Fabric 401/403 or consent-required error | Ask identity/Fabric administrator to approve the interactive CLI access; do not enable service-principal settings as a workaround |

Validation is read-only: it neither provisions resources nor starts Spark.
It cannot conclusively verify all policies, permissions, entitlement or
capacity headroom through reads alone.

Next: Step 18 only after exit `0`.

## 4 Finish Fabric setup

### Step 18 Run the Fabric finish command and wait

```powershell
.\deploy.ps1 deploy -AzureDeploymentName '<portal-deployment-record-name>'
$LASTEXITCODE
```

Why this command: it verifies the existing Azure handoff and performs the
Fabric REST setup that the blue button cannot do.
Do **not** substitute bare `.\deploy.ps1 deploy` here; bare deploy is the
alternative path that submits Azure provisioning again.

See/expect:

1. Prerequisite table passes again.
2. Workspace is created/reused only if deployment ownership matches.
3. Capacity assignment completes.
4. Lakehouse and environment are created.
5. Messages such as `[Environment publication] Running` appear while the
   environment publishes. Wait for completion; do not start another process.
6. Notebook is created/imported and its bindings are checked.
7. Final success text:

```text
Deployment configured. No notebook was executed. Next: .\deploy.ps1 configure-secret
```

The exit code must be `0`. Publication can take several minutes; the script
allows up to 30 minutes for its environment-publication polling.
There is no guarantee of a fixed duration in your tenant.

If it fails, record the exact error and inspect the relevant Azure/Fabric
activity. State under `deploy\state` is checkpointed; do not edit/delete it
to bypass ownership checks. Resolve the cause, then rerun the **same finish
command**, not the blue button. No automatic rollback occurs.

Next: Step 19. Now return to the Fabric browser tab.

### Step 19 Open Fabric and inspect what was created

1. Open [Fabric](https://app.fabric.microsoft.com) and confirm the Step 03 user.
2. Select **Workspaces**, find your recorded `workspaceName`, and open it.
   If it is not visible, refresh the page and verify your account/tenant.
3. Expect items with the recorded names and types **Lakehouse**,
   **Environment**, and **Notebook**. A SQL analytics endpoint with the
   Lakehouse name may also appear automatically; it is not another manually
   deployed workload.
4. Open the Environment item. Inspect its compute/runtime configuration:
   **Runtime 1.3**, Native Execution Engine disabled, or Spark property
   `spark.native.enabled=false`, and publication completed.
5. Return to the workspace and open the Notebook item.
   If the Fabric code-review/security warning is shown, review the source
   before acknowledging it.
6. Check the attached Lakehouse in the notebook explorer and environment
   selection against your recorded names. **Do not select Run all.**

Back in PowerShell:

```powershell
.\deploy.ps1 status
$LASTEXITCODE
```

See/expect: JSON containing `"stage": "Configured"`, the item names/IDs,
`"runtimeVersion": "1.3"`, and `"notebookBindingsVerified": true`.
There is no `lastVerifiedOutputs` yet on a fresh deployment because you have
not run the workload.

Status is the definitive repo check of the deployed runtime and bindings,
even if your UI places the environment settings under a different tab.
If it fails, resolve the error before secret setup/run.
Do not manually create duplicate items, import the original notebook, or
edit the generated workload to insert secrets.

Next: Step 20. Leave the workspace browser tab open.

## 5 Configure the Esri key

### Step 20 Enter the key at the hidden PowerShell prompt

In the local terminal, not Azure/Fabric browser:

```powershell
.\deploy.ps1 configure-secret
```

See this exact prompt:

```text
Esri GeoAnalytics API key (hidden):
```

Paste the authorized Step 11 key at that prompt and press **Enter**.
The input is masked; it must not be echoed as plain text.
Do not put the key after the command, in a screenshot, or into a notebook cell.

See/expect:

```text
Secret stored; metadata access verified for the interactive user. Runtime access is checked during run.
```

The secret's name is `geoanalytics-api-key` in your deployed vault.
For a manual metadata check, Azure portal search **Key vaults > your vault >
Objects > Secrets**. Expect that name. Do not open/show/copy its secret value
for evidence. If browsing metadata is denied, inspect the error and RBAC.

A vault 403 can indicate role propagation, an inactive role, or network/policy
denial. Have the Azure owner inspect **vault > Access control (IAM)** and
network settings; rerun after the cause is resolved. Do not grant broad roles
or disable policy to suppress the error.
A successful secret write does not prove Spark can retrieve it.

Next: Step 21.

## 6 Prove the small synthetic workload

### Step 21 Submit the first run from PowerShell

Review the supplied file:

```powershell
Get-Content .\deploy\config\smoke-run.json
```

See/expect: `SIM_DAYS: 2`, `STUDY_RADIUS_KM: 10`, `H3_RESOLUTION: 6`,
`USE_REAL_POPULATION: false`, seed `42`, prefix `zombie`, and overwrite disabled.
The notebook's pinned origin defaults to Atlanta.

Now run:

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json
$LASTEXITCODE
```

Do not close this terminal while the command runs.
It checks deployed state/secret metadata, submits an authorization-only
preflight job, then submits the simulation only if preflight passes.
It does not need you to select **Run all** in the browser.

See/expect: `Submitted notebook job: ...`, polling statuses such as
`[Notebook job ...] InProgress`, and `Completed`.
There are normally **two submitted jobs**: preflight, then simulation.
If the first fails, the second is not submitted.
The preflight returns `{"preflight":"passed"}` internally; the command does
not promise to print that JSON separately.

On success, the terminal prints JSON with `run_id` and six `outputs`, then
the workspace URL and item/job IDs. The exit code must be `0`.
Polling allows up to two hours per job; a timeout does not cancel a running job.
Do not resubmit while the first command/job may still be active.

Next: Step 22 while it runs, then Step 23 after exit `0`.

### Step 22 Watch the two jobs in Fabric

1. In your Fabric workspace, find the deployed Notebook item.
2. Use its **More options (...) > Recent runs** action, where available,
   or open **Monitor** / the monitoring hub and filter to your workspace
   and notebook.
3. Open the newest notebook run to inspect status and execution details.
4. Expect the authorization run followed by the simulation run. The preflight
   is shorter in workload scope, but Spark startup can still take time.

The terminal's submitted job ID and timestamp identify the run; use them
to avoid confusing it with another user's activity.
The browser need not remain open for the terminal-submitted job to run.
Reference: [Recent runs and monitoring navigation](https://learn.microsoft.com/en-us/fabric/data-engineering/apache-spark-monitor-run-series#access-the-monitor-run-series-feature).

If a job fails, open its run details and find the error. Common stop points:

| Error or symptom | Owner/action |
|---|---|
| GeoAnalytics module unavailable | Fabric owner checks Step 10 effective setting and Runtime 1.3 |
| `Cannot retrieve geoanalytics-api-key` | Azure/network owner checks executing user's vault Get access, secret existence and Spark networking |
| `GeoAnalytics authorization failed` / not authorized | Esri owner verifies the subscription/key; do not replace it with a generic ArcGIS key |
| Spark cannot start / capacity unavailable | Capacity owner checks active state, workloads, headroom and access |
| Completed job but missing exit value | Inspect run details; beta exit-value retrieval is a documented accelerator limitation |
| Command timeout | Check current job status before rerunning; it may still be active |

Next: Step 23 only after terminal success, not merely a green browser job.

### Step 23 Open the six tables and OneLake receipt

In PowerShell:

```powershell
.\deploy.ps1 status
$Config = Get-Content .\deploy\config\customer.json -Raw | ConvertFrom-Json
$Manifest = Get-Content ".\deploy\state\$($Config.deploymentName).json" -Raw | ConvertFrom-Json
$Manifest.lastResult.run_id
$Manifest.lastResult.outputs | ConvertTo-Json -Depth 10
```

See/expect: `lastVerifiedOutputs` in status, a run ID, and these exact output
suffixes with full table names and `rows` counts:

| Suffix | What to inspect |
|---|---|
| `cells_daily` | Daily cell state; must be nonempty |
| `arrival` | First infested day and peak zombies for reached cells |
| `front_daily` | Daily spread footprint/hull/center/reach/speed |
| `grid_population_vulnerability` | H3 grid and population/vulnerability attributes; must be nonempty |
| `origin` | Scenario origin; must be nonempty |
| `vulnerability_summary` | Quintile summary; can be empty for synthetic population |

Table names follow `zombie_<run_id>_<suffix>` in lowercase.
Copy the **actual names printed above**, not this placeholder.
The receipt contains Spark read-back counts; do not expect a prescribed numeric
count for every output or bit-identical results across runtime partitions.

In Fabric:

1. Open your workspace and select the **Lakehouse** item, not the similarly
   named SQL analytics endpoint yet.
2. In its explorer, expand **Tables**. If schemas are shown, expand the schema
   containing the printed table names (normally `dbo` for this default path).
3. Refresh the table list if necessary. Select each printed table name.
   Expect its preview grid with columns/rows corresponding to the output above.
4. Geometry columns are `*_wkt` text with `geometry_srid=4326`.
   WKT is not an automatically rendered map or a native SQL spatial type.
5. Expand **Files > zombie_outbreak > run_id=<your run ID>**.
6. Select `result.json` and use its file preview. If preview is unavailable,
   download that nonsecret receipt and open it locally.

Expect a receipt containing the same run ID, six table names, and row counts.
If `Tables` are absent but the job is green, do not declare success; compare
the run ID, Lakehouse binding, run details and manifest before proceeding.
Some outputs may validly have zero rows, but required origin/grid/daily-state
outputs cannot be empty for a verified run.

Next: Step 24.

### Step 24 Verify the SQL analytics endpoint

1. Return to the workspace item list.
2. Select the **SQL analytics endpoint** item with the same name as your
   Lakehouse. Alternatively, in the Lakehouse top-right ribbon dropdown,
   switch to **SQL analytics endpoint**.
3. Expect a SQL query editor and explorer with schemas/tables.
4. Refresh the explorer and find the six actual table names from Step 23.
   Note the schema shown alongside them; use it in your queries.
5. Select **New SQL query** and paste the following, replacing both
   angle-bracket placeholders with the actual schema and arrival table name.
6. Select **Run** in the query editor.

```sql
SELECT TOP (20) *
FROM [<schema-shown-in-explorer>].[<actual-arrival-table-name>];
```

Expect a row grid for reached cells with the arrival attributes and WKT geometry.
Repeat for `origin` or `cells_daily` and check a row count:

```sql
SELECT COUNT_BIG(*) AS row_count
FROM [<schema-shown-in-explorer>].[<actual-cells-daily-table-name>];
```

Expect the count to match the corresponding Spark count in `result.json`.
If tables are not visible yet, refresh and wait for metadata synchronization;
there is no guaranteed synchronization duration. If they remain absent,
inspect schema/table registration and the
[SQL endpoint guidance](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-sql-analytics-endpoint).
Do not repeatedly rerun the simulation to force SQL synchronization.

This endpoint is read-only over the Lakehouse Delta data. You do not need to
create an Azure SQL database or install a SQL client for this browser test.

Next: Step 25 after the synthetic run and read-back checks are successful.

### Step 25 Run the small Atlanta real-population scenario

This step exercises the upstream demo's external census/SVI enrichment.
It requires the Step 12 public-source network approvals. It is not required
to prove that the synthetic setup worked.

Review the supplied file:

```powershell
Get-Content .\deploy\config\real-run.json
```

See/expect: explicit Atlanta coordinates `33.7490, -84.3880`,
`USE_REAL_POPULATION: true`, three days, 10 km radius, H3 resolution 6,
seed `42`, and overwrite disabled.

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\real-run.json
.\deploy.ps1 status
```

Expect a new preflight/simulation pair and a **new run ID** with six output
tables. Repeat Steps 22-24 using the new names. Compare the grid's enriched
population/vulnerability attributes and the vulnerability summary.
US origins are required for these sources. An external source/schema error
must be investigated; do not silently switch to synthetic inputs and call the
real-data test passed.

The upstream defaults were 30 days, 150 km and H3 resolution 7.
Do not jump to that workload on an unmeasured capacity. The provided run uses
the same model with bounded inputs, not a claim of identical output extent,
row counts, map rendering or runtime.
See [architecture and next experiments](./architecture.md).

## Acceptance checklist

Before calling the first test complete, record:

* [ ] Steps 04-12 approvals came from the correct owners, not inferred from login.
* [ ] Azure deployment succeeded and its outputs match the approved subscription/user.
* [ ] `validate` exits `0`.
* [ ] Fabric finish exits `0` and did not require another Azure deployment.
* [ ] Fabric workspace contains the expected Lakehouse, environment and notebook.
* [ ] Status verifies Runtime 1.3 and notebook bindings.
* [ ] Secret is stored without exposing its value.
* [ ] Preflight and synthetic simulation succeed with verified exit/output contracts.
* [ ] Six output tables and `result.json` are readable with required nonempty outputs.
* [ ] SQL table previews/counts match the Spark receipt.
* [ ] If claiming real-source replication, Step 25 enrichment also succeeds.

Store evidence in your customer-controlled records. Do not post API keys,
bearer tokens, personal data or customer resource identifiers to public issues.
Offline tests and this walkthrough are not live acceptance evidence.

For repeat setup, rerun the same finish command after inspecting ownership/state.
It reuses owned items but republishes the environment and updates the generated
notebook, potentially replacing custom edits. Do not redeploy solely to inspect results.

## Alternate path without the button

This is for operators who deliberately choose CLI-only Azure provisioning.
It is not the next command after a successful blue-button deployment.

```powershell
Copy-Item .\deploy\config\customer.sample.json .\deploy\config\customer.json
notepad .\deploy\config\customer.json
```

Fill all names/GUIDs/capacity fields and genuine confirmations using the
prerequisite steps above, then:

```powershell
.\Get-DemoNotebook.ps1
.\deploy.ps1 validate
.\deploy.ps1 deploy -WhatIf
.\deploy.ps1 deploy
```

ARM what-if does not preview Fabric mutations. Continue at Step 19 only after
deployment succeeds.

## Cleanup and troubleshooting

Automatic `remove` is intentionally unavailable. Do not expect resource cleanup
to happen when you close the browser, stop a terminal, or delete a local clone.

1. Record the deployed ownership name, group and item names from configuration/manifest.
2. Ask the resource owners to review the deployment tags/descriptions and confirm
   which resources belong exclusively to this POC.
3. If authorized, delete the dedicated Fabric workspace through its settings/
   More options deletion action. Confirm the workspace name before confirming deletion.
4. In Azure portal, open **Resource groups > the dedicated POC group**.
   Review every resource, then use **Delete resource group** only if the owner
   confirms they are all disposable POC resources. Read and complete Azure's
   name-confirmation prompt.
5. Never delete, resize or suspend a reused customer capacity. If a new capacity
   was created in the dedicated group, include its cost/lifecycle in the owner's cleanup review.

Key Vault soft-delete/purge protection retains deleted vaults/secrets for
90 days; immediate vault-name reuse is not guaranteed. You may need another
globally unique name for the next test.
These deletion actions are destructive and require separate owner approval.

For detailed errors and partial failures, see the
[operations troubleshooting table](../deploy/README.md#removal-and-troubleshooting).
For a public issue, provide a redacted error, command/stage, and tool versions,
not credentials or unredacted tenant/resource data.
