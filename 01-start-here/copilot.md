---
title: 01 Start here - Copilot Fast Pass
description: Prepare your computer and accounts, then start guided setup with Copilot.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.


## Use Copilot as your deployment guide

This is the recommended route. Read one step, do the named action,
and let **GitHub Copilot in VS Code on your computer** run the repeatable
commands. You do not need to know Azure administration, Fabric REST, or Bicep
syntax. You will need the Azure/Fabric permissions and Esri license listed
below. Copilot helps you check them, but cannot grant access or supply a license.

The [manual walkthrough](./manual.md) is the detailed screen-by-screen
reference and fallback, not a second deployment you need to run.

Both routes set up the same model and a small synthetic run, with an optional
Atlanta real-population experiment. You will inspect results in Fabric tables and SQL,
not Sean's original map or optional ArcGIS publication. See
[what the test reproduces](./manual.md#what-this-test-reproduces).

### Who does what

| Copilot does                                                         | You do                                                             |
| -------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Check versions, repo state, account metadata and accessible capacity | Install/approve missing software and complete sign-in/MFA          |
| Prepare a nonsecret portal parameter table                           | Load the private compiled template, review values and select Create |
| Read successful Azure deployment state and prepare configuration     | Confirm the five real prerequisite approvals and review edits      |
| Run validation and the approved Fabric finish command                | Approve creation/update of Fabric items                            |
| Verify metadata and run approved preflight/simulation jobs           | Enter the Esri key privately in Azure's secure field and approve compute |
| Extract actual run/table names and explain SQL checks                | Inspect Fabric UI and confirm Lakehouse/SQL visibility             |

Keep **Manual permissions** enabled and review each command before approving it.
The skill tells Copilot how to help; it does not prevent it from making a
mistake. Do not select blanket approval or unattended permissions.

**Do this now in Chat** when a command is proposed: reply with approval for
that exact command and scope, then approve its matching terminal tool request.
Copilot executes it in a PowerShell terminal; Chat is not a shell. Do not also
run it manually. Sign-in/MFA and private key entry remain your actions.
Expected: one execution. Stop if the target or arguments differ.

### Fast Pass sequence

[![Five numbered folders: start here, deploy Azure, finish Fabric, run and verify, next steps](../docs/images/accelerator-journey.svg)](../docs/images/accelerator-journey.svg)

Read 01-03 across the top, then 04-05 across the bottom; click for full size.
Follow FP01-FP08 here, then use the Next links to continue through folders
02-04. Do not perform a second manual deployment. Each step starts with
a checkpoint card: **Where**, **Do**, **See**, and a clickable **Next**.
Do not continue when its success condition has not been met.

## FP01 Check what you need before opening Copilot

| Checkpoint | Instruction                                                                          |
| ---------- | ------------------------------------------------------------------------------------ |
| Where      | Your computer, with your private access/approval notes                               |
| Do         | Review the checklist below and note anything you still need to confirm |
| See        | You know which accounts, approvals and license to check |
| Next       | [FP02](#fp02-install-vs-code-and-the-local-tools) to prepare your computer |

Check that you have, or know whom to ask for, the following:

* A Windows computer permitted to install/run VS Code, PowerShell 7, Git,
  Azure CLI, Bicep and Python
* A GitHub account with approved Copilot access and available usage allowance
* Your work/school Azure/Fabric deployment user, tenant GUID and subscription GUID
* Permission to run subscription deployments, create the dedicated resource
  group/private Key Vault/networking, and create the vault role assignment
* Registered `Microsoft.KeyVault` and `Microsoft.Network` providers;
  `Microsoft.Fabric` only for explicitly approved new-capacity creation
* Permission to create a dedicated Fabric workspace and Fabric items
* An approved active F capacity, its Fabric GUID/region, and assignment rights
* Effective **ArcGIS GeoAnalytics for Fabric Runtime** enablement
* An active **ArcGIS GeoAnalytics for Microsoft Fabric** entitlement and its
  authorized API key available through an approved secret-sharing channel
* Approved computer/Spark networking and costs

Your GitHub Copilot account can differ from your Azure/Fabric account.
The Azure browser, Fabric browser and Azure CLI must all use the **same**
deployment user/tenant. A Copilot plan supplies neither Azure nor Fabric access.

Choose a non-production/test Azure subscription where you can create the
Fast Pass resources. Follow
[manual Step 03](./manual.md#step-03-choose-the-user-tenant-and-azure-subscription)
to select it and Step 04 to verify the required permissions. If your organization
requires Azure deployment approval, use the subscription your Azure administrator
has approved for this evaluation. If you are unsure which subscription your
organization allows you to use, stop here and confirm the subscription with
your Azure administrator before continuing.

You do not need to collect every ID before installing the tools. Continue
with local preparation below; FP08 helps you find the values and confirm
access. For missing permissions, use the
[administrator request in manual Step 12](./manual.md#step-12-confirm-networking-costs-and-administrator-approvals).
Wait for the required approvals before continuing to Azure deployment.
Do not ask Copilot to assume permissions or treat a successful sign-in as approval.
Use an organization-approved Copilot account and data-handling policy;
even nonsecret tenant/resource configuration can be organization-sensitive.

See/expect: a checklist of what you have and what is still needed. Nothing
has been deployed.

## FP02 Install VS Code and the local tools

| Checkpoint | Instruction                                                              |
| ---------- | ------------------------------------------------------------------------ |
| Where      | Your Windows computer and approved installer pages                       |
| Do         | Install/open VS Code and verify the five local tools                     |
| See        | VS Code opens; version checks succeed, including PowerShell 7            |
| Next       | [FP03](#fp03-clone-and-open-the-correct-repository) after the tools work |

1. Open [Download Visual Studio Code](https://code.visualstudio.com/Download).
2. Select the appropriate **Windows** installer for your computer and follow
   the installation prompts. If your organization deploys VS Code centrally,
   use that approved installation instead.
3. Open **Visual Studio Code** from Start.
4. Install/check the remaining tools using
   [manual Step 01](./manual.md#step-01-install-and-verify-the-tools).
   That step has the installer links and version commands for PowerShell 7,
   Git, Azure CLI, Bicep CLI 0.48.1 or later and Python 3.12.
   The accelerator was originally validated with Bicep CLI 0.48.1.
5. Close/reopen VS Code after installations so it inherits the updated PATH.

See/expect: VS Code opens and the tools are available. No local Spark or
GeoAnalytics installation is required. Stop if installation is blocked by policy;
ask IT instead of bypassing it.

## FP03 Clone and open the correct repository

| Checkpoint | Instruction                                                           |
| ---------- | --------------------------------------------------------------------- |
| Where      | VS Code Command Palette, then the cloned repository's Explorer        |
| Do         | Clone the URL below and open its root folder                          |
| See        | `deploy.ps1`, `docs` and `.github` in the same open root              |
| Next       | [FP04](#fp04-sign-into-github-copilot) after the correct repo is open |

In VS Code:

1. Press **Ctrl+Shift+P** to open the Command Palette.
2. Type **Git: Clone** and select that command.
3. Paste this URL and press Enter:

```text
https://github.com/Tonyfra91/fabric-geoanalytics-deploy.git
```

4. Choose a writable local parent folder in the folder picker.
5. When VS Code offers to open the cloned repository, select **Open**.
   Otherwise use **File > Open Folder** and select `fabric-geoanalytics-deploy`.
6. Review the repository before trusting it. If the trust notification appears,
   use **Manage > Trust** (or the direct trust option in your version) only
   if permitted by your organization.

See/expect: Explorer shows `README.md`, `deploy.ps1`, `Initialize-Experience.ps1`,
`Get-DemoNotebook.ps1`, `deploy`, `docs`, and `.github`.
Open the **repository root**, not `deploy`, the original zombie-demo repo,
or a folder containing multiple unrelated projects.

This uses the current checkout's Fast Pass and private compiled template.
The older `v0.1.0` tag does not contain the skill or private foundation.
If a clone already exists, open it, inspect its Git status, and update a clean
checkout deliberately. Do not reset/discard another person's changes.
If **Git: Clone** is missing, fix Git installation and restart VS Code.

For a **fresh installation**, clone into a new isolated folder; do not reuse
the earlier demo's configuration/state or infer readiness from its success.
For **resume**, use the original clone/configuration and the
[read-only resume checkpoint](../04-run-and-verify/copilot.md#fp16-finish-with-evidence-or-resume-safely).
In a multi-root workspace, use **Remove Folder from Workspace** for the old
checkout, or open the fresh root alone. This does not delete its files.

Cloning downloads a local copy; it does not create a new GitHub repository or
automatically create a new branch. A second clone in a different folder still
points to the same GitHub repository by default. Renaming that folder does not
change this connection. Local edits stay local until committed and pushed.
If permitted, a push to `main` from either clone updates the same published
`main`; a new folder is not protection against this.
No commit or push is needed for Fast Pass. See
[what cloning changes](manual.md#what-cloning-changes) for the Git terms.

If **Git: Clone** fails, or the folder is empty despite reported success,
stop before FP04. Check **View > Output**, select **Git**, and locate the actual
destination folder. Do not share credentials or sign-in codes from output.
If the verified clone exists elsewhere, open it rather than cloning again.
Otherwise use the [safe terminal fallback](manual.md#if-cloning-fails), then
verify the root and required files before continuing. Never clone inside
another repository, delete its files, or treat an unverified result as success.

## FP04 Sign into GitHub Copilot

| Checkpoint | Instruction                                                                |
| ---------- | -------------------------------------------------------------------------- |
| Where      | VS Code Accounts/Copilot controls and the sign-in browser                  |
| Do         | Sign in with your approved GitHub Copilot account, then return to VS Code  |
| See        | Copilot Chat is available under the intended GitHub account                |
| Next       | [FP05](#fp05-open-a-powershell-7-terminal) after Copilot sign-in completes |

1. In VS Code, find the Copilot icon/status control and select **Use AI Features**
   or **Sign in to use Copilot**, depending on your version.
2. Alternatively, open the Command Palette and run **GitHub Copilot: Sign in**,
   or use **Accounts > Sign in with GitHub to use GitHub Copilot**.
3. Follow the browser sign-in prompt using the GitHub account with your
   approved Copilot access. Complete any organization SSO/approval requirements.
4. Return to VS Code and accept the sign-in completion/open-VS-Code prompt
   where displayed.

If Copilot commands/features are absent, use **Extensions** (**Ctrl+Shift+X**),
find **GitHub Copilot Chat** from publisher **GitHub**, and install/enable it
through your approved process, then reload VS Code.
Do not install a similarly named third-party deployment extension.

See/expect: Chat is available and the intended GitHub account is signed in.
If Copilot reports an organization policy restriction or exhausted allowance,
resolve it with your account owner or use the manual route.
Reference: [Official Copilot setup](https://code.visualstudio.com/docs/setup/copilot).

## FP05 Open a PowerShell 7 terminal

| Checkpoint | Instruction                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------- |
| Where      | VS Code's integrated terminal, at the repository root                                                   |
| Do         | Select PowerShell 7 and run the location/version/file checks below                                      |
| See        | Major version at least 7, the repo path, and `True` for `deploy.ps1`                                    |
| Next       | [FP06](#fp06-choose-a-local-copilot-agent-session-with-manual-permissions) after all three checks match |

1. In VS Code, select **Terminal > New Terminal**.
2. In the terminal profile dropdown, choose PowerShell 7 where available.
   Do not assume **Windows PowerShell** is version 7.
3. Check:

```powershell
$PSVersionTable.PSVersion
Get-Location
Test-Path .\deploy.ps1
git rev-parse --show-toplevel
git status --short
Test-Path .\.git
Test-Path .\Initialize-Experience.ps1
Test-Path .\.github\skills\fabric-geoanalytics-fast-pass\SKILL.md
```

See/expect: `Major` at least `7`, location and Git top-level equal to the
chosen checkout, and all file checks `True`. An empty folder or missing Git
metadata is a blocker even if cloning was reported successful. Stop and open
the actual clone. Once verified, do not repeat these checks at every checkpoint
unless the root/session changes.
If the terminal is PowerShell 5.1, run `pwsh` or select the installed
PowerShell 7 profile, then check again.

Keep this terminal for sign-in and the later secret prompt.
**Do not run `configure-secret` yet.**

## FP06 Choose a local Copilot Agent session with manual permissions

| Checkpoint | Instruction                                                                           |
| ---------- | ------------------------------------------------------------------------------------- |
| Where      | A fresh VS Code Chat session for this repository                                      |
| Do         | Choose local Copilot, Agent mode and Manual permissions                               |
| See        | The session is attached to this repo and tool approvals remain enabled                |
| Next       | [FP07](#fp07-start-fast-pass-without-authorizing-deployment) without blanket approval |

1. Press **Ctrl+Alt+I** to open Chat.
2. Select **+** to start a fresh chat for this repository.
3. Configure the session:

| Control                   | Choose                                                          |
| ------------------------- | --------------------------------------------------------------- |
| Environment, if displayed | **This Computer**, not a cloud coding agent or remote container |
| Session Target / harness  | **Copilot**                                                     |
| Agent / mode              | **Agent**, not Ask or Edit                                      |
| Language model            | **Auto**, or an organization-approved available model           |
| Permissions               | **Manual permissions**                                          |

Older versions may use **Agent** in an Ask/Edit/Agent dropdown and individual
tool approvals instead of the newer permission control. Keep approval prompts
enabled. Do not choose **Autopilot**, bypass, or blanket automatic approval.
Reference: [Official agent-session quickstart](https://code.visualstudio.com/docs/agents/quickstart).

See/expect: a local Agent session attached to this repo. It can request terminal
commands/file edits. That capability is not authorization to provision or run compute.

## FP07 Start Fast Pass without authorizing deployment

| Checkpoint | Instruction                                                                                                 |
| ---------- | ----------------------------------------------------------------------------------------------------------- |
| Where      | VS Code Chat input, not the PowerShell terminal                                                             |
| Do         | Select the skill and send the exact read-only starting message below                                        |
| See        | Copilot identifies the skill and proposes preparation, not deployment                                       |
| Next       | [FP08](#fp08-let-copilot-check-preparation-and-confirm-your-prerequisites) after skill loading is confirmed |

1. In Chat, type `/` and select **fabric-geoanalytics-fast-pass** from the menu.
2. Add the following starting message and send it:

```text
Start Copilot Fast Pass for this repository. I am new to Azure/Fabric
deployment. Follow the skill and 01-start-here/copilot.md.
Begin with read-only checks and local preparation only. Check the tools,
repository state and current sign-in. Ask for missing nonsecret values one
at a time. Do not create/update cloud resources, run Spark, retrieve secrets,
or assume prerequisite confirmations. Stop at each approval checkpoint.
```

See/expect: Copilot identifies the
[`fabric-geoanalytics-fast-pass` skill](../.github/skills/fabric-geoanalytics-fast-pass/SKILL.md),
starts preparation, and reports what it will check.
It must not begin Azure/Fabric creation or a notebook job from this message.

If the command is absent:

1. Open **Ctrl+Shift+P > Chat: Open Customizations > Skills**.
2. Check Workspace skills for `fabric-geoanalytics-fast-pass`.
3. Verify the open root contains
   `.github\skills\fabric-geoanalytics-fast-pass\SKILL.md`.
4. Update VS Code if required/approved, reload the window, and start a fresh chat.
5. If slash invocation is unavailable but file attachment is supported, attach
   that `SKILL.md` and this guide using **Add Context** (or `#file` selection),
   and explicitly ask Copilot to follow the attached skill with the starting
   message above. Confirm it read the file before allowing commands.

Do not substitute `/skills` and assume it launches the workflow;
that menu behaves differently across harnesses.
Select the skill explicitly rather than relying on automatic discovery.
If Copilot selects it for a matching request, that still authorizes only
read-only checks/local preparation, not cloud creation or compute.
Reference: [Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills).
If discovery/attachment remains unavailable, stop and use the manual guide.

## FP08 Let Copilot check preparation and confirm your prerequisites

| Checkpoint | Instruction                                                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Where      | VS Code Chat/tool approvals; use the terminal only for your sign-in                                                             |
| Do         | Review checks and supply requested nonsecret values/real confirmations                                                          |
| See        | Preparation is verified or clearly blocked; no cloud writes occurred                                                            |
| Next | [FP09](../02-deploy-azure/copilot.md#fp09-review-parameters-and-load-the-private-azure-template) only when preparation is ready |

Copilot checks your tools, the downloaded files and the deployment template.
It also runs the repository's local checks. Review each requested command
before approving it.
If a tool is missing, it should stop and give installation instructions, not
silently install software or change organization policy.

If Azure CLI is not signed into the deployment account selected in Step 03,
Copilot gives you
sign-in commands. **You** run them in the visible terminal and complete
browser/Windows sign-in and MFA. Follow
[manual Step 03](./manual.md#step-03-choose-the-user-tenant-and-azure-subscription).
It must not ask for your password, MFA code, device code or access token in chat.

Supply only requested nonsecret values, one at a time:

* Expected tenant/subscription GUIDs and deployment user
* Existing Fabric capacity GUID and region, or an explicitly approved new-capacity plan
* Fresh ownership, dedicated group and available vault names
* The five prerequisite approvals, based on your actual administrator/Esri confirmations

If you do not know an ID, ask Copilot to help you find it using
[manual Step 03 for your account and subscription](./manual.md#step-03-choose-the-user-tenant-and-azure-subscription)
and [manual Step 09 for capacity details](./manual.md#step-09-confirm-capacity-access-assignment-rights-and-region).
Keep these values in a private note. Never send the Esri key.

See/expect: tool/test results, account/capacity checks, and a checkpoint table:

| Status         | Meaning                                                           |
| -------------- | ----------------------------------------------------------------- |
| `VERIFIED`     | A command/API result or your explicit manual evidence supports it |
| `AWAITING YOU` | Sign-in, a missing value, a manual action or approval is needed   |
| `BLOCKED`      | A failure or unavailable prerequisite prevents progress           |
| `NOT RUN`      | The stage has not happened                                        |

The local suites should pass their HTTP compatibility, accelerator, handoff,
documentation/template and managed private endpoint checks. Counts change
with regressions; use the suite's final PASS and exit code, not historical totals.
These confirm the files are ready;
you still need to confirm your access and check the deployed results later.
If an approval is missing, resolve it using
[manual prerequisite instructions](./manual.md#step-04-confirm-azure-deployment-and-role-assignment-permissions).

### Approval matrix before FP09

FP08 is interactive preparation, not automatic approval of deployment or compute.
Record nonsecret owner confirmation and scope in approved private notes:

| Category | Responsible owner | Acceptable evidence | Read-only checks versus attestation |
| -------- | ----------------- | ------------------- | --------------------------------- |
| Azure deployment, RBAC, providers, policy and costs (`azureDeploymentAllowed`) | Azure subscription/RBAC and cost owners | Scoped active role/access review and explicit deployment/policy/cost approval | CLI checks identity/providers/names; policy, quota and role conditions need owner review |
| Workspace and items (`workspaceCreationAllowed`) | Fabric tenant administrator | Effective settings for this user/group; workspace/item creation allowed | UI/API access alone does not prove creation policy |
| Capacity assignment (`capacityAssignmentAllowed`) | Selected capacity owner | Capacity Admin/Contributor assignment rights and workload approval | API verifies GUID, F SKU, Active and region; visibility does not prove rights/headroom |
| GeoAnalytics (`geoAnalyticsEnabled`) | Fabric tenant/capacity administrator | Effective integration enablement for selected capacity/user | Owner confirmation; authorization is tested later by preflight |
| Entitlement (`esriEntitlement`) | Esri subscription owner | Active GeoAnalytics entitlement and authorized key available privately | No key inspection in Chat; generic basemap keys do not qualify |
| Network allocation and source access | Network owner | Exact VNet/subnet CIDRs approved, subnet contained, no overlap; required outbound paths allowed | Read-only subscription VNet inventory is useful but not the organization's address-allocation inventory |

**Do this now in Chat:** ask Copilot to inventory visible subscription VNet
address spaces read-only, compare the exact proposed CIDRs, and show the result
to the network owner. The default `10.0.0.0/16` can overlap an earlier demo.
Obtain explicit approval for replacement ranges against organizational
allocations/connected networks; do not guess unused space from an empty inventory.
Stop on overlap, missing owner approval or unavailable evidence.

**01 Start here is complete** only after this preparation is verified.
**Do this now in the same Chat:**

```text
FP08 preparation is complete. Continue to 02 Deploy Azure / FP09.
Show the reviewed portal parameter table with subscription name and ID,
literal resource names and owner-approved CIDRs. Do not deploy or run compute.
```

Expected: the FP09 table. Deployment, Fabric finish, endpoint approval, secret
entry, simulation and viewer compute each retain their separate approvals.
