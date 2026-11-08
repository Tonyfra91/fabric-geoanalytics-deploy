---
title: Fabric GeoAnalytics deployment experience
description: Deploy, authorize, run and verify a bounded Fabric GeoAnalytics experience.
ms.date: 2026-11-04
---

## Fabric GeoAnalytics Fast Pass

Go from prerequisites to a working Microsoft Fabric + ArcGIS GeoAnalytics
experience: private Azure deployment, secure Esri credential entry, a bounded
synthetic simulation, a visible spatial map in Fabric, and six verified SQL
outputs. This is a functional validation, not a performance benchmark or
production-scale workload.

The scenario adapts [Sean McGinnis's zombie outbreak demo](https://github.com/SeanKMcG/fabric_zombie_outbreak).
The fictional model is not a public-health forecast. The Results map is a
local projection, not the original ArcGIS basemap or an ArcGIS publication.

## Start here

**[Open 01 Start here](./01-start-here/README.md)**

Follow folders 01-04 in order. Each explains what to do, what you should
see, and where to go next.
In folder 01, choose Copilot Fast Pass or the manual walkthrough. Both lead
to the same result, so follow just one. Folder 05 offers optional next steps.

Start in your browser. When instructed to clone/open the project in VS Code,
open the **whole repository**, not a numbered subfolder. Run terminal
commands from the main folder containing `deploy.ps1`.
Do not deploy Azure until folder 01's prerequisites are confirmed.

### Use the current private Azure template

At [Step 13](./02-deploy-azure/manual.md#step-13-load-the-private-template-and-enter-the-azure-parameters),
load the checkout's [compiled foundation](./deploy/azuredeploy.json) into Azure
**Custom deployment > Build your own template in the editor > Load file**.
Review the subscription-scoped deployment, then select Create yourself.
The old `v0.1.0` button is not the supported private-foundation entry.

> [!IMPORTANT]
> This template deploys Azure resources only. It does not create Fabric workspace
> items, configure your Esri key, or run a notebook. Follow the guided finish
> steps after Azure deployment succeeds.

> [!WARNING]
> Azure and Fabric resources can incur charges. Reuse an existing supported F
> capacity when available. Create a new one only with the owner's approval.
> Key Vault public access must remain Disabled. Complete the private Fabric
> connection approval when requested, and supply the Esri key only through
> the secure Azure deployment step.

## The experience

| Open in order                                      | What you do                                                                    | Continue when                                    |
| -------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------ |
| [01 Start here](./01-start-here/README.md)         | Choose a route, install tools, verify identity and prerequisites               | Access and approvals are confirmed               |
| [02 Deploy Azure](./02-deploy-azure/README.md)     | Load the private template, review parameters and record outputs                | Azure deployment succeeds with public vault access Disabled |
| [03 Finish Fabric](./03-finish-fabric/README.md)   | Initialize, validate, approve setup, inspect items and enter the key           | Fabric is configured and secret storage succeeds |
| [04 Run and verify](./04-run-and-verify/README.md) | Run the bounded sample; Open Results, Run all, View map; compare six SQL counts | Map is visible and all six counts match the receipt |
| [05 Next steps](./05-next-steps/README.md)         | Explore optional ideas for using the results | You can stop here or plan a separately approved next step |

### Follow the accelerator in order

[![Five numbered folders: start here, deploy Azure, finish Fabric, run and verify, next steps](./docs/images/accelerator-journey.svg)](./docs/images/accelerator-journey.svg)

Read 01-03 across the top, then 04-05 across the bottom. Click for full size.
The numbers match the folders above. The diagram is an overview, not another
set of deployment instructions.

The synthetic path has been validated end to end, including the visible Fabric
map and SQL counts. Optional real-population execution has **not been run** and
is not required for completion.

### Where you work at each stage

| Location                                      | What you do there                                                                       | What you must not assume                       |
| --------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Local PowerShell 7                            | Install/check tools, sign into Azure CLI, run repo commands                             | Windows PowerShell 5.1 is not sufficient       |
| Azure portal                                  | Load the private template; later enter the key privately in the secure credential field | Azure success does not create Fabric items     |
| Fabric portal                                 | Verify access before deployment; inspect workspace, jobs, Lakehouse and SQL after setup | Azure access does not imply Fabric permissions |
| Your administrator or Esri subscription owner | Confirm the required settings, permissions and Esri license | Get these approvals before deploying |

## Fast Pass completed successfully

* Azure is healthy with Key Vault public access **Disabled**.
* Fabric is configured on active F capacity, Runtime **1.3**, with correct bindings.
* The managed private endpoint is **Succeeded / Approved**.
* Private secret retrieval and GeoAnalytics authorization pass.
* The bounded run exits **0** and six outputs pass Spark read-back.
* **Open Results > Run all > View map** shows the spatial result in Fabric.
* All six SQL counts match that run's receipt; zero synthetic vulnerability-summary rows is valid.

Save your run ID and use the [completion checklist](./04-run-and-verify/manual.md#acceptance-checklist).

## About this guide

This is a local Fast Pass v0.1 candidate for small, approved trials, not a production-ready solution.
The revised checked-out-template Azure entry still needs new-customer UI validation
before release; the old immutable release was not changed.
Check the results in your own workspace using the
[completion checklist](./04-run-and-verify/manual.md#acceptance-checklist).

## Help and reference

* [Troubleshooting](./deploy/README.md#removal-and-troubleshooting)
* [Optional next steps](./05-next-steps/README.md)
* [Where the demo comes from and what is included](./docs/demo-provenance.md)
* [Technical reference and maintenance](./deploy/README.md)
* [Engineering evidence, not required customer reading](./engineering/validation-notes.md)
