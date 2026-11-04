---
title: Fabric GeoAnalytics deployment experience
description: A post-zombie path from spatial demo to real-world location intelligence, starting with guided Azure and Fabric GeoAnalytics deployment.
ms.date: 2026-11-03
---

## Post zombie outbreak: same data, real impact

[![Post zombie outbreak: real-world data flows through Microsoft Fabric and OneLake into ArcGIS and operational experiences. Concept illustration, not deployed output.](./docs/images/post-zombie-outbreak.png)](./docs/images/post-zombie-outbreak.png)

The zombies were the demo. Location intelligence is the opportunity.

The [zombie outbreak demo](https://github.com/SeanKMcG/fabric_zombie_outbreak)
made a spatial pattern memorable: combine location and population data,
analyze relationships, simulate change, and inspect results. The post-zombie
story takes that pattern beyond the fictional scenario, toward questions
about service coverage, infrastructure exposure, and community resilience.

The broader journey is real-world data, spatial computation in Microsoft
Fabric with ArcGIS GeoAnalytics, reusable data in OneLake, and ArcGIS
visualization and operational experiences that help people act.
This repository starts by making the compute and data foundation deployable
and repeatable, rather than copying the original blog.

> [!NOTE]
> The image shows the broader vision, not a deployment screenshot; its maps
> and metrics are illustrative. This accelerator creates an Azure foundation
> and Fabric workspace items, then writes six Delta/WKT outputs and a OneLake
> verification receipt when you run the workload. It does not deploy the
> pictured GeoParquet outputs, ArcGIS maps, dashboards, Experience Builder
> apps, or Field Maps workflows. Those are potential next integrations, not
> completed capabilities. The fictional model is not a public-health forecast.
> Click the image to read it at full size.

## Start here

**[Open 01 Start here](./01-start-here/README.md)**

Read the numbered folders in order. Each opens with what to do, what success
looks like, and a link to the next folder.
Choose Copilot Fast Pass, the preferred route, or the manual alternative
inside folder 01. Continue that same route through folders 02-04; do not
perform both. Folder 05 is optional architecture and next experiments.

Start in your browser. When instructed to clone/open the project in VS Code,
open the **whole repository**, not a numbered folder or the deployment
implementation folder. All terminal commands run from the repository root.
Do not press the Azure button until folder 01's prerequisites are confirmed.

### Use the Azure button when the guide tells you

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTonyfra91%2Ffabric-geoanalytics-deploy%2Fv0.1.0%2Fdeploy%2Fazuredeploy.json)

> [!IMPORTANT]
> The button deploys Azure resources only. It does not create Fabric workspace
> items, configure your Esri key, or run a notebook. Follow the guided finish
> steps after Azure deployment succeeds.

> [!WARNING]
> Azure and Fabric resources can incur charges. Reuse an existing supported F
> capacity by default. Creating a new capacity requires explicit opt-in.
> Key Vault has public network access in this interactive-user POC.

## The experience

| Open in order                                      | What you do                                                                    | Continue when                                    |
| -------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------ |
| [01 Start here](./01-start-here/README.md)         | Choose a route, install tools, verify identity and prerequisites               | Access and approvals are confirmed               |
| [02 Deploy Azure](./02-deploy-azure/README.md)     | Review parameters, press the button and record outputs                         | Azure deployment succeeds                        |
| [03 Finish Fabric](./03-finish-fabric/README.md)   | Initialize, validate, approve setup, inspect items and enter the key           | Fabric is configured and secret storage succeeds |
| [04 Run and verify](./04-run-and-verify/README.md) | Approve a synthetic run, inspect tables/receipt/SQL, optionally test real data | Acceptance evidence is recorded                  |
| [05 Next steps](./05-next-steps/README.md)         | Understand the architecture and choose future experiments                      | Only separately approved experiments continue    |

### Follow the accelerator in order

[![Five numbered folders: start here, deploy Azure, finish Fabric, run and verify, next steps](./docs/images/accelerator-journey.svg)](./docs/images/accelerator-journey.svg)

Read 01-03 across the top, then 04-05 across the bottom. Click for full size.
The numbers match the folders above. The diagram is an overview, not another
set of deployment instructions.

