---
title: 04 Run and verify - Manual walkthrough
description: Run the small sample, open its tables and check the results in Fabric and SQL.
ms.date: 2026-11-04
---

[Stage overview](./README.md) | [Journey home](../README.md#start-here)

Run terminal commands from the main repository folder containing `deploy.ps1`,
not from this numbered subfolder.

## Prove the small synthetic workload

### Step 21 Submit the first run from PowerShell

Where to be: local PowerShell 7 at the repo root, with the synthetic file open.

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

Next: [Step 22](#step-22-watch-the-two-jobs-in-fabric) while it runs,
then [Step 23](#step-23-open-the-six-tables-and-onelake-receipt) after exit `0`.

### Step 22 Watch the two jobs in Fabric

Where to be: Fabric portal's notebook Recent runs or Monitor; keep PowerShell open.

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

| Error or symptom                                     | Owner/action                                                                                        |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| GeoAnalytics module unavailable                      | Fabric owner checks Step 10 effective setting and Runtime 1.3                                       |
| `Cannot retrieve geoanalytics-api-key`               | Azure/network owner checks executing user's vault Get access, secret existence and Spark networking |
| `GeoAnalytics authorization failed` / not authorized | Esri owner verifies the subscription/key; do not replace it with a generic ArcGIS key               |
| Spark cannot start / capacity unavailable            | Capacity owner checks active state, workloads, headroom and access                                  |
| Completed job but missing exit value                 | Inspect run details; beta exit-value retrieval is a documented accelerator limitation               |
| Command timeout                                      | Check current job status before rerunning; it may still be active                                   |

Next: [Step 23](#step-23-open-the-six-tables-and-onelake-receipt) only after
terminal success, not merely a green browser job.

### Step 23 Open the six tables and OneLake receipt

Where to be: local PowerShell for names, then the Fabric Lakehouse's Tables/Files.

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

| Suffix                          | What to inspect                                                   |
| ------------------------------- | ----------------------------------------------------------------- |
| `cells_daily`                   | Daily cell state; must be nonempty                                |
| `arrival`                       | First infested day and peak zombies for reached cells             |
| `front_daily`                   | Daily spread footprint/hull/center/reach/speed                    |
| `grid_population_vulnerability` | H3 grid and population/vulnerability attributes; must be nonempty |
| `origin`                        | Scenario origin; must be nonempty                                 |
| `vulnerability_summary`         | Quintile summary; can be empty for synthetic population           |

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

Next: [Step 24](#step-24-verify-the-sql-analytics-endpoint).

### Step 24 Verify the SQL analytics endpoint

Where to be: Fabric portal, in the created Lakehouse's SQL analytics endpoint.

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

Next: optionally [Step 25](#step-25-run-the-small-atlanta-real-population-scenario)
after synthetic verification, or the [acceptance checklist](#acceptance-checklist)
to finish with real-population validation marked `NOT RUN`.

### Step 25 Run the small Atlanta real-population scenario

Where to be: local PowerShell for submission, then Fabric to verify the new outputs.

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
See [architecture and next experiments](../05-next-steps/README.md).

Next: repeat [Steps 22-24](#step-22-watch-the-two-jobs-in-fabric) for this new run,
then complete the [acceptance checklist](#acceptance-checklist).

## Acceptance checklist

Before finishing, check each result below:

* [ ] Steps 04-12 approvals came from the correct owners, not inferred from login.
* [ ] Azure deployment succeeded and its outputs match the approved subscription/user.
* [ ] `validate` exits `0`.
* [ ] Fabric finish exits `0` and did not require another Azure deployment.
* [ ] Fabric workspace contains the expected Lakehouse, environment and notebook.
* [ ] Status shows runtime `1.3` and the notebook connected to the expected items.
* [ ] Secret is stored without exposing its value.
* [ ] The access check and sample-data run succeed, and `run` exits `0`.
* [ ] Six output tables and `result.json` are readable with required nonempty outputs.
* [ ] SQL table previews and row counts match the run summary.
* [ ] The optional real-population run succeeds, or is recorded as `NOT RUN`.

Keep your checklist and run IDs in your organization's approved storage. Do not post API keys,
bearer tokens, personal data or customer resource identifiers to public issues.
Leave any unfinished check unchecked.

To view completed results, open Fabric rather than repeating setup.
Repeating Fabric setup republishes the environment and updates the generated
notebook, which can replace your custom edits.

## Alternate path without the button

Skip this section if you followed the guided setup above.
If you prefer an advanced command-line-only setup, choose it **instead of**
the Azure button before starting. Its commands are in the optional
[technical reference](../deploy/README.md#configure-and-validate).
It is not a follow-up to a successful deployment.

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

## Continue to 05 Next steps

After completing the acceptance checklist, you may stop or open
[05 Next steps](../05-next-steps/README.md) for ideas to explore.
Review the target and costs before separately approving any new run.
