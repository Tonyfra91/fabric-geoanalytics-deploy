---
name: fabric-geoanalytics-fast-pass
description: "Use when explicitly asked to start or resume Copilot Fast Pass for this repo's Azure-button and Fabric GeoAnalytics accelerator. Guide local preparation, approved Fabric setup, secret-safe manual handoff, bounded runs and evidence checks; stop at cloud and compute approval checkpoints."
user-invocable: true
disable-model-invocation: false
---

# Fabric GeoAnalytics Fast Pass

## Scope and source of truth

Run the repository's existing experience in a local VS Code Copilot Agent
session. Prefer explicit invocation; discovery may also select it for a matching
user request. Loading the skill is not unattended authorization.
Use [the Fast Pass guide](../../../01-start-here/copilot.md) for user-facing
instructions and [the manual walkthrough](../../../01-start-here/manual.md)
for exact screens, fields, prerequisites and expected results.
Read the relevant stage file before executing each stage. The first file
contains preparation only; it is not the complete deployment guide.

| Journey folder    | Copilot instructions                               | Manual screen reference                                            |
| ----------------- | -------------------------------------------------- | ------------------------------------------------------------------ |
| 01 Start here     | [FP01-FP08](../../../01-start-here/copilot.md)     | [Steps 01-12](../../../01-start-here/manual.md)                    |
| 02 Deploy Azure   | [FP09](../../../02-deploy-azure/copilot.md)        | [Steps 13-14](../../../02-deploy-azure/manual.md)                  |
| 03 Finish Fabric  | [FP10-FP12](../../../03-finish-fabric/copilot.md)  | [Steps 15-20](../../../03-finish-fabric/manual.md)                 |
| 04 Run and verify | [FP13-FP16](../../../04-run-and-verify/copilot.md) | [Steps 21-25 and acceptance](../../../04-run-and-verify/manual.md) |

Keep the whole repository open in VS Code and run commands at its root.
The numbered folders organize instructions; do not change the terminal's
working directory into one of them.

Use these existing entry points, not replacement provisioning logic:

* [Pinned demo retrieval](../../../Get-DemoNotebook.ps1)
* [Azure handoff initializer](../../../Initialize-Experience.ps1)
* [Lifecycle commands](../../../deploy.ps1)
* [Synthetic inputs](../../../deploy/config/smoke-run.json)
* [Real-population inputs](../../../deploy/config/real-run.json)
* [Operations reference](../../../deploy/README.md)

The source demo's model is retained with bounded inputs. Do not promise
identical large-run results, original inline maps, GeoParquet presentation,
ArcGIS publication, semantic models, or production certification.

## Operating rules

* Ask for one missing input or approval at a time. Give the user the action,
  expected screen/prompt/result, stop condition, and next action.
* Maintain a chat checkpoint table with `VERIFIED`, `AWAITING YOU`,
  `BLOCKED`, or `NOT RUN`, and evidence. Do not create tracking Markdown files.
* A starting request authorizes read-only checks and local preparation only.
  Do not treat tool approval or “do all of it” as permission for every cloud stage.
* Obtain separate explicit approvals for Fabric creation/update, the synthetic
  run, and the real-population run. State exact target, command, inputs and costs.
* The user presses the unchanged Azure button and selects Create after
  prerequisites and parameter review. Do not click Create, invoke bare
  `deploy`, run CLI Azure provisioning, or modify Bicep/template/button URLs.
* Never request or inspect passwords, MFA/device codes, bearer tokens, API keys,
  clipboard contents or secret values. Never run token-output commands,
  `az keyvault secret show`, raw secret GETs, or secret-entry tools.
* Never run `configure-secret` yourself. The user runs it in their visible
  terminal and enters the key at the hidden prompt, outside agent tools/chat.
  Ask only whether its documented success message appeared.
* Do not set all confirmations true by inference. Map each flag to explicit
  administrator/customer confirmation; reads do not prove permission/licensing.
* Check every command's exit code and relevant output. Stop on errors, failed/
  manual prerequisite rows, unknown state, or missing expected output. Do not
  silently change inputs, catch/ignore failure, or declare a green job sufficient.
* Keep Manual permissions enabled. Skill instructions are not security enforcement.
  Do not bypass policy, install software without approval, elevate privileges,
  grant roles, register providers, or retag/adopt unrelated resources.
* Do not change accelerator source to bypass failures. Limit file edits to
  reviewed nonsecret customer configuration; never overwrite an existing config.
* Never delete resources, alter an existing capacity's lifecycle/SKU, discard
  user changes, commit/push local configuration/state, or publish customer evidence.
* Do not automatically retry submissions. A timeout/stop can leave a live job;
  inspect the recorded job first and obtain new approval before another submission.

## Phase 1 Prepare without cloud writes

1. Confirm the workspace root contains `deploy.ps1`, the initializer and the
   numbered journey folders.
   Inspect Git status, existing configuration and manifest presence. Do not
   open an unrelated root or reset changes. Use PowerShell 7 on Windows.
2. Check PowerShell, Git, Azure CLI, Bicep 0.48.1 and Python. Missing tools
   are blockers with FP02/manual Step 01 installation instructions.
3. Obtain the local pinned notebook with `.\Get-DemoNotebook.ps1`; run
   `.\deploy\tests\Test-Accelerator.ps1`,
   `.\deploy\tests\Test-Experience.ps1`, and
   `.\deploy\scripts\Build-Template.ps1 -Check`. Do not interpret mocks as live proof.
