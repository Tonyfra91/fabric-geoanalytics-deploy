---
title: Deployment operations reference
description: Bicep-led deployment automation for Azure and Microsoft Fabric resources.
ms.date: 2026-10-30
---

## Status and architecture

First-time users should begin at [01 Start here](../01-start-here/README.md).
This folder contains deployment implementation and the operations reference,
not the first stage of the reading journey.
This reference also covers the alternative CLI-only deployment.
Obtain the pinned upstream notebook locally with `.\Get-DemoNotebook.ps1` first.

Bicep-led deployment automation for Azure and Microsoft Fabric resources.
This is an interactive-user POC, not a production-certified accelerator.
Deployment and simulation execution are separate operations.

```text
PowerShell entry point
  validate          Read-only Azure/Fabric checks and manual confirmations
  deploy -WhatIf    ARM preview only; no Fabric mutations
  deploy            Subscription Bicep -> resource group, Key Vault, vault RBAC
                    Optional new capacity, only with capacity.mode = new
                    Fabric REST -> workspace, capacity assignment, Lakehouse,
                                   published environment, notebook
  configure-secret  Hidden prompt -> Key Vault geoanalytics-api-key
  run               Runtime authorization probe -> parameterized simulation
                    -> six Delta tables and a nonsecret OneLake result receipt
  status            Read item metadata, environment settings, and last job
```

