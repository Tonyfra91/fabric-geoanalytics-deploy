---
title: Deploy Azure and finish Fabric setup
description: Guided deployment from the Azure button through verified GeoAnalytics outputs.
ms.date: 2026-10-30
---

## 1 Prepare your identity and capacity

Use an interactive Microsoft Entra user in the target tenant. The same user
deploys Azure, finishes Fabric setup, writes the key, and executes the notebook.
Service principals and workspace managed identities are not supported here.

You need:

* PowerShell 7, Git, Azure CLI, and Azure CLI-managed Bicep
* Subscription permissions to deploy the resource group and resources
* `Microsoft.Authorization/roleAssignments/write` at the vault scope
* Registered `Microsoft.KeyVault` and `Microsoft.Fabric` resource providers
* Permission to create a Fabric workspace and assign a supported active F capacity
* Administrator-confirmed GeoAnalytics enablement and an active Esri entitlement
* Network access from Fabric Spark to Key Vault and, for later real-data runs,
  the public ArcGIS census/SVI services

Contributor alone cannot grant the vault role. Tenant administration and
capacity assignment privileges cannot be inferred from successful API reads.
See the [permission details](../deploy/README.md#prerequisites-and-identities).

```powershell
az login --tenant '<tenant-guid>'
az account set --subscription '<subscription-guid>'
az bicep version
az ad signed-in-user show --query id --output tsv
```

Save the displayed user object GUID for the portal's `userObjectId` parameter.
It is not an application/client ID or an email address.

Choose an existing capacity and note its Fabric GUID and region. If permitted:

```powershell
az rest --method get --url https://api.fabric.microsoft.com/v1/capacities --resource https://api.fabric.microsoft.com
```

The selected capacity must be visible to you, active, and an F SKU.
Use its Fabric `id`, not its Azure resource ID.

## 2 Deploy the Azure foundation

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTonyfra91%2Ffabric-geoanalytics-deploy%2Fv0.1.0%2Fdeploy%2Fazuredeploy.json)

Choose the correct subscription in the portal. This is a subscription-scoped
deployment that creates its own resource group.

| Portal parameter | Guidance |
|---|---|
| `deploymentName` | Unique ownership name, 3-41 characters, lowercase letter first, then lowercase letters, numbers, or hyphens; for example `geoanalytics-poc` |
| `location` | Azure region identifier matching the selected capacity, for example `centralus` |
| `resourceGroupName` | New dedicated group, for example `rg-geoanalytics-poc`; do not use a shared/customer group |
| `keyVaultName` | Globally unique 3-24 character vault name; start with a letter; alphanumerics and single hyphens only; end alphanumeric |
| `userObjectId` | GUID from the signed-in-user command above |
| `shouldCreateCapacity` | Leave `false` to reuse an existing capacity |
| `capacityName` | Leave null for existing capacity; for new capacity, use a globally unique lowercase alphanumeric name starting with a letter |
| `capacitySku` | Only used for new capacity; `F2` is the smallest supported choice |
| `capacityAdministrators` | Empty array for existing capacity; for new capacity, an array of administrator UPNs such as `["admin@customer.example"]` |

> [!WARNING]
> The portal deployment does not perform the CLI's ownership/conflict checks.
> Use fresh dedicated names. ARM can update resources with existing names.
> Do not use the button to adopt, retag, or resize customer resources.

Review the resources and pricing before selecting **Create**.
New capacity incurs compute charges until you explicitly manage its lifecycle.
Existing capacity is not resized, suspended, or otherwise managed by this template.
Vault soft-delete and purge protection retain deleted vaults/secrets for 90 days.

Wait for **Deployment succeeded**. Record the subscription deployment's
record name, often `Microsoft.Template-...`. Open its **Outputs** and inspect
`experienceVersion`, `keyVaultUri`, `keyVaultId`, and optional `capacityResourceId`.
No Esri API key is accepted by or returned from the template.

## 3 Initialize the local handoff

```powershell
git clone --branch v0.1.0 https://github.com/Tonyfra91/fabric-geoanalytics-deploy.git
Set-Location .\fabric-geoanalytics-deploy
.\Get-DemoNotebook.ps1
.\Initialize-Experience.ps1 -AzureDeploymentName '<portal-record-name>' -ExistingCapacityId '<fabric-capacity-guid>'
```

If you opted into a new capacity, use:

```powershell
.\Initialize-Experience.ps1 -AzureDeploymentName '<portal-record-name>'
```

