---
title: Fast Pass engineering validation notes
description: Historical dogfood evidence, rejected experiments, and live-versus-repository validation boundaries.
ms.date: 2026-11-04
---

## Engineering evidence - not the customer journey

These notes preserve the investigation as it happened, including superseded
commands and recommendations. They are not current setup instructions.
Use the [customer journey](../README.md) and [current operations reference](../deploy/README.md)
to complete Fast Pass. No customer needs to reproduce these experiments.

The bounded synthetic run, private credential retrieval, authorization, six
outputs, interactive Fabric map and SQL counts were validated. Real-population
execution was not performed. New endpoint creation, pending approval/resume,
live collisions and live multi-page inventory remain repository-tested only.

The repository refinement changes `view-results` to publication only, followed
by customer-controlled **Open Results > Run all > View map**. Historical REST
preview evidence below remains valid, but preview submission is no longer the
customer path. This revised command has repository tests; it has not been
republished or rerun in the live environment during refinement.

The old immutable `v0.1.0` Azure button contains a public-access vault template.
The customer guide now loads the checked-out compiled private foundation into
Azure Custom deployment instead. That revised foundation-entry UI still needs
new-customer validation; no release/tag was changed.

The retired metadata-only [notebook fixture](./fixtures/setup-esri-api-key.ipynb)
and [persistence inspector tests](./tests/Test-SecretSetup.py) preserve the
notebook-input finding. Neither is deployed by Fast Pass. Moving the local
fixture does not delete the existing cloud diagnostic notebook or historical
Fabric service snapshots. The synthetic ARM probe remains subject to separately
approved cloud cleanup.

### Private-vault blocker and rejected exemptions

The original local writer failed with HTTP 403 / `ForbiddenByConnection`.
The vault's public access was Disabled and the caller was not using an approved
private link. A customer-authorized public-access update returned exit 0 but
did not persist. The inherited `MCAPSGov Deploy and Modify Policies` assignment,
through `KeyVault_PublicNetwork_Modify`, rewrote publicNetworkAccess to Disabled.
This MCAPS/SFI observation explains the private-only boundary; an accepted
management request was not evidence that the requested setting took effect.

The local client had no verified private route. Neither a Fabric endpoint
approval nor a TCP connection to a private IP proved local hostname/TLS access.
The subsequent ARM child-resource credential deployment removed the need for a
local Key Vault data-plane writer.

Earlier SecurityControl exemption investigation is engineering evidence only,
not a prerequisite or supported bypass. No `SecurityControl=Ignore`
implementation was retained. The full exemption-trial transcript is not captured
in these notes; no current validation claim depends on its success. VM, VPN,
Bastion and public-vault alternatives were rejected, not added to the product.

The `getpass` experiment below failed because no runtime prompt rendered.
The Password-widget experiment persisted its nonsecret input in metadata/widget
state before the callback. Both input methods were retired; their failed results
must not be represented as a secure credential-entry option.

### Repository refinement validation

All current offline suites passed: 49 accelerator checks, 27 HTTP compatibility
checks, 35 handoff checks plus private-foundation/journey/link contracts,
35 managed-endpoint checks, 34 secure ARM checks, 23 Results checks,
8 Python rendering/generated-notebook tests and 18 retired-fixture/persistence tests.
Both compiled templates passed freshness/compilation checks. Pylance reported
no syntax errors for the renderer and relocated persistence tests.

Filename/category-only sensitive-content scans found no credential/token/private-key
patterns in tracked/proposed content. Six ignored configuration/state/demo files
had unchanged SHA256 file hashes and remained untracked. This was a file-integrity
check, not a hash or inspection of the customer key. `git diff --check` passed.

This refinement made no Azure/Fabric cloud mutations, compute submissions,
cloud cleanup, commits or pushes.
The foundation selection UI and publication-only Results command were not
revalidated live. Existing synthetic/map/SQL acceptance is retained, not extended
to optional real population or a new customer's complete deployment.

## Status and architecture

First-time users should begin at [01 Start here](../01-start-here/README.md).
Use this optional reference for implementation details, troubleshooting,
maintenance or the alternative CLI-only deployment. It is not required
reading for the guided setup.
Obtain the pinned upstream notebook locally with `.\Get-DemoNotebook.ps1` first.

Bicep-led deployment automation for Azure and Microsoft Fabric resources.
This is an interactive-user POC, not a production-certified accelerator.
Deployment and simulation execution are separate operations.

