---
title: Fast Pass operations reference
description: Current commands, approval checkpoints, and recovery actions.
ms.date: 2026-11-21
---

## Fast Pass operations

Start with the [numbered customer journey](../README.md#start-here).
This reference covers current commands, not the engineering investigation.

## Configure and validate

Run PowerShell 7 from the repository root using the same interactive Azure/Fabric
user. Use the default ignored `deploy\config\customer.json` and `deploy\state`
paths. For a deliberate alternate configuration, supply `-ConfigPath` to every
command and exclude that file from Git before use. All configuration is nonsecret.

| Command | Action | Approval boundary |
| ------- | ------ | ----------------- |
| `validate` | Checks prerequisites without cloud writes | Administrator confirmations must be genuine |
| `deploy -AzureDeploymentName <record>` | Reuses Azure outputs and finishes Fabric | Approve workspace/items, publication and endpoint creation |
| `configure-network` | Discovers/reuses or creates only the vault managed endpoint | Approve creation; Azure owner approves connection separately |
| `configure-secret` | Prints secure Azure UI instructions; accepts no key | Customer enters the key privately and selects Create |
| `verify-secret` | Checks enabled/current secret metadata through ARM | Does not retrieve the value or prove runtime access |
| `run -ParametersPath .\deploy\config\smoke-run.json` | Private retrieval/authorization preflight, then bounded simulation | Separate paid-compute approval |
| `recover-run -RunId <expected-run-id>` | Validates and saves the recorded completed simulation result | Approve local state update; no compute or secret retrieval |
| `view-results` | Prepares only the owned Results notebook and verifies its source/bindings | Approve publication; no Spark job is submitted |
| `status` | Reads capacity, bindings, endpoint and recorded job state | Does not execute notebooks |

Prefix commands with `.\deploy.ps1`. Deployment success is not Fast Pass success:
complete the [map and SQL acceptance checks](../04-run-and-verify/manual.md#acceptance-checklist).

An optional CLI-only foundation path is `.\deploy.ps1 deploy -WhatIf`, then,
after explicit Azure/Fabric provisioning approval, `.\deploy.ps1 deploy`.
Choose it instead of the portal foundation step, not after a successful handoff.
It uses the current Bicep and nonsecret generated parameters. The Esri credential
must never be added to those parameters; use the separate secure UI step.

## Fabric managed private endpoint

Activation (`provisioningState`) and Azure approval (`connectionState.status`)
are separate. Continue only with **Succeeded / Approved**.

If approval is pending: Azure portal > the deployed Key Vault > **Networking >
Private endpoint connections**. Select the request matching the expected Fabric
endpoint and workspace, verify the vault and `vault` target, then the authorized
Azure owner selects **Approve**. Do not approve unrelated connections.

Run `.\deploy.ps1 configure-network` to resume only networking. Then rerun
`.\deploy.ps1 deploy -AzureDeploymentName '<same-record>'` to finish Fabric.
Neither action needs another Azure foundation deployment. See
[Stage 3](../03-finish-fabric/manual.md#step-18-run-the-fabric-finish-command-and-wait).

## Secure credential entry

Follow [Step 20](../03-finish-fabric/manual.md#step-20-securely-provide-the-esri-api-key).
Load [secret-setup.azuredeploy.json](./secret-setup.azuredeploy.json) into Azure
Custom deployment at the existing resource-group scope. Enter the key only in
the secure `esriApiKey` field. The template creates enabled `geoanalytics-api-key`
in the existing private vault and has no outputs.

Do not inspect, screenshot or automate credential entry with Copilot. Never put
the key in local configuration, parameter files, notebooks, widget state, Git,
chat, command arguments or logs. No local data-plane writer is supported.
Keep public vault access Disabled. No template-deployment flag, new networking,
roles or infrastructure are required by this credential template.

## Recover an interrupted run

If local polling or result retrieval fails after submission, inspect the recorded
job before doing anything else. Do not rerun `run`: it submits new jobs.
When the recorded simulation job is **Completed**, its result can be recovered:

```powershell
.\deploy.ps1 recover-run -RunId '<expected-run-id>'
```

Use the expected run ID from the original run evidence, not the previous
`lastResult` if that result belongs to an older run. Recovery accepts only the
manifest's recorded job in the original workspace/notebook. It verifies the
interactive identity, notebook/Lakehouse ownership, job completion, expected run
ID, six matching table names and integer counts. Required origin, grid and
daily-state outputs must be nonempty; an empty vulnerability summary is allowed.
All outputs must share a safe table prefix and the expected run ID.

After explicit approval, recovery saves only the validated result and update
timestamp through the nonsecret manifest writer. It preserves provisioning
milestones, job URI and historical preview state. Recovery does not require
active Spark capacity, submit or cancel jobs, retrieve secrets, republish Results,
or change the original command's failure evidence. A changed recorded job/result,
incomplete job, missing exit value or invalid output blocks persistence.

Expect exit `0`, the six outputs and `Recovered verified result for run ...`.
Recovery uses the same notebook-specific beta exit-value endpoint as normal
execution; unavailable exit values remain a blocker. Do not copy a receipt into
the manifest manually. Approve Results publication separately afterward, then
complete the independent Lakehouse, map and SQL checks for the recovered run.

## View results

After a verified bounded run, approve `.\deploy.ps1 view-results`.
It creates/updates only `<deploymentName> Results`; repeating publication can
replace custom viewer edits. It preserves simulation state and submits no
preview or simulation job. Open the printed notebook URL, then separately
approve paid compute and select **Run all** in Fabric.

The viewer reads the completed run's existing Lakehouse tables. It neither
retrieves the key nor writes tables, reruns GeoAnalytics or publishes to ArcGIS.
Expect gray grid cells, red reached cells and a blue origin. This is a local
projection without an external basemap. It supports bounded 2D POINT and
single-ring POLYGON data, at most 5,000 grid and arrival rows each.

Historical preview fields remain readable for existing deployment state.
A completed REST job alone does not establish visible-map acceptance.

## Removal and troubleshooting

| Symptom | Next action |
| ------- | ----------- |
| Capacity Inactive or unavailable | Ask its owner to resume the existing F capacity; charges restart. Do not recreate Environment |
| Endpoint Pending | Verify the exact request and obtain Azure approval, then network-only resume |
| Secret absent/disabled | Repeat the private secure UI step, then metadata-only `verify-secret` |
| Private runtime retrieval fails | Inspect approved endpoint, executing user's vault role and secret metadata; never enable public access |
| GeoAnalytics authorization fails | Esri owner checks entitlement/key; do not print the key |
| Job timeout | Inspect the recorded job before any new submission; timeout does not cancel it |
| Completed simulation but stale `lastResult` | Approve `recover-run -RunId <expected-run-id>`; do not resubmit compute or manually edit state |
| Map not visible | Open Results and Run all after approval; do not rerun the workload |
| SQL tables missing | Refresh and wait for metadata synchronization; do not rerun the simulation |
| Ownership/name collision | Stop and review the named resources; never adopt or overwrite unrelated items |

Automatic removal is unavailable. Follow the separately authorized
[cleanup guide](../04-run-and-verify/manual.md#cleanup-and-troubleshooting).
Do not delete or resize reused capacity.

## Engineering and maintenance

Historical experiments, rejected alternatives, API references and evidence
boundaries are preserved in [engineering validation notes](../engineering/validation-notes.md).
They are optional engineering evidence, not prerequisites. Run the offline suites
listed in [validation CI](../.github/workflows/validate.yml), including both compiled
template freshness checks, before publishing a new release.

The old immutable `v0.1.0` button is not the current private foundation entry.
Use the preferred commit-pinned **Deploy to Azure** button at
[Step 13](../02-deploy-azure/manual.md#step-13-load-the-private-template-and-enter-the-azure-parameters).
Manual Azure Custom deployment **Load file** using the same compiled foundation
remains the fallback. Both entry experiences still need new-customer validation.
No optional real-population run or production certification is claimed.
