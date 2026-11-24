---
title: 05 Next steps
description: Choose separately approved, bounded GeoAnalytics experiments and stop safely.
ms.date: 2026-11-22
---

## 05 Next steps

Once you have checked your results in
[04 Run and verify](../04-run-and-verify/README.md), the guided setup is complete.
The bounded synthetic Fast Pass is complete. Everything below is **optional**
and separately approved. The goal remains reproducible ArcGIS GeoAnalytics
deployment and execution in Fabric, not new ingestion or publishing automation.

### Where

Open your results in Fabric and keep your run ID and table names handy.
There are no required commands in this step.

### Do

#### Test another scenario

**Do this now in your local editor:** copy `deploy\config\real-run.json` to a
separate nonsecret input, for example `deploy\config\city-run.local.json`.
Check `git check-ignore` before use; if needed exclude only that file through
local `.git\info\exclude`. Keep it untracked; do not blanket-stage with
`git add .` or `git add -A`. Do not modify the supplied baseline or put secrets,
tenant/resource/job identifiers or customer data in the input.

Choose a supported **US city** for the current census/SVI sources and set
explicit `OUTBREAK_LAT`, `OUTBREAK_LON` and `OUTBREAK_NAME`. Keep three days, 10 km,
H3 resolution 6, seed 42, real population enabled and `OVERWRITE=false`.
Record Runtime 1.3, capacity SKU and input scope in approved private evidence.
Check source coverage/schema and obtain separate network/source and compute
approvals before submission.

**Do this now in Chat** on the Copilot route: ask to review that exact file and
target, then approve **one** bounded run and its matching terminal request.
On the manual route, after approval run in PowerShell:

```powershell
.\deploy.ps1 run -ParametersPath .\deploy\config\city-run.local.json
```

Expected: preflight and simulation complete, six verified outputs and receipt,
real enrichment without synthetic fallback. Repeat
[Lakehouse, map and SQL verification](../04-run-and-verify/manual.md#step-23-open-the-six-tables-and-onelake-receipt)
for the new run ID. Item names remain unchanged; republish Results separately
so its saved run binding selects the new verified run.
Stop on source/schema errors, fallback, incomplete results or mismatched counts.
If cloud completion and local failure disagree, use
[supported recovery](../deploy/README.md#recover-an-interrupted-run), not a resubmission
or manual state edit.

The optional Tampa reference passed after recovery: `27.9506, -82.4572`,
three days, 10 km, H3 6, seed 42, real population, overwrite disabled, Runtime
1.3/F2. Counts were `cells_daily=8`, `arrival=3`, `front_daily=4`,
`grid_population_vulnerability=17`, `origin=1`, `vulnerability_summary=5`.
The original CLI exited 1 after DNS interruption; completed jobs were recovered
with exit 0, persisted, then map and SQL were user-confirmed. This is **not**
a clean initial run or an expected-count promise for other cities.

#### Explore interactive mapping

**Do this now in your browser:** read the official
[ArcGIS Maps for Microsoft Fabric guide](https://doc.esri.com/en/arcgis-maps-microsoft-fabric/latest/index.html).
Maps is an optional downstream workload, distinct from GeoAnalytics and the
included Results notebook. Confirm workload availability, administrator settings,
ArcGIS licensing/user privileges and a supported spatial ingestion path before
planning an experiment. WKT text is **not automatically map-ready**.
Expected: a scoped feasibility decision; stop if compatibility/access is unverified.
This guide adds no export, ingestion, map publication or app automation and
does not claim reproduction of Sean's exact map or outcome.

#### Consider your own data

**Do this now with the data owner:** choose a small approved dataset and one
concrete spatial question. Review geometry/CRS, source coverage, data rights,
permissions, expected outputs and costs. Expected: a separate adaptation plan,
not a guaranteed parameter-only feature of the pinned teaching model.
Stop until the data and implementation scope are approved.

#### Measure and stop safely

**Do this now in Fabric:** stop the Results notebook's interactive Spark session
after viewing. Check already submitted jobs before stopping Chat/terminal:
closing either does not cancel cloud execution or remove resources.
Distinguish job duration, measured CU consumption and shared/delayed billed costs.
A daily bill difference is not per-run cost; the Tampa run's CU and dollar cost
remain unmeasured. Do not install metrics tooling or change capacity without approval.

### See

You have an Azure/Fabric foundation and results you can inspect.
Any new use case still needs suitable data, permissions and its own checks.
Runtime 2.0 and execution under another identity (including Ana) were not validated.
The fictional simulation is a learning example, not a real-world outbreak
forecast.

### Next

Return to [04 Run and verify](../04-run-and-verify/README.md) if you want to
approve another small run. Otherwise, save your results and use the
[cleanup guide](../04-run-and-verify/manual.md#cleanup-and-troubleshooting)
when the resource owner agrees they are no longer needed.

No commit, push or PR is required to complete a customer trial. Contributors
need explicit permission for a feature branch, reviewed source-only staging,
commit, push and PR publication; approval to run Fast Pass grants none of these.
Keep configuration, state, receipts, private identifiers and upstream/generated
notebooks out of committed content.
Another local clone is not a separate GitHub repository or feature branch.
Review [what cloning changes](../01-start-here/manual.md#what-cloning-changes)
before publishing intentional contributor changes.

For implementation details, see the optional
[engineering evidence](../engineering/validation-notes.md#architecture-details).
