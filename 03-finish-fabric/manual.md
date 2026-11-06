---
title: 03 Finish Fabric - Manual walkthrough
description: Create the Fabric workspace items and store the Esri key using a hidden prompt.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## Initialize the local handoff

### Step 15 Generate the nonsecret local configuration

Where to be: local PowerShell 7 at the cloned repository root.

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

Next: [Step 16](#step-16-review-names-and-enter-the-five-genuine-confirmations).

### Step 16 Review names and enter the five genuine confirmations

Where to be: local PowerShell to open the generated JSON in Notepad.

Open the generated local file:

```powershell
notepad .\deploy\config\customer.json
```

See/expect: JSON containing subscription/tenant GUIDs, Azure names, Fabric item
names, a `capacity` object, and the following `confirmations` object.
Compare the GUIDs/Azure names to your note. Keep the derived values unless
you have reviewed a deliberate change.

For ownership name `geo-atlanta-youralias-01`, generated names are:

| JSON field        | Expected generated name                 |
| ----------------- | --------------------------------------- |
| `workspaceName`   | `geo-atlanta-youralias-01 GeoAnalytics` |
| `lakehouseName`   | `Geo_geo_atlanta_youralias_01`          |
| `environmentName` | `geo-atlanta-youralias-01 Runtime 1.3`  |
| `notebookName`    | `geo-atlanta-youralias-01 Demo`         |

Record your actual four names. Names change with your ownership name.
Use fresh names; unowned existing workspaces/items cannot be adopted.

Change each flag to `true` **only** when its preceding approval was obtained:

| Confirmation field          | What must actually be confirmed                              |
| --------------------------- | ------------------------------------------------------------ |
| `geoAnalyticsEnabled`       | Step 10 effective tenant/capacity integration setting        |
| `esriEntitlement`           | Step 11 active entitlement and the correct API key available |
| `workspaceCreationAllowed`  | Steps 07-08 your user's allowed workspace/item creation      |
| `capacityAssignmentAllowed` | Step 09 capacity assignment rights for your user             |
| `azureDeploymentAllowed`    | Steps 04 and 12 deployment, RBAC, policy and cost approval   |

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

Next: [Step 17](#step-17-run-prerequisite-validation-and-read-the-result).

### Step 17 Run prerequisite validation and read the result

Where to be: local PowerShell 7 at the repo root, after saving `customer.json`.

```powershell
.\deploy.ps1 validate
$LASTEXITCODE
```

See/expect: a table with columns `Check`, `Status`, `Detail`. Automated checks
should show `Pass`; the five approvals should show `Confirmed`.
The exit code must be `0` before continuing.

| Exit/result                                    | Do this                                                                                                                           |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `0`                                            | Continue to Step 18                                                                                                               |
| `2` or `Manual` rows                           | Return to Steps 04-12; obtain missing approvals, then update only their flags                                                     |
| `1` or `Fail` rows                             | Read that row's detail; resolve the named tool, sign-in, provider, region, capacity, ownership or API-access problem              |
| JSON parse error                               | Reopen `customer.json`, fix JSON syntax, and rerun                                                                                |
| Azure/Fabric 401/403 or consent-required error | Ask identity/Fabric administrator to approve the interactive CLI access; do not enable service-principal settings as a workaround |

Validation is read-only: it neither provisions resources nor starts Spark.
It cannot conclusively verify all policies, permissions, entitlement or
capacity headroom through reads alone.

Next: [Step 18](#step-18-run-the-fabric-finish-command-and-wait) only after exit `0`.

## Finish Fabric setup

### Step 18 Run the Fabric finish command and wait

Where to be: local PowerShell 7, with the recorded Azure deployment name ready.

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

Next: [Step 19](#step-19-open-fabric-and-inspect-what-was-created).
Now return to the Fabric browser tab.

### Step 19 Open Fabric and inspect what was created

Where to be: Fabric portal's created workspace, then PowerShell for status.

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

Next: [Step 20](#step-20-enter-the-key-at-the-hidden-powershell-prompt).
Leave the workspace browser tab open.

## Configure the Esri key

### Step 20 Enter the key at the hidden PowerShell prompt

> [!IMPORTANT]
> The current private-network implementation adds a manual Azure approval
> checkpoint before Fabric finish. If it stops for a Pending managed endpoint,
> use [the managed endpoint approval and resume instructions](../deploy/README.md#fabric-managed-private-endpoint).
> Endpoint approval alone does not provision a key. The Python setup notebook
> is a later implementation stage; the local secret command below still
> requires an approved private network path.

Where to be: your visible local PowerShell 7 terminal, not chat or a notebook cell.

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

Next: [Step 21](../04-run-and-verify/manual.md#step-21-submit-the-first-run-from-powershell).
