---
title: 04 Run and verify
description: Prove the synthetic workload, inspect outputs and separately approve optional real data.
ms.date: 2026-11-03
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

Approve one bounded synthetic run first. Verify it before separately
approving the optional real-population test. Do not submit a second run
because a browser looks idle or a command timed out; inspect the existing job.

### See

Preflight and simulation succeed, and six Delta/WKT output tables plus a
OneLake `result.json` receipt are verified. Inspect required nonempty outputs
and compare SQL visibility/counts with the Spark receipt.
This is table-based verification, not a deployed map or dashboard.
Record real-population validation as `NOT RUN` if you decline it.
Use the [acceptance checklist](./manual.md#acceptance-checklist) before calling
the test complete.

### Next

After acceptance, open [05 Next steps](../05-next-steps/README.md) to understand
the architecture and choose a future experiment, or stop here.
Cleanup is separate, destructive and owner-approved:
[cleanup and troubleshooting](./manual.md#cleanup-and-troubleshooting).

[Previous: 03 Finish Fabric](../03-finish-fabric/README.md)