```text
PowerShell entry point
  validate          Read-only Azure/Fabric checks and manual confirmations
  deploy -WhatIf    ARM preview only; no Fabric mutations
  deploy            Subscription Bicep -> resource group, private Key Vault,
                    vault RBAC, VNet/subnet, private endpoint and private DNS
                    Optional new capacity, only with capacity.mode = new
                    Fabric REST -> workspace, capacity assignment, Lakehouse,
                                   published environment, notebook
  configure-secret  Nonsecret instructions -> secure Azure credential deployment
  verify-secret     ARM metadata only; no credential retrieval
  configure-network Fabric managed private endpoint only; stop for Azure approval
  run               Runtime authorization probe -> parameterized simulation
                    -> six Delta tables and a nonsecret OneLake result receipt
  view-results      Owned Results notebook -> bounded read-only spatial preview
                    Separate paid job; no key retrieval or simulation rerun
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

Workspace, Environment and Notebook names accept letters, numbers, spaces,
underscores and hyphens, not periods. The generated Environment display name
ends in `Runtime 1-3`; the actual Spark runtime remains `1.3`.

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

The current Bicep source provisions an RBAC-enabled, soft-delete and
purge-protected Key Vault with public network access disabled, a dedicated
VNet/subnet, a dynamically addressed private endpoint, and private DNS.
It grants Key Vault Secrets Officer to the interactive user. Fabric setup creates or
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
against the [manifest schema](../deploy/fabric/deployment-manifest.schema.json).
It records deployment/version, subscription, tenant, region, executing user,
vault/secret name, capacity and Fabric IDs, timestamps, source commit when Git
is available, created-versus-reused item ownership, last submitted job, and
last verified output table names/counts.

State is checkpointed after provisioning milestones. Do not edit or delete it
to bypass checks. Rerun `deploy` after inspecting a partial failure. Azure and
Fabric resources are not rolled back automatically.

Capacity assignment can return `202 Accepted` without a `Location` header.
Deployment verifies the assignment by polling the workspace's `capacityId`
for up to ten minutes, without resubmitting the assignment. A timeout does
not mean the assignment was cancelled.

Operation and notebook-job `Location` headers can be absolute or relative
to `https://api.fabric.microsoft.com/`. Polling requires that same HTTPS
origin and rejects user information, nonstandard ports and fragments before
acquiring credentials. For long-running item operations, a valid
`x-ms-operation-id` takes precedence: the script constructs the documented
`https://api.fabric.microsoft.com/v1/operations/<id>` state/result endpoints
instead of following a regional Location. An invalid operation ID fails
explicitly. Notebook definition updates verify completion without requesting
a result body, and send the required `definition` request wrapper.
Rejection diagnostics include the scheme, host and
port, not credentials, paths or query strings. If a location is rejected,
inspect the service operation before an explicitly approved retry; do not
disable URL validation or assume that the service action failed.

Environment publication is verified separately by polling the Environment's
`properties.publishDetails.state` through `api.fabric.microsoft.com`, then
checking the published runtime and Spark settings. Its submission may return
a regional `analysis.windows.net` Location; the script does not follow that
URL or expand its credential host allowlist. Publication failure or timeout
still blocks Notebook import.

Exact name matching, expected type, ownership tags/descriptions, and compatible
region/capacity configuration are required. Duplicate names and unowned items
fail clearly. When exactly one Lakehouse matches, its same-named SQL endpoint
is excluded from the name-conflict check. Lakehouse ownership is still required;
multiple Lakehouses, other item-type conflicts, and a SQL endpoint without a
matching Lakehouse still fail. A repeat deployment reuses matching items, republishes the
environment, and updates the deployable notebook. This is not a no-op preview.
It can replace custom edits to that deployment-owned notebook.

Keep a single deployment process per deployment name. Concurrent provisioning
and cross-user adoption are not supported. List APIs only reveal resources the
caller can see; invisible conflicts still surface as service failures.

## Configure the GeoAnalytics key