Bicep does not directly manage Fabric workspace items. Fabric REST APIs do.
No ArcGIS publication is present in the generated workload.
The [upstream notebook](https://github.com/SeanKMcG/fabric_zombie_outbreak) remains unchanged,
including its original optional publishing code. Only the generated notebook
is deployed.

## Prerequisites and identities

Use PowerShell 7, Azure CLI with `az bicep`, and an interactive Microsoft Entra
user signed in to the correct tenant and subscription:

```powershell
az login
az account set --subscription '<subscription-guid>'
az bicep version
```

The same user performs Azure deployment, Fabric API calls, secret creation,
notebook execution, and runtime Key Vault retrieval. No managed identity or
service principal is created: neither is needed for this user-driven POC.
Service-principal execution and Fabric workspace identities are not implemented
or validated. A managed identity does not implicitly have Fabric access.

Required permissions and prerequisites:

* Deploy resource groups and resources at the Azure subscription/target scope.
* Create role assignments at the vault scope (for example, an appropriately
  scoped Owner or Contributor plus Role Based Access Control Administrator).
  Contributor alone cannot grant the vault role.
* Register `Microsoft.KeyVault` and `Microsoft.Fabric` before validation.
  The scripts never register providers automatically.
* Have Fabric enabled and permission to create a workspace.
* Have workspace Admin and capacity Contributor or capacity Admin permission
  for workspace capacity assignment.
* Have an active supported F capacity in the configured region.
* Have an administrator enable ArcGIS GeoAnalytics for Fabric Runtime for the
  tenant or selected capacity.
* Hold an active Esri GeoAnalytics entitlement and valid API key.
* Allow Fabric Spark outbound access to Key Vault and the public ArcGIS census
  and SVI services when using real population.

Validation cannot conclusively prove workspace-creation policy, capacity
assignment rights, Esri entitlement, tenant enablement, effective Azure
deployment privileges under all policy/deny conditions, or capacity headroom
without mutation/execution. Those checks remain explicit customer/admin
confirmations. Reading a capacity is not proof of permission to assign it.

## Configure and validate

Run commands from the repository root.

```powershell
Copy-Item .\deploy\config\customer.sample.json .\deploy\config\customer.json
```

Edit the new nonsecret configuration:

1. Set subscription and tenant GUIDs.
2. Choose a new dedicated resource group and globally unique vault name.
3. Choose unique workspace, Lakehouse, environment, and notebook names.
4. Set `capacity.mode` to `existing` and provide its Fabric capacity GUID,
   not an ARM resource ID.
5. Obtain each administrator/customer confirmation before setting its
   corresponding `confirmations` boolean to `true`.

The existing local configuration is ignored by Git. Never put a key or token
in any configuration file.

```powershell
.\deploy.ps1 validate
.\deploy.ps1 deploy -WhatIf
```

Validation performs no cloud writes and does not execute Spark.
It checks tools, configuration, local definitions, generated notebook structure,
subscription/tenant, provider registration and regional metadata, resource
conflicts, vault name availability, Fabric authentication, visible active
capacity, workspace ownership, and an existing workspace's current-user Admin
role. Existing customer resources without matching ownership are not adopted.

Exit codes: `0` means checks passed with all confirmations supplied; `1` means
failure; `2` means automated checks passed but manual confirmation is required.
`deploy -WhatIf` permits unresolved confirmations so an administrator can review
the ARM preview. It still stops on failed automated checks.

ARM what-if does not preview Fabric API operations. It does not guarantee
regional quota, Spark capacity headroom, runtime licensing, or all Azure Policy
outcomes.

### Optional new capacity

Existing-capacity mode reuses the selected capacity and never changes its SKU,
state, administrators, or lifecycle. New capacity support is opt-in:

```json
{
  "mode": "new",
  "id": "",
  "name": "customeruniquecapacity",
  "sku": "F2",
  "administrators": ["capacity.admin@customer.example"]
}
```

Replace only the `capacity` object. Confirm cost, capacity name availability,
regional SKU availability, and quota before deploying. Only regional provider
metadata and visible naming conflicts are checked automatically; a successful
what-if is not a quota reservation. Do not select `new` to adopt an existing
customer capacity.

## Deploy Azure and Fabric resources

If the Azure button already succeeded, initialize configuration and use:

```powershell
.\deploy.ps1 deploy -AzureDeploymentName '<portal-record-name>'
```

This verifies the subscription deployment, user, parameters, and vault outputs
before finishing Fabric without submitting a new Azure create deployment.
Do not confuse the portal record name with the `deploymentName` ownership value.
See the [handoff guide](../03-finish-fabric/manual.md#initialize-the-local-handoff).

For CLI-only Azure and Fabric provisioning, use:

```powershell
.\deploy.ps1 deploy
```

The deployment provisions an RBAC-enabled, soft-delete and purge-protected Key
Vault, grants Key Vault Secrets Officer to the interactive user, creates or
reuses deployment-owned Fabric items, assigns the selected capacity, configures
Runtime 1.3 with `spark.native.enabled=false`, publishes the environment, waits
for completion, imports the notebook, and validates deployed item metadata
and environment settings.

GeoAnalytics is provided by the Fabric runtime when enabled. No `pip` packages
or fabricated GeoAnalytics distribution are installed. The generated notebook
also explicitly disables the Native Execution Engine at runtime.

The user creating the workspace receives its Admin role from Fabric.
The script verifies that role and does not add other principals or silently
elevate privileges.

No simulation or authorization probe runs during deployment.

### State and idempotency

Nonsecret state is saved under `deploy\state\<deploymentName>.json` and validated
against the [manifest schema](./fabric/deployment-manifest.schema.json).
It records deployment/version, subscription, tenant, region, executing user,
vault/secret name, capacity and Fabric IDs, timestamps, source commit when Git
is available, created-versus-reused item ownership, last submitted job, and
last verified output table names/counts.

State is checkpointed after provisioning milestones. Do not edit or delete it
to bypass checks. Rerun `deploy` after inspecting a partial failure. Azure and
Fabric resources are not rolled back automatically.

Exact name matching, expected type, ownership tags/descriptions, and compatible
region/capacity configuration are required. Duplicate names and unowned items
fail clearly. A repeat deployment reuses matching items, republishes the
environment, and updates the deployable notebook. This is not a no-op preview.
It can replace custom edits to that deployment-owned notebook.

Keep a single deployment process per deployment name. Concurrent provisioning
and cross-user adoption are not supported. List APIs only reveal resources the
caller can see; invisible conflicts still surface as service failures.

## Configure the GeoAnalytics key

```powershell
.\deploy.ps1 configure-secret
```

The hidden prompt passes the key directly to Key Vault over HTTPS. It is not
passed in a child-process command line, written to disk, printed, or returned
as an output. Secret contents necessarily exist briefly in process memory for
the HTTPS request. Do not use debug tracing, request-body logging, or inspect
process memory while setting credentials.

The command then checks secret metadata without returning its value.
Allow time for Azure RBAC propagation if Key Vault initially returns HTTP 403.
It does not claim that a local metadata check proves Fabric runtime access.
The notebook retrieves the key using `notebookutils.credentials.getSecret`
under the executing user. The explicit `run` preflight proves retrieval and
GeoAnalytics authorization before simulation submission.

For an Azure CLI alternative, use an access-restricted UTF-8 file populated
through your approved secret-management process, not a command-line value:

```powershell
az keyvault secret set --vault-name '<vault-name>' --name geoanalytics-api-key --file '<protected-key-file>' --encoding utf-8 --output none
```

Delete the protected file securely according to organizational policy.
Do not commit it, paste the key into chat, use `--value` in shell history,
or run `az keyvault secret show` without an output projection.

The POC vault has a public endpoint with Entra/RBAC authentication and TLS.
Private networking and managed private endpoints are not implemented.
Do not use this default in an environment that requires private-only access.

## Run and explore Fabric results

Start with a small synthetic test that avoids census-service downloads:

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json
.\deploy.ps1 status
```

`run` checks identity and manifest, deployed resources, secret existence and
metadata validity, then submits a small runtime preflight. If that succeeds,
it submits the simulation separately, polls its status, verifies its exit-value
contract, and reports table names and row counts. Failed, cancelled, unexpected,
or timed-out jobs cause a nonzero exit. A timed-out job may still be running;
use `status` and Fabric monitoring before submitting another.

Job submission uses the documented release endpoint with `beta=false`.
Notebook exit-value retrieval currently requires the documented notebook job
details endpoint with `beta=true`. This beta dependency is isolated in
`Invoke-NotebookJob` and is a production-readiness limitation. Failure to
retrieve a verified exit value is reported as failure, not success.

The original model calculations are retained. The generated notebook defaults
to 2 days, 10 km, H3 resolution 6, rather than the upstream 30-day, 150 km
scenario. This deliberate POC safety change reduces initial resource demand.
No F2 throughput or headroom guarantee is made.

The output tables use `<prefix>_<run_id>_<output>`:

| Output                             | Actual notebook result                                    |
| ---------------------------------- | --------------------------------------------------------- |
| `cells_daily`                      | Per-cell daily S/Z/R, population, vulnerability, status   |
| `arrival`                          | First infested day and peak zombies per reached cell      |
| `front_daily`                      | Daily footprint, hull, mean center, reach, and speed      |
| `grid_population_vulnerability`    | H3 grid, interpolated population, vulnerability indices   |
| `origin`                           | Scenario name and origin coordinates                      |
| `vulnerability_summary`            | Existing vulnerability-quintile analysis                  |

Geometry columns are converted to `*_wkt` strings with `geometry_srid=4326`.
This avoids persisting Esri spatial user-defined types directly into Delta or
claiming native SQL spatial compatibility. Open the Lakehouse tables in Fabric,
query tabular attributes through the SQL analytics endpoint after metadata
sync, or build semantic models and Power BI reports. WKT visualization depends
on the specific consumer; no mapping experience or semantic model is deployed.
An empty vulnerability summary is valid for synthetic population.

Each written table is read back in Spark and counted. Required origin, grid,
and daily-state outputs must be nonempty. A nonsecret result receipt is also
written under `Files/zombie_outbreak/run_id=<run_id>/result.json`.
SQL endpoint visibility and visualization still need end-to-end verification.

### Rerun with different parameters

Create a JSON object with case-sensitive notebook parameter names, for example:

```json
{
  "OUTBREAK_NAME": "Atlanta real-population validation",
  "SIM_DAYS": 3,
  "STUDY_RADIUS_KM": 10,
  "H3_RESOLUTION": 6,
  "USE_REAL_POPULATION": true,
  "RANDOM_SEED": 42,
  "TABLE_PREFIX": "zombie",
  "OVERWRITE": false
}
```

Use `-ParametersPath` to select it. Origins with real population must be in the
United States. A new run ID is generated unless supplied explicitly.
No secrets, deployment identifiers, or custom infrastructure paths are allowed
as run parameters.

Existing table names cause failure unless `OVERWRITE=true` is explicitly supplied.
Each table write is atomic, but the six-table group is not transactional.
A failed run can leave partial tables; inspect them and choose a new run ID,
or explicitly overwrite after reviewing ownership. Seeded randomness does not
promise identical results across different Spark partitioning/runtime versions.

## Removal and troubleshooting

Automatic removal is deliberately unavailable. `remove` exits nonzero rather
than guessing ownership. Review the manifest and the deployment-specific
resource tags/descriptions before manually deleting individual POC items.
Never delete or change an existing customer capacity or unrelated
workspaces. Vault purge protection retains deleted secrets
according to the retention policy; do not promise immediate name reuse.

| Symptom                      | Action                                                                  |
| ---------------------------- | ----------------------------------------------------------------------- |
| Exit 2 from validate         | Obtain outstanding confirmations; do not bypass admin settings          |
| Wrong tenant/subscription    | Use `az login --tenant` and `az account set`                            |
| Fabric HTTP 401/403          | Verify delegated scopes, workspace access, and capacity rights          |
| Vault HTTP 403               | Verify Secrets Officer RBAC propagation and network policy              |
| Capacity invisible           | Use the Fabric capacity GUID and verify user access                     |
| Ownership conflict           | Choose a new dedicated name; do not retag an unrelated resource         |
| Environment publish fails    | Inspect Fabric publication details, correct settings, then redeploy     |
| Import fails                 | Inspect notebook/item activity; the upstream source is unchanged        |
| Runtime preflight fails      | Verify tenant enablement, entitlement, key validity, and user KV access |
| Job succeeds but run fails   | Inspect beta exit-value retrieval and output-contract verification      |
| Upstream fingerprint fails   | Review source/adapter compatibility before changing the pinned hash     |

## Validation and remaining engineering work

```powershell
az bicep build --file .\deploy\main.bicep --stdout
.\deploy\tests\Test-Accelerator.ps1
.\deploy.ps1 validate
.\deploy.ps1 deploy -WhatIf
```

Offline checks exercise configuration-independent notebook transformation,
Python syntax, parameter types/ranges, ready and incompatible environments,
missing authentication/permissions/capacity, missing/denied secrets, asynchronous
failure propagation, import/submission failure, and manifest shape.
They do not substitute for cloud integration tests.

Before calling this customer-ready, verify a real deployment, runtime identity
and secret retrieval, the small synthetic run, real-source schema compatibility,
Delta table creation/SQL visibility, beta job exit-value behavior, and a repeat
deployment. Environment publication, notebook failures, runtime denial, and
successful Lakehouse creation require live integration evidence.
Also evaluate private networking, least-privilege separation of secret writer
and reader roles, preauthorized service principals, concurrent-deployment
locking, stronger ownership for safe removal, and the beta endpoint dependency.

## Official API and runtime references

* [GeoAnalytics setup and authorization](https://learn.microsoft.com/en-us/fabric/data-engineering/spark-arcgis-geoanalytics)
* [NotebookUtils current-user Key Vault retrieval](https://learn.microsoft.com/en-us/fabric/data-engineering/notebookutils/notebookutils-credentials)
* [Environment staging Spark settings](https://learn.microsoft.com/en-us/rest/api/fabric/environment/staging/update-spark-compute)
* [Environment publication](https://learn.microsoft.com/en-us/rest/api/fabric/environment/items/publish-environment)
* [Native Execution Engine settings](https://learn.microsoft.com/en-us/fabric/data-engineering/native-execution-engine-overview)
* [Notebook definition format](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/notebook-definition)
* [Run notebook with parameters](https://learn.microsoft.com/en-us/rest/api/fabric/notebook/background-jobs/run-on-demand-notebook)
* [Notebook job details and exit value (beta)](https://learn.microsoft.com/en-us/rest/api/fabric/notebook/background-jobs/get-notebook-job-instance(beta))
* [Workspace capacity assignment permissions](https://learn.microsoft.com/en-us/rest/api/fabric/core/workspaces/assign-to-capacity)