After synthetic verification, the real-population test is optional. Follow
the chosen guide; do not jump directly to it or run both routes.

### Where you work at each stage

| Location                                      | What you do there                                                                       | What you must not assume                       |
| --------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Local PowerShell 7                            | Install/check tools, sign into Azure CLI, run repo commands                             | Windows PowerShell 5.1 is not sufficient       |
| Azure portal                                  | Check subscription access, press the button, inspect deployment and vault               | Azure success does not create Fabric items     |
| Fabric portal                                 | Verify access before deployment; inspect workspace, jobs, Lakehouse and SQL after setup | Azure access does not imply Fabric permissions |
| Your administrator or Esri subscription owner | Obtain settings, permission and entitlement approvals                                   | A non-admin cannot grant these to themselves   |

## What is in this repository

* [Bicep source](./deploy/main.bicep) and its checked-in
  [portal ARM template](./deploy/azuredeploy.json)
* [Portal configuration initializer](./Initialize-Experience.ps1) that reads
  Azure outputs without provisioning anything
* [Lifecycle entry point](./deploy.ps1) for validation, Fabric completion,
  secret setup, execution, and status
* [Pinned demo retrieval](./Get-DemoNotebook.ps1), with
  [upstream attribution and boundaries](./docs/demo-provenance.md)
* [Detailed operations reference](./deploy/README.md) and
  [architecture and next steps](./05-next-steps/README.md)
* [Copilot Fast Pass guide](./01-start-here/copilot.md) and a
  [repository deployment skill](./.github/skills/fabric-geoanalytics-fast-pass/SKILL.md)
* Offline regression tests and a template freshness check

The upstream notebook is downloaded locally or supplied by you. It is not
redistributed in this repository. The adapter removes author bindings,
cached results, and ArcGIS publishing from the deployed workload.

The numbered folders are the user journey. The deployment folder contains
implementation and operations reference, while the documentation folder holds
shared images, provenance and compatibility indexes for old guide links.
Neither is an alternative starting point.

## Engineering status

This is a preview, not a production-certified accelerator.
Offline tests cover notebook adaptation, parameter validation, failures,
ownership boundaries, the output contract, and the Azure-to-Fabric handoff.
The ARM template is compiled from Bicep; CI checks that it stays synchronized.

A customer deployment is not proven until live environment publication,
runtime Key Vault access, synthetic execution, output read-back, SQL visibility,
and repeat deployment are verified in that customer's tenant.
See the [live acceptance checklist](./04-run-and-verify/manual.md#acceptance-checklist).

## Develop and validate

CI runs the checks below on every push and pull request. Documentation checks
require ordered steps, explicit location/action/success/next-step checkpoints,
working links, the unchanged deployment button, and synchronized compact
diagram labels. They cannot prove current tenant screens or live access.

```powershell
.\Get-DemoNotebook.ps1
.\deploy\tests\Test-Accelerator.ps1
.\deploy\tests\Test-Experience.ps1
.\deploy\scripts\Build-Template.ps1 -Check
```

After editing Bicep, regenerate the portal template:

```powershell
.\deploy\scripts\Build-Template.ps1
```

The button pins release `v0.1.0`. Updating `main` does not silently change
that released deployment. A future release must update the button and be
tagged after validation.

### Edit the overview diagram

The [editable draw.io source](./docs/images/accelerator-journey.drawio) is
separate from the [SVG shown on GitHub](./docs/images/accelerator-journey.svg).
Open [diagrams.net](https://app.diagrams.net), choose **Device**, then
**Open Existing Diagram** (or **File > Open From > Device**) and select the
downloaded `.drawio` file. Keep five numbered stages matching the folders and
plain-text labels.
Save the source, then use **File > Export as > SVG** to update the SVG as well.
Run the documentation checks before committing both files.

Keep the overview short: decisions, errors and detailed commands belong in
the step-by-step guides, not in a taller flowchart. Validate layout on GitHub
after publishing. For a first-run usability check, have a new operator follow
one route and record the first unclear screen/action without exposing secrets;
fix that checkpoint and rerun CI.