Initialization performs Azure reads only. It requires a successful deployment,
the expected handoff contract, vault outputs matching the parameters and
subscription, and the same user as `userObjectId`. It creates
`deploy\config\customer.json` without overwriting an existing file.
It does not approve prerequisites, retrieve the key, or create Fabric resources.

Review workspace, Lakehouse, environment, and notebook names in that local file.
After obtaining each approval, set the corresponding `confirmations` boolean
to `true`. Never put a key, token, or password in this file.

```powershell
.\deploy.ps1 validate
```

Exit `0` means automated checks passed and approvals were supplied.
Exit `1` means failure. Exit `2` means manual approvals remain outstanding.
Resolve failures before proceeding; do not bypass ownership or access checks.

## 4 Finish Fabric setup

```powershell
.\deploy.ps1 deploy -AzureDeploymentName '<portal-record-name>'
.\deploy.ps1 status
```

The finish command verifies the Azure deployment against your configuration,
then reuses its outputs. It does not submit another Azure create deployment.
It creates/reuses only matching deployment-owned Fabric items:

1. Dedicated workspace assigned to the selected capacity
2. Lakehouse
3. Published environment using Runtime 1.3 with Native Execution Engine disabled
4. Generated notebook with workspace/Lakehouse/environment bindings

No notebook executes during this step. Nonsecret milestones are checkpointed
in `deploy\state\<deploymentName>.json`.
On failure, inspect Azure/Fabric activity and the manifest before rerunning
the same finish command. Keep one deployment process per ownership name.
Repeat setup republishes the environment and replaces custom edits to the
deployment-owned notebook.

## 5 Configure the Esri key

```powershell
.\deploy.ps1 configure-secret
```

Enter your Esri GeoAnalytics API key at the hidden prompt.
It is written to Key Vault as `geoanalytics-api-key`, never supplied as a
command-line argument or stored in repository configuration.
Wait for vault RBAC propagation if access is initially denied.

The notebook retrieves the key under the executing user's runtime identity.
Deployment identity access is not sufficient proof of runtime access.

## 6 Prove the small synthetic workload

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json
.\deploy.ps1 status
```

The run first submits a runtime authorization probe. Only after that succeeds
does it submit the simulation with two days, a 10 km radius, H3 resolution 6,
synthetic population, and seed 42. It creates a unique run ID.

The six Delta output suffixes are `cells_daily`, `arrival`, `front_daily`,
`grid_population_vulnerability`, `origin`, and `vulnerability_summary`. See the
[exact table naming and output contract](../deploy/README.md#run-and-explore-fabric-results).
Geometry is stored as WKT in EPSG:4326, not as a claim of native SQL spatial types.
Status records output table names and read-back row counts.

Inspect the Lakehouse tables and the receipt under
`Files/zombie_outbreak/run_id=<RUN_ID>`.
Inspect SQL analytics endpoint visibility separately; synchronization can lag.
Job completion alone is not proof of valid outputs.

## Acceptance checklist

Record live evidence in your customer-controlled deployment records.
Never publish keys, bearer tokens, personal data, or customer resource identifiers
as repository issues.

* Azure deployment succeeds with expected vault outputs and user RBAC.
* Validation passes with all five approvals genuinely obtained.
* Fabric status verifies item bindings and published environment settings.
* Runtime authorization and Key Vault retrieval succeed.
* The small synthetic run returns six outputs with readable Delta tables and counts.
* Lakehouse tables become visible through the SQL analytics endpoint.
* Repeat finish setup reuses owned items without adopting unrelated resources.
* A real-population US run validates external source/schema compatibility before scale-up.

Offline tests establish behavior under mocks, not this live acceptance evidence.

## Alternate path without the button

Copy the sample configuration and fill in the same nonsecret values and approvals:

```powershell
Copy-Item .\deploy\config\customer.sample.json .\deploy\config\customer.json
.\Get-DemoNotebook.ps1
.\deploy.ps1 validate
.\deploy.ps1 deploy -WhatIf
.\deploy.ps1 deploy
```

This path performs the Azure deployment through Bicep before finishing Fabric.
ARM what-if does not preview Fabric API mutations.

## Cleanup and troubleshooting

Automatic deletion is intentionally unavailable. Review ownership and delete
only the dedicated POC resources manually. Do not delete or change existing
capacity or unrelated workspaces. Purge protection prevents immediate vault
name reuse.

For failed publications, authentication errors, runtime denial, partial output
writes, or missing SQL tables, use the
[operations reference](../deploy/README.md#removal-and-troubleshooting).
Continue with [architecture and next steps](./architecture.md) after acceptance.
