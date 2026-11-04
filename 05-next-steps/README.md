---
title: 05 Next steps
description: Architecture, deployment boundaries and evidence-driven future experiments.
ms.date: 2026-11-03
---

## 05 Next steps

Begin here only after [04 Run and verify](../04-run-and-verify/README.md). Record the acceptance evidence before choosing another experiment. Nothing on this page automatically deploys the broader ArcGIS vision.

### Where

Use your private acceptance records and the architecture reference below.
No terminal command or cloud mutation is required to read this stage.

### Do

Review the lessons and roadmap. Choose an experiment only after confirming
its scope, prerequisites and owner approval; future capabilities are not
implemented deployment switches.

### See

You can distinguish the delivered Azure/Fabric foundation and verified
workload from optional ArcGIS publishing, unattended deployment and other
future work.

### Next

The required first-test journey is complete after verified acceptance.
Stop here, return to the [journey overview](../README.md), or separately
approve a bounded experiment using [04 Run and verify](../04-run-and-verify/README.md).


## Separate the resource planes

```text
README blue button
    -> versioned ARM JSON compiled from Bicep
    -> subscription / dedicated resource group
       -> RBAC Key Vault
       -> optional new Fabric capacity

Interactive PowerShell finish
    -> verify completed Azure deployment and identity
    -> read-only prerequisite and ownership checks
    -> Fabric REST workspace / capacity assignment
    -> Lakehouse / published environment / notebook

Explicit secret and run commands
    -> hidden prompt writes Esri key
    -> notebook runtime retrieves key from Key Vault
    -> authorization probe
    -> spatial simulation
    -> six Delta tables + OneLake receipt + read-back counts
```

ARM manages Azure resources. Fabric REST manages workspace items.
The standard Azure button accepts ARM JSON, not a remote Bicep file:
[Microsoft's button guidance](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-azure-button).

The existing ownership marker `fabric-zombie-outbreak` remains in resource tags
and Fabric descriptions so the reused adapter/lifecycle checks stay consistent.
The repository name and deployment-first presentation do not silently change
that ownership contract.

## Lessons carried forward from the demo

| Demo pattern                        | Deployment lesson                                                      | Next experiment                                                 |
| ----------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------- |
| H3 cells and spatial joins          | Fix runtime and engine compatibility before workload execution         | Compare grid resolutions at bounded study radii                 |
| Census and vulnerability enrichment | Treat source coverage, schema, and access as separate prerequisites    | Validate a small real-population US run                         |
| Iterative movement graph            | Capacity visibility does not prove Spark headroom                      | Measure wall time and memory before increasing days/radius      |
| Spatial outputs                     | Define an explicit data contract, not merely a successful notebook job | Confirm Delta read-back and SQL visibility                      |
| Optional downstream publication     | Keep ingestion/compute separate from destination credentials           | Design a separately consented ArcGIS publishing stage           |
| Notebook parameters                 | Separate workload inputs from infrastructure and secrets               | Adapt the pattern to service coverage or accessibility analysis |

The fictional simulation is a teaching workload, not an epidemiological,
emergency-planning, or public-health prediction.

## Why not one unattended button yet

Embedding Fabric provisioning in an ARM deployment script would introduce a new
runtime identity, token acquisition, consent, and credential lifecycle.
The current interactive-user model cannot be replaced by a managed identity
without proving the exact Fabric APIs and runtime Key Vault access path.

The two-stage experience makes that boundary visible instead of hiding an
unsupported identity assumption behind an Azure success screen.

## Evidence-driven roadmap

1. Complete the [live acceptance checklist](../04-run-and-verify/manual.md#acceptance-checklist)
   in a dedicated tenant/workspace.
2. Validate real-source coverage and schema, then measure bounded scale increases.
3. Evaluate private networking and separate key-writer/key-reader roles.
4. Add concurrency locking and stronger removal ownership before automating cleanup.
5. Evaluate the beta job exit-value dependency and compatible stable alternatives.
6. Prove a least-privilege unattended identity for each Fabric operation before
   adding deployment-script orchestration or another one-button finish experience.

These are future capabilities, not switches supported by this release.
Existing capacity lifecycle, ArcGIS publication, unattended execution, and
automatic cleanup remain out of scope.