4. Read Azure account metadata and compare with the user's intended subscription/
   tenant. If sign-in/MFA is needed, show the manual commands and pause while
   the user runs them. Do not collect authentication secrets/codes.
5. Collect expected nonsecret GUIDs, capacity/region and fresh Azure names.
   Read capacity metadata, check provider registration and name availability.
   Default to an existing active supported F capacity; new capacity requires
   explicit administrator/cost/quota approval.
6. Confirm each manual prerequisite: user permissions, item/workspace creation,
   capacity assignment, effective GeoAnalytics setting, Esri entitlement/key
   availability, networking and cost/policy approval. Do not request the key itself.

Stop at `BLOCKED` or `AWAITING YOU` for any unresolved requirement.
When ready, proceed to the user-controlled Azure step, not a cloud tool call.

## Phase 2 Guide the Azure button and verify its handoff

1. Show the exact portal parameter table based on verified values and the user's
   signed-in object ID. Explain subscription deployment record name versus
   template ownership `deploymentName`.
2. Direct the user to README's unchanged Deploy to Azure button and manual
   Steps 13-14. The user signs in, enters fields, reviews costs and selects Create.
3. Wait for the user to report success and the subscription deployment record name.
   Read the actual deployment metadata/outputs. Verify success, version, identity,
   subscription, vault outputs and capacity choice through the existing helpers.
4. Propose and run `.\Initialize-Experience.ps1 -AzureDeploymentName <record>`
   with `-ExistingCapacityId <guid>` only for existing-capacity mode.
   Do not overwrite existing configuration. On resume, inspect and validate it.
5. Explain each generated Fabric name and confirmation flag. Ask before edits;
   set only flags backed by the user's explicit prerequisite confirmations.
6. Run `.\deploy.ps1 validate` and inspect the table/exit code.
   Exit 1 blocks progress; exit 2 requires real approvals, not flag bypassing.

Stop for the Fabric finish approval after validation exits 0.

## Phase 3 Obtain approval and finish Fabric

1. State exact subscription, capacity, deployment record and planned Fabric item
   names, expected mutations, and that deployment will not execute a notebook.
   Explain that repeat finish republishes the environment and can replace
   custom edits to the owned notebook; do not use it for read-only inspection.
2. Request explicit approval for Fabric finish. After approval, run only
   `.\deploy.ps1 deploy -AzureDeploymentName <verified-record>`.
3. Wait for environment publication/import and check exit code and documented
   configured success message. On failure, explain the specific error and
   retained milestones; do not rerun automatically or redeploy Azure.
4. Run `.\deploy.ps1 status`. Verify Configured stage, Runtime 1.3 and notebook
   bindings. Provide workspace/item names for the manual Step 19 UI inspection.
5. Ask the user to inspect the created Fabric items; record that evidence separately.

Stop for the user's secret-entry handoff.

## Phase 4 Hand secret entry to the user

1. Tell the user to run `.\deploy.ps1 configure-secret` themselves in the visible
   PowerShell 7 terminal. Do not execute it through a tool.
2. Explain the exact `Esri GeoAnalytics API key (hidden)` prompt and documented
   success text. The key goes only into that prompt, never chat or files.
3. Wait for the user to confirm success, not disclose the key.
   For failure, use only redacted errors and metadata/access/network guidance.
4. If a key is exposed, do not repeat it. Stop and direct its owner to revoke/
   rotate it; do not promise to erase an exposure by deleting chat text.

Stop for synthetic compute approval; secret success is not authorization to run.

## Phase 5 Approve, execute and verify bounded runs

1. Show the synthetic file and exact command/target. Explain two-day, 10 km,
   H3 6, synthetic population, seed 42, overwrite false, Spark costs, and the
   preflight-then-simulation sequence.
2. Obtain explicit approval for one synthetic run. Execute
   `.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json`.
3. Track the single execution and existing job, not duplicate submissions.
   Verify exit 0, preflight/simulation completion, requested run ID and six
   outputs. The script's receipt/read-back contract is authoritative.
4. Run status and read the existing nonsecret manifest's `lastResult`.
   Supply actual run/table names, counts and receipt path.
   Required origin, grid and daily-state outputs must be nonempty.
   Do not fail a valid empty synthetic vulnerability summary.
5. Guide the user through manual Steps 23-24 for Lakehouse/receipt and SQL checks.
   Do not claim SQL/UI verification without observed results or user confirmation.
6. Offer the real-population stage only after synthetic verification. Display
   `real-run.json` with Atlanta coordinates, three days, 10 km, H3 6, real
   population and overwrite false. Confirm external-source readiness.
7. Obtain separate explicit approval for one real-population run, then execute
   `.\deploy.ps1 run -ParametersPath .\deploy\config\real-run.json`.
   Verify the new run separately. Do not scale to the upstream defaults,
   switch failed real inputs to synthetic, or claim a declined run completed.

## Phase 6 Summarize or resume

Report verified stages, command/exit evidence, manual confirmations, current
run IDs and table counts, blockers, and checks `NOT RUN`. Use the manual
acceptance checklist. Distinguish local tests from live acceptance and
script-verified Spark outputs from manually verified SQL/browser evidence.

On resume, read the existing configuration/manifest and verify the original
user/tenant first. A configured manifest does not mean a secret/run succeeded.
If status verifies the configured deployment, skip another finish operation
and ask about the next unverified stage rather than republishing by default.
A `lastJobUri` may still be active; inspect it without resubmitting.
Re-establish current-session approval before another mutation or compute stage.
Never edit state to skip milestones. Guide separately approved cleanup to
the manual reference; do not execute deletion.