Complete [manual Step 20](../03-finish-fabric/manual.md#step-20-securely-provide-the-esri-api-key)
after Fabric finish. Run:

```powershell
.\deploy.ps1 configure-secret
```

This prints only the target and the local nonsecret template path. Load
[secret-setup.azuredeploy.json](../deploy/secret-setup.azuredeploy.json) into Azure
Custom deployment, select the existing group/vault, enter the key only in the
masked `geoAnalyticsApiKey` parameter field, and review/create once. Do not
put the key in the template editor, chat, files, command arguments, notebook
code, outputs or deployment debug logs. No additional infrastructure or
public vault access is required.

The template deploys one enabled `geoanalytics-api-key` child resource through
ARM, leaving the existing vault and networking unchanged. Secure parameter
values are not saved in normal deployment history. Do not export parameter
values or enable request/response debug logging. Do not overwrite an existing
credential without an explicit rotation decision.

After Azure reports **Deployment succeeded**, run:

```powershell
.\deploy.ps1 verify-secret
```

Expect `Secret metadata verified; runtime access is checked during run.`
This is an ARM metadata check, not secret retrieval. `run` uses the same
metadata gate, then the existing Fabric preflight proves private runtime
retrieval and GeoAnalytics authorization before simulation submission.

The deployer needs `Microsoft.KeyVault/vaults/secrets/write` and deployment
permissions at the appropriate scopes; metadata checks need ARM vault/secret
reads. The notebook user separately needs data-plane secret Get permission.
No new role grants or `enabledForTemplateDeployment` change are needed.
See [Microsoft's networking distinction](https://learn.microsoft.com/en-us/azure/key-vault/general/overview-vnet-service-endpoints#usage-scenarios)
and [secure parameter protection](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters#secure-parameters).
Historical investigations remain in the optional engineering evidence below;
they are not customer setup steps.

### Private Key Vault foundation

The current Bicep source keeps Key Vault public network access disabled, with
firewall default action Deny and no trusted-service bypass. It creates a
dedicated VNet and private-endpoint subnet, an Azure private endpoint targeting
the `vault` subresource, and a `privatelink.vaultcore.azure.net` private DNS zone.
A zone group manages the endpoint's DNS record; a VNet link makes that private
zone available to the dedicated network. No private IP is hardcoded, and the
endpoint manages its own NIC. No VM, VPN, Bastion, public IP, or policy exclusion
tag is deployed.

The additional subscription-template parameters have these defaults:

| Parameter                             | Default                         |
| ------------------------------------- | ------------------------------- |
| `virtualNetworkName`                  | `vnet-<deploymentName>`          |
| `virtualNetworkAddressPrefix`         | `10.0.0.0/16`                   |
| `privateEndpointSubnetName`           | `snet-private-endpoints`        |
| `privateEndpointSubnetPrefix`         | `10.0.0.0/24`                   |
| `privateEndpointName`                 | `pe-<keyVaultName>`              |
| `privateEndpointNetworkInterfaceName` | `nic-<privateEndpointName>`      |
| `privateDnsLinkName`                  | `<virtualNetworkName>-vault`    |

Review names, CIDR overlap, subnet containment, networking permissions and
organization policy before deploying a fresh dedicated foundation.
`Microsoft.Network` must be registered, in addition to the existing providers.
Azure endpoint approval depends on the deployer's permissions and must be
verified explicitly. The nonsecret outputs include the VNet, private endpoint,
and private DNS zone resource IDs, not the secret or a fixed private address.

> [!IMPORTANT]
> This is the first repository implementation stage, not a completed private
> Fast Pass. The unchanged Azure button remains pinned to `v0.1.0`; it does not
> publish the modified local template. Do not redeploy the manually validated
> foundation or replace existing networking to test these changes.

The Azure private endpoint does not connect your computer or Fabric.
Credential provisioning and local metadata verification use ARM; Fabric
runtime retrieval uses the separately approved managed private endpoint.
Do not enable public access to bypass a failed check.

### Fabric managed private endpoint

Stage 2 has repository-test coverage and limited live validation of reuse.
The original manual experiment established an endpoint with Activation
Succeeded and Approval Approved while Key Vault public access remained
Disabled. It remains separate from the automated lifecycle evidence below.

LIVE VALIDATED (2026-11-05, existing approved endpoint only):

* Existing approved endpoint discovery
* Target Key Vault resource ID and `vault` subresource validation
* Separate Succeeded activation and Approved approval recognition
* Endpoint reuse and network-only resume
* Idempotent rerun
* Nonsecret state persistence

The exported `configure-network` handler, `Set-DeploymentNetwork`, ran twice
under a runtime GET-only service-request guard. Both runs reported Existing,
activation Succeeded and approval Approved. All 15 service requests were GETs;
no create, approval or asset-update request was issued. Endpoint count remained
one before and after, with identical endpoint IDs. Key Vault public access
remained Disabled. The local manifest retained Configured and all existing
resource records, adding only endpoint metadata, its reused resource record
(`created=false`), and the updated timestamp. The persisted state passed its
schema. No secret access, notebook execution or Stage 3 work was performed.

REPOSITORY TESTED ONLY:

* Creation when no endpoint exists
* Pending-approval stop
* Post-approval resume after an accelerator-created endpoint
* Collision behavior against a live conflicting endpoint
* Pagination against a live multi-page endpoint inventory

The last two behaviors use mocked inventories in repository tests; neither
was exercised against live conflicting endpoints or live multi-page results.
The guarded handler runs validate the network-only lifecycle, not invocation
of the CLI argument dispatcher. The full `status` command was not run live
because it also obtains a notebook definition using a metadata-read POST.
Network status was read directly through the lifecycle endpoint-status helper
and reported independently by both network-only runs.

Fabric finish now discovers the endpoint named `mpe-<keyVaultName>` in the
deployment workspace before creating one. Its target comes from the Key Vault
ARM resource ID recorded by the Azure handoff. Both that resource ID and the
`vault` subresource must match. Duplicate expected names, a mismatched target,
or disagreement with a recorded endpoint ID stop deployment without deleting,
adopting, or replacing a connection. Other names are not adopted as Fast Pass
endpoints.

The supported Fabric v1 API operations are:

* `GET /workspaces/<workspaceId>/managedPrivateEndpoints` with pagination
* `GET /workspaces/<workspaceId>/managedPrivateEndpoints/<endpointId>`
* `POST /workspaces/<workspaceId>/managedPrivateEndpoints`

Creation uses `name`, `targetPrivateLinkResourceId`, `targetSubresourceType`
(`vault`), and the request message
`Fabric GeoAnalytics Fast Pass access to Key Vault`. The supported response
is HTTP 201. The lifecycle persists the endpoint ID before waiting for
activation; it never repeatedly submits creation while polling.

The manifest records only endpoint identity, target, `provisioningState`,
and `approvalState`. `provisioningState` is Fabric activation;
`approvalState` comes from the API's `connectionState.status`.
Missing approval metadata remains null, not Approved or an invented API state.
`status` reports `managedPrivateEndpointReady` only for Succeeded plus Approved.
This indicates connection metadata readiness, not successful secret retrieval.
Legacy Configured manifests do not establish endpoint readiness.

If approval is Pending, the command persists that checkpoint and exits with an
error before proceeding with Fabric item creation/publication. An authorized
administrator must open the deployed Key Vault in Azure portal, then
**Networking > Private endpoint connections**. Identify the Fabric-generated
connection using its target and the request message, and approve that request
under the organization's policy. Azure may display a generated connection name
rather than the Fabric endpoint name. Do not approve unrelated requests.
This stage does not issue Azure approval writes or grant roles.

After approval, request separate permission to resume the network step:

```powershell
.\deploy.ps1 configure-network
.\deploy.ps1 status
```

`configure-network` verifies the original interactive identity, workspace
ownership/capacity and Admin role, then discovers/reuses or creates only the
managed endpoint. It does not redeploy Azure, republish the Environment,
update the Notebook, or submit compute. It requires approval because it can
create an endpoint if none exists. Pending approval, failed activation,
rejection, disconnection, unknown state and timeout are not success.
For timeouts, inspect the recorded endpoint before resuming; a missing recorded
endpoint is not automatically recreated.

If Fabric assets were never finished, resume the separately approved
`deploy -AzureDeploymentName <verified-record>` step after the network checkpoint.
That command may republish/update assets; do not use it merely to inspect or
resume networking on an already configured workspace.

The create API requires workspace Admin and delegated `Workspace.ReadWrite.All`;
list/get require Viewer or higher and `Workspace.Read.All` or
`Workspace.ReadWrite.All`. Azure approval separately requires authorized Key
Vault private-endpoint-connection write permission. No secret Set/Get permission
is implied by endpoint approval.

No API key is requested by the managed endpoint flow. The Python artifact's
metadata check is available, but its secure-input experiment failed; see the
[blocked secret-entry handoff](#configure-the-geoanalytics-key). Replacement of
the local run metadata gate remains a separate, narrowly scoped resume step.
Keep workload compute paused until secret setup succeeds and run approval is
obtained.

### Secret setup engineering evidence

On 2026-11-05, read-only resume checks reconfirmed the original deployment user,
Configured state, existing workspace/capacity, and the same approved managed
endpoint with activation Succeeded. Key Vault public access remained Disabled;
no existing job was recorded. No cloud writes or secret reads were used for
these checks.

REPOSITORY TESTED ONLY:

The initial setup prototype's 11 offline tests passed, together with the existing
35 handoff, 35 managed-endpoint, and 73 accelerator/HTTP checks. These mocks did
not establish Fabric frontend input support. An initial
documentation-link check rejected a percent-encoded filename with spaces;
the artifact was renamed to `setup-esri-api-key.ipynb` and the checks passed.

* The Python setup artifact lists only metadata and requests no key.
* The revised artifact disables both input and write cells with explicit errors.
* Metadata validation requires enabled/time-valid attributes for an existing
  secret; no `getSecret`, value GET, `putSecret`, or input function is invoked.
* Metadata-only reruns perform no writes. Transport failures, malformed
  responses and unexpected/repeated continuation URLs fail explicitly.

LIVE VALIDATED (import only):

With explicit customer approval, the existing Fabric item helper imported
one notebook named `00 - Setup Esri API Key`, with only its nonsecret vault URL
filled from the existing manifest. A request guard permitted only that
creation POST and subsequent metadata/operation GETs. Workspace item count
changed from four to five; all existing item IDs remained present. The setup
ID was recorded as `resources.SecretSetupNotebook` in ignored local state,
which retained Configured and passed its schema.

A separate definition-read POST verified the imported notebook's identity,
three code cells, empty outputs, null execution counts, and matching vault URL.
Its standard `python3` kernelspec was retained; the customer must still select
the Fabric **Python** runtime in the UI before execution. No job was submitted,
no existing asset was republished, and no secret was requested or accessed.

CUSTOMER-CONFIRMED LIVE (metadata check):

The customer ran only the first code cell in Fabric and reported
`Metadata check passed; secret is absent`. This establishes successful
Python-runtime metadata access to the private-only vault and absence of the
named secret at that checkpoint. It is interactive customer evidence, not an
automated notebook-run result or secret-value retrieval.

CUSTOMER-CONFIRMED FAILURE (secure input):

The customer ran the second code cell. It kept running without displaying an
input box. After being instructed to cancel the probe without entering a key,
the customer confirmed that it stopped. The secret was not supplied or written.
This disproves the assumed frontend input path for this session; it does not
invalidate the successful metadata/private-connectivity check.

The repository artifact was narrowed to metadata-only checks, with explicit
blocking errors in place of input/write cells. The revised 11 offline tests,
35 handoff checks, and documentation/private-foundation contracts passed.
With separate customer approval, one setup-only definition update applied
that correction in Fabric. A definition-read POST verified all three code
cells against the revised local artifact, with empty outputs and null
execution counts. No execution was submitted and the GeoAnalytics workload
notebook was not modified. No password-widget fallback was added:
the [ipywidgets Password documentation](https://ipywidgets.readthedocs.io/en/stable/examples/Widget%20List.html#password)
warns that saved widget state contains plaintext passwords. The documented
VS Code Fabric extension targets remote Spark, so it was not treated as proof
of secure input for the Python-only `putSecret` API. No alternative secret
channel or network architecture was implemented.

NOT LIVE VALIDATED:

* Customer-controlled secret write and enabled metadata verification
* GeoAnalytics Spark retrieval, Esri authorization and bounded output validation

The documented Python `putSecret` and Python-runtime managed endpoint support
establish the API/networking design, not a secure customer-input channel.
See [NotebookUtils credentials](https://learn.microsoft.com/en-us/fabric/data-engineering/notebookutils/notebookutils-credentials)
and [managed endpoint item support](https://learn.microsoft.com/en-us/fabric/security/security-managed-private-endpoints-overview#supported-item-types).
Secure secret bootstrap remains BLOCKED until an approved nonpersistent input
process with private vault access is available. Do not infer success from the
endpoint approval or repository tests.

The customer confirmed that only the current local terminal and Fabric workspace
are available, with no other existing approved private-connected admin client.
No new compute/connectivity infrastructure or alternative credential-transfer
mechanism was introduced. The deployment remains Configured; the secret,
GeoAnalytics authorization, and bounded workload run remain unvalidated.

#### Password-widget persistence experiment

The customer authorized Phase 1 only: update the existing temporary setup
notebook with `ipywidgets.Password`, a button callback, and pass/fail output.
The expected nonsecret marker is assembled inside the callback rather than
stored as a contiguous source literal. The callback keeps the entered value
local, clears the control immediately and again in `finally`, unregisters the
callback, and closes the input/button. No secret write or retrieval is present.
The GeoAnalytics workload notebook and infrastructure remain unchanged.

REPOSITORY TESTED ONLY: 21 offline tests cover metadata checks, callback
pass/fail, clearing/closure, missing widget support, blocked Phase 2, and the
persistence-inspection helper. Mocked controls do not establish live rendering
or storage behavior. The audit helper scans decoded definition parts, source,
outputs, metadata, widget state, and parameter containers. It rejects
uninspectable payloads and any persisted widget-state container, even empty.
Widget-view references are reported separately from saved widget state.

The live experiment has two persistence checkpoints: save while the masked
nonsecret field is populated but before clicking the button, then save after
the callback clears/closes the controls. Both Notebook and Item definition
API views must be inspected, including all returned parts. Local deployment
state and repository files must also contain no marker. No output cleanup,
manual state deletion, or refresh is allowed before each inspection.

LIVE VALIDATED (pre-entry baseline only): one guarded setup-only definition
update deployed the Phase 1 artifact without execution. Notebook and Item
definition reads each returned two inspected parts, including one notebook.
Both contained no probe in source, outputs, metadata, widget state, parameter
containers, or the overall definition; no saved widget-state container or
widget-view reference was present. A scan of 54 repository files, including
ignored files but excluding the Git object database, and the parsed deployment
manifest found no marker. No workload notebook or infrastructure was modified.

CUSTOMER-CONFIRMED LIVE: the Password field and button rendered, the field was
masked, and the customer entered only the nonsecret marker and saved without
clicking the button.

LIVE FAILED (populated field saved before callback):

Both Notebook and Item definition reads returned the entered marker in
notebook metadata and saved widget state. Each view included two inspected
parts and three widget-view references. The source and outputs did not
contain the marker, but the complete saved Fabric definition did.

| Inspected surface | Nonsecret marker found |
| ----------------- | ---------------------- |
| Notebook source | No |
| Notebook outputs | No |
| Notebook metadata | Yes |
| Saved widget state | Yes |
| Saved parameter containers | No |
| Overall Fabric item definition, including decoded parts | Yes |
| Parsed local deployment state | No |
| Repository files, including ignored files and excluding Git objects | No |

The local scan covered 54 files. Inspection emitted only flags and counts,
not the entered value; no raw saved definition was written to the repository.
The definition reads were guarded read-only operations: no additional
definition update, secret access, workload execution or infrastructure change
was performed.

The experiment stopped at this failure. The live callback and after-callback
snapshot were NOT RUN; Phase 2 was NOT STARTED and no actual API key was
requested, supplied, stored or retrieved. Clearing a control in a later callback
cannot prevent the already observed pre-callback persistence. Even a clean
after-callback snapshot would not make this method acceptable.

A clean after-callback snapshot alone does not establish that a populated field
was never persisted. Any marker occurrence or persisted widget state blocks
progression. Phase 2 is blocked by this observed failure, not awaiting an
approval override.
The inspections cover the returned saved definitions, not undisclosed service
logs, historical snapshots, or a general security certification.

#### Metadata-only setup cleanup

LIVE VALIDATED (current saved-definition cleanup):

After the customer confirmed stopping the setup Python session and closing
its browser tab, one guarded setup-only definition update replaced the
experimental notebook with metadata-only diagnostics. Both Notebook and Item
definition reads inspected two parts, including one notebook. Both matched
the local artifact's single code cell and Markdown, with empty outputs and
null execution count.

Neither view contained the nonsecret marker in source, outputs, metadata,
widget state, saved parameter containers, or any decoded definition part.
No widget-state container or widget-view reference remained. A scan of 54
repository files, including ignored files but excluding Git objects, also
found no marker. The local deployment manifest was unchanged.

The existing GeoAnalytics workload definition was read before and after the
cleanup and was unchanged. The request guard permitted exactly one setup
update, definition-read POSTs, and metadata/operation GETs. No secret request,
notebook execution, workload update, infrastructure mutation, or role change
was performed. Current-definition cleanup does not establish erasure of
historical service snapshots or logs.

REPOSITORY TESTED ONLY: the current 18 tests cover diagnostic-only execution,
metadata validity and failure handling, safe pagination, absence of input and
write code, and saved-definition inspection. The observed Password-state
failure remains a regression fixture. Both saved widget-state containers and
widget-view references block cleanup acceptance. Earlier callback tests
described above apply to the retired experiment, not the current artifact.

#### Secure ARM credential step

LIVE VALIDATED (synthetic credential only):

One customer-authorized, guarded Incremental resource-group ARM deployment
used the compiled secure credential template, changing only the nonsecret
child name to a unique probe name. The synthetic value entered the request
through its SecureString parameter in memory, not a file or command argument.
The deployment Succeeded and ARM metadata confirmed the probe was enabled.

The value was absent from the returned submission response, deployment
history, deployment operations, exported template and secret metadata.
History retained the SecureString type without its value; outputs were absent.
The vault remained publicNetworkAccess Disabled and
enabledForTemplateDeployment false. Networking and RBAC settings were
unchanged. Secret inventory changed from zero to one probe; the production
`geoanalytics-api-key` remained absent.

The guard allowed one deployment PUT, one read-only template-export POST,
and bounded ARM GETs. No Fabric or Key Vault data-plane request occurred.
The local manifest was unchanged and a scan of 57 repository files, including
ignored files and excluding Git objects, found no synthetic value.
The probe remains for separately approved cleanup; it cannot satisfy the
production credential gate.

The customer path now uses a secure Azure parameter field and metadata-only
verification. The blocked local data-plane gate in `run` was replaced with
ARM metadata verification; runtime retrieval and authorization remain in the
existing Fabric preflight. No Azure foundation or workload was republished.

Final handoff validation exposed a CLI module-boundary error: `verify-secret`
called an unexported helper. An exported metadata-only wrapper fixed it.
Before customer credential entry, the actual CLI exited 1 with
`Missing geoanalytics-api-key`, correctly
rejecting the separate probe. Offline regressions passed: 34 secure ARM
checks, 46 accelerator checks, 27 HTTP compatibility checks and 35 experience
checks plus private-foundation contracts. Both compiled templates were current
and `git diff --check` passed.

LIVE VALIDATED (customer credential metadata): the customer reported successful
deployment after entering the real credential through the secure Azure UI.
`.\deploy.ps1 verify-secret` exited 0 and verified enabled/current production
secret metadata. Copilot did not receive or inspect the credential value.

The subsequent status check returned HTTP 404 from typed Environment APIs
while the generic Environment item remained readable. The customer confirmed
that the existing capacity was paused, resumed it, and confirmed active state.
After resumption, `.\deploy.ps1 status` exited 0: Configured, Runtime 1.3,
notebook bindings verified, endpoint activation Succeeded and approval Approved.
No Environment recreation, republication or API-route change was needed.

LIVE VALIDATED (bounded synthetic run): after separate customer compute
approval, `.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json`
exited 0. Preflight job `b803983b-dd76-4d05-a1dd-9b293cc45521` completed,
including private Fabric `getSecret`, GeoAnalytics authorization and a geometry
operation. Simulation job `eb32afa0-ee15-4298-8dd2-45f7344c1baf` then completed.
No retry or duplicate submission was made.

Run `20261106T193642_498c8f` persisted six outputs and read them back:
cells_daily 3, arrival 1, front_daily 3, grid_population_vulnerability 17,
origin 1, vulnerability_summary 0. The empty synthetic summary is allowed.
The receipt path is
`Files/zombie_outbreak/run_id=20261106T193642_498c8f/result.json`.
Post-run status exited 0 and its verified output counts matched the persisted
manifest result. The workload keeps WKT geometry in Delta tables; the current
customer viewing steps cover tables and SQL, not a rendered map.

NOT RUN at this checkpoint: manual Lakehouse/SQL acceptance, rendered spatial
map acceptance and a real-population run. The synthetic credential test establishes
the ARM write/history boundary, not a browser-state or general security
certification. The customer journey does not require the historical notebook
experiments or private management-surface investigation below.

The customer separately approved a credential-free Results notebook and one
bounded preview of the completed run. Local viewer, rendering and regression
tests passed. The first guarded live attempt stopped at readiness with an
Environment HTTP 404; physical create requests and preview submissions were
both zero. Fabric capacity metadata then reported `esriontologypoc`, F2,
Inactive. Fast Pass now shares the existing active-F-capacity validation with
status, surfacing the customer resume action before typed Environment calls.
No capacity lifecycle change or existing-asset update was performed.

LIVE VALIDATED (read-only spatial preview): after the customer resumed the
existing capacity, status reported Active and exited 0. The guarded preview
created only `geo-atlanta-tonyfra-01 Results`
(`1cbb43ae-cad6-40ac-bad1-d94b3ae4f4b3`), verified its saved source and existing
Lakehouse/Environment bindings, and submitted one job
(`96100e6c-ad2e-4a5d-9293-2b186a86c426`). It completed with exit 0 and returned
the same simulation run ID, 17 grid rows, one arrival row and one origin row.
The self-contained SVG was rendered and visually inspected in a local browser:
17 study-grid cells, one red reached cell and a blue origin.
The physical request guard counted one create and one preview submission;
no existing notebook, environment, endpoint or output table was modified.
Post-preview status verified both completed jobs and preserved the original
simulation job/result separately from the preview. Offline checks passed:
19 preview/capacity checks, eight Python geometry/generated-notebook tests,
46 accelerator checks, experience/handoff contracts, 35 endpoint checks and
34 secure ARM checks. `git diff --check` passed.
At that point, manual Fabric map visibility and SQL counts were unconfirmed; local browser
rendering does not establish those customer-UI checks. The optional
real-population run remains NOT RUN.

CUSTOMER UI CHECK: the customer can see the completed preview run in Fabric,
but its rendered map output is missing from that view. This is not map
acceptance. Do not repeat the REST preview or simulation to obtain visible
output. The next check is a separately approved interactive Run all of the
credential-free Results notebook; its result is not yet known.

LIVE VALIDATED (customer Fabric map): the customer separately approved one
interactive Run all of the Results notebook, then confirmed that the map is
visible in Fabric. The viewer reads the already verified run; it does not
retrieve the credential, write tables or rerun the simulation.
The remaining acceptance check is manual SQL visibility/counts.
The optional real-population run remains NOT RUN.

LIVE VALIDATED (customer SQL acceptance): the customer ran the six-output
SQL count query and confirmed that all counts match the Spark receipt:
cells_daily 3, arrival 1, front_daily 3, grid_population_vulnerability 17,
origin 1, vulnerability_summary 0.
The bounded synthetic Fast Pass outcome is complete: secure customer credential
provisioning, private Fabric retrieval, GeoAnalytics authorization, simulation,
six persisted/read-back outputs, customer-visible Fabric map and matching SQL
counts. This is bounded synthetic acceptance, not a production certification
or validation of the optional real-population workload.

#### Private management handoff assessment

HISTORICAL ASSESSMENT, SUPERSEDED: the secure ARM credential step above replaces
the private-management-surface recommendation. The following records the
earlier investigation, not additional customer actions.

READ-ONLY ASSESSMENT, NOT A LIVE SECRET-WRITE VALIDATION:

The smallest supported handoff is an existing approved Azure-hosted private
management surface, such as
[VNet-integrated Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/vnet/overview),
running the existing hidden-prompt writer. It must have private DNS and
routing to the vault's existing Azure private endpoint. The approved Fabric
managed endpoint does not provide another service's network path.

No suitable execution service was found among 37 caller-visible ARM resources
in the current subscription. This inventory does not rule out services in
other subscriptions or organization-managed deployment systems. The Cloud
Shell profile lookup returned HTTP 404; profile availability remains
unverified. Default Cloud Shell is not a private-network execution surface,
and opening the Azure portal does not grant the browser private routing.

Options were assessed in this order:

1. Reuse an approved private Azure-hosted management surface. No usable
   instance is currently confirmed. Creating private Cloud Shell would need
   additional network, Relay and storage resources, platform permissions and
   cost approval. Its
   [deployment prerequisites](https://learn.microsoft.com/en-us/azure/cloud-shell/vnet/deployment)
   are not an authorization to provision it as part of this deployment.
2. Use deployment or automation only with a verified private execution path
   and approved runtime input handling. ARM
   [secure parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/parameters#secure-parameters)
   are excluded from deployment history, but the customer's restriction
   explicitly disallows supplying this key in ARM parameters. Default
   [Automation cloud sandboxes](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-execution)
   do not provide interactive input or the required private route.
   [Encrypted Automation variables](https://learn.microsoft.com/en-us/azure/automation/shared-resources/variables)
   and pipeline secret variables retain a protected copy in service
   configuration; encryption is not absence of retention. No qualifying
   execution-time mechanism is confirmed here.
3. Reuse an organization-approved secret/deployment service only after its
   private route, execution identity, input handling and retention policy
   are confirmed. No such service has been identified. Do not place the key
   in GitHub or create a credential store to bypass this checkpoint.

Before any key entry, Fast Pass can guide or check the original identity,
deployment ownership, private DNS/access, existing RBAC and Disabled public
access, then prepare only nonsecret files on the approved surface. Keep
configuration and state out of source control. Do not transfer a key in
those files or use request tracing, session recording, or body logging.

The one-time customer secret-entry action, only after those checks pass, is
to run `.\deploy.ps1 configure-secret` in that surface's visible PowerShell 7
terminal and enter the key only at `Esri GeoAnalytics API key (hidden)`.
Copilot must not execute or inspect that interactive entry. The existing
writer does not put the value in command arguments, ARM deployments, files,
logs, outputs, or an automation variable. It handles the HTTPS body in memory
and clears its managed references afterward; this is not guaranteed physical
erasure of every memory copy.

The browser and shell necessarily handle the input in volatile memory.
Browser extensions, session recording and organization-specific telemetry
must be approved separately; no blanket browser-state or service-log
non-retention claim has been validated. Key Vault intentionally retains the
secret, and its
[audit logs](https://learn.microsoft.com/en-us/azure/key-vault/general/logging)
record operation/identity/status metadata. No extra service configuration
copy is part of the proposed writer.

The writer requires secret Set and metadata List permission. The customer's
existing vault-scoped Key Vault Secrets Officer assignment and Disabled
public access were reconfirmed through reads. An assignment read is not proof
that a write will succeed. Runtime Get permission is separate; control-plane
Owner or Global Administrator is not a substitute for data-plane permission.
No new role assignment is proposed.

Verify success by listing metadata for the exact secret name and confirming
it is enabled and currently valid, without secret-value retrieval or display.
The existing writer performs a metadata check after its write. Fabric's
metadata-only diagnostic can subsequently corroborate access with customer
approval; neither check establishes GeoAnalytics authorization.

Secret provisioning remains BLOCKED on identifying an approved private
execution surface. No infrastructure or secret-provisioning changes were
made during this assessment. The existing local metadata gate in `run`
remains a separate issue for a caller without private access; do not bypass it
or submit the workload while bootstrap is unresolved.

Before claiming live validation of endpoint creation and its approval cycle,
separately authorize and verify a newly submitted request, the Pending
checkpoint, Azure approval, and resume without duplicate creation. Do not
delete or modify an existing validated endpoint to manufacture that test.
Run the offline contract suite with:

```powershell
.\deploy\tests\Test-ManagedPrivateEndpoint.ps1
```

See the [create API](https://learn.microsoft.com/en-us/rest/api/fabric/core/managed-private-endpoints/create-workspace-managed-private-endpoint)
and [list API](https://learn.microsoft.com/en-us/rest/api/fabric/core/managed-private-endpoints/list-workspace-managed-private-endpoints)
contracts.

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
sync, or build semantic models and Power BI reports. The separately approved
Results viewer renders the existing WKT grid/arrival/origin without an external
basemap. No semantic model or ArcGIS publication is deployed.
An empty vulnerability summary is valid for synthetic population.

Each written table is read back in Spark and counted. Required origin, grid,
and daily-state outputs must be nonempty. A nonsecret result receipt is also
written under `Files/zombie_outbreak/run_id=<run_id>/result.json`.
Manual SQL endpoint and Fabric map visibility require customer verification.

### View the completed run

After separate publication/compute approval, run `.\deploy.ps1 view-results`.
It creates or updates only the owned `<deploymentName> Results` notebook,
verifies its saved definition, and submits a bounded read-only preview of
`lastResult`. It never retrieves a credential or reruns the simulation.
The preview job/result are persisted separately; `status` reports them.
An active recorded preview blocks resubmission. It returns a self-contained
SVG saved in the ignored local state folder and displays that map in the
notebook output. See the numbered
[viewing steps](../04-run-and-verify/manual.md#view-the-completed-spatial-result)
for Fabric UI acceptance and the supported geometry/row limits.

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

## Architecture details

The following details are optional reference, not additional steps in the
guided setup.

### Separate the resource planes

```text
README blue button
    -> versioned ARM JSON compiled from Bicep
    -> subscription / dedicated resource group
       -> private RBAC Key Vault
       -> dedicated VNet/subnet / Azure private endpoint / private DNS
       -> optional new Fabric capacity

Interactive PowerShell finish
    -> verify completed Azure deployment and identity
    -> read-only prerequisite and ownership checks
    -> Fabric REST workspace / capacity assignment
    -> managed Key Vault endpoint / explicit Azure approval checkpoint
    -> Lakehouse / published environment / notebook

Explicit secret and run commands
    -> customer secure Azure deployment parameter writes Esri key
    -> ARM verifies enabled/current secret metadata without retrieving a value
    -> notebook runtime retrieves key from Key Vault
    -> authorization probe
    -> spatial simulation
    -> six Delta tables + OneLake receipt + read-back counts
```

ARM manages Azure resources. Fabric REST manages workspace items.
The standard Azure button accepts ARM JSON, not a remote Bicep file:
[Microsoft's button guidance](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-azure-button).

The existing ownership marker `fabric-zombie-outbreak` remains in resource tags
and Fabric descriptions so the reused adapter/lifecycle checks stay consistent.
The repository name and deployment-first presentation do not silently change
that ownership contract.

### Lessons carried forward from the demo

| Demo pattern                        | Deployment lesson                                                      | Next experiment                                                 |
| ----------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------- |
| H3 cells and spatial joins          | Fix runtime and engine compatibility before workload execution         | Compare grid resolutions at bounded study radii                 |
| Census and vulnerability enrichment | Treat source coverage, schema, and access as separate prerequisites    | Validate a small real-population US run                         |
| Iterative movement graph            | Capacity visibility does not prove Spark headroom                      | Measure wall time and memory before increasing days/radius      |
| Spatial outputs                     | Define an explicit data contract, not merely a successful notebook job | Confirm Delta read-back and SQL visibility                      |
| Optional downstream publication     | Keep ingestion/compute separate from destination credentials           | Design a separately consented ArcGIS publishing stage           |
| Notebook parameters                 | Separate workload inputs from infrastructure and secrets               | Adapt the pattern to service coverage or accessibility analysis |

The fictional simulation is a teaching workload, not an epidemiological,
emergency-planning, or public-health prediction.

### Why not one unattended button yet

Embedding Fabric provisioning in an ARM deployment script would introduce a new
runtime identity, token acquisition, consent, and credential lifecycle.
The current interactive-user model cannot be replaced by a managed identity
without proving the exact Fabric APIs and runtime Key Vault access path.

The two-stage experience makes that boundary visible instead of hiding an
unsupported identity assumption behind an Azure success screen.

### Evidence-driven roadmap

1. Complete the [live acceptance checklist](../04-run-and-verify/manual.md#acceptance-checklist)
   in a dedicated tenant/workspace.
2. Validate real-source coverage and schema, then measure bounded scale increases.
3. Evaluate private networking and separate key-writer/key-reader roles.
4. Add concurrency locking and stronger removal ownership before automating cleanup.
5. Evaluate the beta job exit-value dependency and compatible stable alternatives.
6. Prove a least-privilege unattended identity for each Fabric operation before
   adding deployment-script orchestration or another one-button finish experience.

These are future capabilities, not switches supported by this release.
Existing capacity lifecycle, ArcGIS publication, unattended execution, and
automatic cleanup remain out of scope.

## Validation and remaining engineering work

For maintainers changing the accelerator, run the following from the
repository root. These are not additional steps for first-time users.

```powershell
.\Get-DemoNotebook.ps1
.\deploy\tests\Test-Accelerator.ps1
.\deploy\tests\Test-Experience.ps1
.\deploy\scripts\Build-Template.ps1 -Check
```

After editing Bicep, regenerate the portal template:

```powershell
.\deploy\scripts\Build-Template.ps1
```

The Azure button pins release `v0.1.0`. Updating `main` does not change
that released deployment. A future release must update the button and be
tagged after validation.

Once signed in and configured, check the target tenant without deploying:

```powershell
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
