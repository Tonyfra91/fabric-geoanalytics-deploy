---
title: 04 Run and verify - Copilot Fast Pass
description: Approve the small sample run, inspect its results and choose whether to try real data.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## FP13 Separately approve the synthetic run

| Checkpoint | Instruction                                                                                        |
| ---------- | -------------------------------------------------------------------------------------------------- |
| Where      | VS Code Chat/tool approval and the existing command's output                                       |
| Do         | Approve one bounded synthetic run and let Copilot watch that submission                            |
| See        | Preflight and simulation succeed; exit `0` includes six verified outputs                           |
| Next       | [FP14](#fp14-read-the-actual-results-in-fabric-and-sql) after verification, not merely a green job |

Copilot should show `smoke-run.json` settings: two days, 10 km, H3 resolution 6,
synthetic population, seed 42, overwrite disabled. It explains that the command
uses paid Spark capacity. It first runs an access check, called preflight,
then submits the simulation if that check passes.

After reviewing that proposal, tell it:

```text
Approve one synthetic run using deploy/config/smoke-run.json for the verified
workspace and capacity. Keep overwrite disabled. Do not submit a real-data run.
```

The proposed command is:

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\smoke-run.json
```

Review and approve the matching tool request. Copilot watches that execution,
not a second submission. Expect two jobs when preflight succeeds and exit `0`
with run ID and six verified output names/counts.
For what each message means, use
[manual Steps 21-22](./manual.md#step-21-submit-the-first-run-from-powershell).

If preflight fails, no simulation should be submitted. If a command times out,
Copilot must inspect the existing job and stop, not automatically resubmit.
An empty synthetic vulnerability summary is allowed; required origin/grid/
daily-state outputs must be nonempty.

## FP14 Read the actual results in Fabric and SQL

| Checkpoint | Instruction                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Where      | Your Fabric Lakehouse, receipt preview and SQL analytics endpoint                                                                                 |
| Do         | Open actual table names and compare SQL counts with the Spark receipt                                                                             |
| See        | Six readable outputs, matching counts and manually confirmed SQL visibility                                                                       |
| Next       | Optional [FP15](#fp15-separately-approve-the-small-atlanta-real-population-run), or [FP16](#fp16-finish-with-evidence-or-resume-safely) to finish |

Copilot runs status and reads the existing nonsecret manifest. It should supply:

* Your workspace URL and generated Lakehouse/notebook names
* The actual run ID, six full table names, and Spark read-back counts
* The run summary, `Files/zombie_outbreak/run_id=<actual ID>/result.json`
* SQL examples using actual table names, with the schema to verify in the explorer

You open the Lakehouse and SQL analytics endpoint and follow
[manual Steps 23-24](./manual.md#step-23-open-the-six-tables-and-onelake-receipt).
That reference covers each click, schema/table expansion, file preview,
**New SQL query**, **Run**, and comparison with receipt counts.

SQL tables may take a little longer to appear after the run. Tell Copilot
when you can see them and whether the row counts match the run summary.
Keep any remaining SQL check marked as incomplete until you have checked it.
You need no separate SQL database/client or ArcGIS publishing credentials.

## FP15 Separately approve the small Atlanta real-population run

| Checkpoint | Instruction                                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Where      | VS Code Chat approval, then Fabric verification for the new run                                                                            |
| Do         | Approve one bounded real-source run, or explicitly decline it                                                                              |
| See        | A new verified run ID/output set, or a clear `NOT RUN` status                                                                              |
| Next       | Repeat [FP14](#fp14-read-the-actual-results-in-fabric-and-sql) for the new names, then [FP16](#fp16-finish-with-evidence-or-resume-safely) |

This small run uses real US population and social-vulnerability data,
as in the source demo. It uses Atlanta coordinates, three days, 10 km, H3 resolution 6,
real population, seed 42, and overwrite disabled.
Confirm the public-source network and Esri prerequisites still hold.

After Copilot displays the file/target, tell it:

```text
Approve one real-population run using deploy/config/real-run.json in the same
verified workspace. Keep the bounded settings and overwrite disabled.
Do not increase to the upstream large-run defaults.
```

Review the tool request:

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\real-run.json
```

Expect another preflight/simulation pair, a new run ID, and six new outputs.
Repeat FP14 using the new names. An external service/schema failure must be
reported as a failure, not silently replaced with synthetic inputs.
Reference: [manual Step 25](./manual.md#step-25-run-the-small-atlanta-real-population-scenario).

You can decline this stage. Copilot then reports real-population validation
as `NOT RUN`, not completed.

## FP16 Finish with evidence or resume safely

| Checkpoint | Instruction                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------ |
| Where      | VS Code Chat's evidence summary and your private test records                                                      |
| Do         | Review verified, blocked and not-run stages; do not authorize another job                                          |
| See        | Evidence-backed results with unresolved checks stated explicitly                                                   |
| Next       | Use the [acceptance checklist](./manual.md#acceptance-checklist); stop or resume only from verified state          |

Ask:

```text
Summarize verified stages, manual confirmations, run IDs, table counts, blockers
and checks not performed. Do not provision, run another job, delete anything,
commit/push local state, or expose credentials.
```

Expect a summary of what worked, what you checked in Fabric and anything
still unfinished. Use the
[completion checklist](./manual.md#acceptance-checklist) before finishing;
successful local checks alone do not confirm a working cloud deployment.

To stop, select **Stop** in Chat. If a cloud job was already submitted, stopping
Copilot is not a guarantee that job was cancelled. Check its current status.

To resume in a fresh chat, invoke the same skill and say:

```text
Resume Copilot Fast Pass from the existing local configuration and manifest.
Perform read-only state/identity checks first. Do not overwrite configuration,
redeploy Azure, resubmit a possibly running job, or assume approvals from the
previous chat. Ask before the next mutation or compute stage.
```

Use the same deployment user and repo clone. Do not place secret values or
unredacted customer evidence into Git.
If status already verifies a configured deployment, Copilot should skip
another finish operation and ask about the next unverified secret/run stage.
Cleanup is separately owner-approved and manual:
[cleanup instructions](./manual.md#cleanup-and-troubleshooting).
The skill deliberately does not automate deletion.

## Continue to 05 Next steps

After completing the acceptance checklist, you may stop or open
[05 Next steps](../05-next-steps/README.md) for architecture and future experiments.
That optional reading is not authorization for another deployment or job.
