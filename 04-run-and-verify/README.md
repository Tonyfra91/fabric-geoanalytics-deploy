---
title: 04 Run and verify
description: Run the bounded sample, view its map in Fabric and verify all six SQL outputs.
ms.date: 2026-11-04
---

## 04 Run and verify

Complete [03 Finish Fabric](../03-finish-fabric/README.md) first.

### Where

Use VS Code Chat or local PowerShell at the repository root for submission.
Use Fabric's monitoring, Lakehouse and SQL analytics endpoint for inspection.
Keep the submitted job's terminal output and actual run ID available.

### Do

Continue the route you selected:

* [Copilot Fast Pass: FP13-FP16](./copilot.md)
* [Manual alternative: Steps 21-25 and acceptance](./manual.md)

Start with the small synthetic run, which uses generated sample population
data. This is end-to-end functional validation, not a benchmark. Optional
real-population execution is not required to finish; record it as **NOT RUN**
if you skip it. A separate Tampa reference passed after completed-job recovery,
not a clean initial CLI run; its evidence does not validate arbitrary scenarios.
If a command times out or the browser looks idle, check the existing job
before starting another one; it may still be running.
For completed cloud jobs with failed local polling, separately approve
[recover-run](../deploy/README.md#recover-an-interrupted-run). Require recovered
state and the new viewer binding before map/SQL acceptance; do not resubmit compute.

### See

An access check runs first, followed by the simulation. When both succeed,
you can open six results tables and a `result.json` run summary in OneLake.
The guide shows you how to prepare Results, then **Open Results > Run all > View map**,
and finally compare all six SQL row counts with that summary. Separately approve
viewer publication and its interactive compute to see the study
grid, reached cells and outbreak origin on a north-up spatial map in Fabric.
It uses the completed run, not another simulation. No external basemap,
ArcGIS publishing credentials or new infrastructure is required.
If you skip the real-population run, record it as `NOT RUN`.
Use the [completion checklist](./manual.md#acceptance-checklist) to finish.

### Next

After checking your results, you can stop or open
[05 Next steps](../05-next-steps/README.md) for ideas.
When you no longer need the resources, follow the
[cleanup guide](./manual.md#cleanup-and-troubleshooting).
Deletion needs the resource owner's approval.
**Do this now in Fabric:** stop the interactive Results Spark session after
acceptance. Expected: the session is stopped; check any submitted jobs separately.
Resources can still charge. No commit/push is required.

[Previous: 03 Finish Fabric](../03-finish-fabric/README.md)
