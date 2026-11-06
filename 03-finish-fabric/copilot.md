---
title: 03 Finish Fabric - Copilot Fast Pass
description: Create the Fabric workspace items with Copilot and enter your Esri key safely.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## FP10 Review the initialized configuration and validation

| Checkpoint | Instruction                                                                                     |
| ---------- | ----------------------------------------------------------------------------------------------- |
| Where      | VS Code Chat, configuration editor and command output                                           |
| Do         | Approve initialization; review configuration/confirmation edits and validation                  |
| See        | Correct `customer.json`, Pass/Confirmed rows, and validate exit code `0`                        |
| Next       | [FP11](#fp11-approve-fabric-finish-and-inspect-the-deployed-items) only after validation passes |

Copilot verifies Azure state and identity, then proposes
`Initialize-Experience.ps1` using the record name and existing capacity GUID
where appropriate. Approve that command after reviewing its arguments.

See/expect: local `deploy\config\customer.json` is created without overwriting
an existing file. It contains no API key. Copilot should ask before changing
the five confirmation flags and map each to your actual FP08 approvals.
Confirm each one separately; Azure access alone does not cover all five.

Review the file in VS Code, including subscription/tenant IDs, capacity,
Azure names, generated Fabric names and each confirmation.
If Copilot presents edits, review/keep only the correct configuration changes.
The manual example is
[Step 16](./manual.md#step-16-review-names-and-enter-the-five-genuine-confirmations).
If a check fails, resolve the reported problem rather than changing the code
to skip it.

Copilot then runs `.\deploy.ps1 validate` and reads its exit code/details.
Expect automated `Pass`, approvals `Confirmed`, and exit `0`.
Exit `2` means missing manual confirmations; exit `1` is a failure.
Do not approve Fabric finish until the required checks/approvals are resolved.

## FP11 Approve Fabric finish and inspect the deployed items

| Checkpoint | Instruction                                                                                                 |
| ---------- | ----------------------------------------------------------------------------------------------------------- |
| Where      | VS Code Chat approval, then the created workspace in Fabric portal                                          |
| Do         | Approve the handoff command; inspect the expected Fabric items and status                                   |
| See        | `Configured`, runtime `1.3`, verified bindings, and the named items                                         |
| Next       | [FP12](#fp12-enter-the-esri-key-yourself-outside-copilot-tools) after setup succeeds; do not select Run all |

Copilot should show the exact target and proposed command:

```powershell
.\deploy.ps1 deploy -AzureDeploymentName '<actual-record-name>'
```

Confirm that it includes `-AzureDeploymentName`; bare deploy would provision
Azure again. It must summarize the workspace/items it will create/update and
that no notebook runs yet.
Repeat finish setup republishes the environment and can replace custom edits
to the deployment-owned notebook. Do not approve it merely to inspect a
previously configured workspace; use status instead.

For the current private-network implementation, finish can stop at the Azure
managed-private-endpoint approval checkpoint before importing/publishing items.
Follow the [approval and network-only resume reference](../deploy/README.md#fabric-managed-private-endpoint).
Request separate approval for `configure-network`; it can create an endpoint
but does not republish existing items or execute a notebook. Do not treat
activation Succeeded as approval Approved or as proof of secret retrieval.

After reviewing the proposal, tell Copilot:

```text
Approve Fabric finish for the displayed subscription, capacity and deployment.
Use the verified Azure handoff. Do not run any notebook yet.
```

Approve the corresponding terminal tool request only if its command matches.
Copilot waits for publication/import, checks exit code, and runs status.
Expect the configured success message, `"stage": "Configured"`,
`"runtimeVersion": "1.3"`, and `"notebookBindingsVerified": true`.

Open [Fabric](https://app.fabric.microsoft.com), sign in as the same deployment
user, select **Workspaces**, then your generated workspace name. Inspect its
Lakehouse, Environment and Notebook using
[manual Step 19](./manual.md#step-19-open-fabric-and-inspect-what-was-created).
Do not select **Run all**, manually import the original, or insert a key.
Tell Copilot whether you can see those items. This confirms the browser check
as well as the command results.

## FP12 Enter the Esri key yourself outside Copilot tools

| Checkpoint | Instruction                                                                                                            |
| ---------- | ---------------------------------------------------------------------------------------------------------------------- |
| Where      | Your visible PowerShell 7 terminal, never Chat                                                                         |
| Do         | You run `configure-secret` and enter the key at its hidden prompt                                                      |
| See        | `Secret stored; metadata access verified...` without the key being exposed                                             |
| Next       | [FP13](../04-run-and-verify/copilot.md#fp13-separately-approve-the-synthetic-run) after reporting success, not the key |

Copilot must pause here and give you this command to run in your visible
PowerShell 7 terminal:

```powershell
.\deploy.ps1 configure-secret
```

**You run it. Copilot must not run this interactive secret-entry command
through an agent tool.**

See/expect:

```text
Esri GeoAnalytics API key (hidden):
```

Paste/type the authorized Esri key at that terminal prompt and press Enter.
Never paste it into Copilot chat, an attached file, configuration JSON, a
notebook cell, or a browser form.
Expect:

```text
Secret stored; metadata access verified for the interactive user. Runtime access is checked during run.
```

Tell Copilot only:

```text
configure-secret completed with the Secret stored message. No key is in chat.
Proceed to the synthetic-run approval checkpoint, not to execution yet.
```

If the command failed, provide only the redacted error. Follow
[manual Step 20](./manual.md#step-20-enter-the-key-at-the-hidden-powershell-prompt).
Copilot must never request `az keyvault secret show`, raw secret GETs, clipboard
contents, or token output to diagnose this.
If a key was exposed in chat, stop and arrange revocation/rotation with its owner;
do not assume removing text makes the exposure safe.
