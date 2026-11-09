---
title: Fabric GeoAnalytics Fast Pass with GitHub Copilot
description: Explore spatial analytics with GitHub Copilot-assisted setup, a visible Fabric map and SQL results.
ms.date: 2026-11-08
---

## Fabric GeoAnalytics Fast Pass with GitHub Copilot

Your data tells you what happened. What changes when you ask **where**?

Where are the gaps in service coverage? Which assets are near an event?
How might a changing footprint affect the surrounding area? Spatial analytics
adds a location perspective to the questions you already explore with SQL,
Power BI and Microsoft Fabric.

This Fast Pass gives you a guided, hands-on introduction to **Microsoft Fabric +
ArcGIS GeoAnalytics**, with **GitHub Copilot in VS Code** as your guide on the
preferred route.

If Sean McGinnis's Halloween zombie blog brought you here, welcome.
If not, here's the connection: his [zombie-outbreak demo](https://github.com/SeanKMcG/fabric_zombie_outbreak)
uses a fictional outbreak to explore location and change over time.
This Fast Pass builds on that idea with guided setup and a small first run:
view the map and inspect the same results in Fabric tables.
You do not need to have read the blog to follow along. The outbreak is a
learning sandbox, not a finished coverage or risk-analysis application.

**To complete the demo, you need an Azure subscription, an active Fabric F
capacity with GeoAnalytics enabled, and an Esri GeoAnalytics entitlement with
an authorized API key.** Neither Fabric nor GitHub Copilot supplies that key.

## Take the Fast Pass with GitHub Copilot

Think beyond autocomplete: **Copilot can help you understand the repository,
work through setup and investigate errors in the context of your project.**
In an approved agent session, it can explain the next action, run setup commands
and check their results. You spend less time translating instructions into
commands and more time understanding what you are building.

Ask questions as you go: "What does this step do?" "Why is this permission
needed?" "What should I see next?" The opportunity is not just getting a demo
running; it is learning how an AI assistant can help you explore unfamiliar
tools while you stay in control.

[Set up GitHub Copilot in VS Code](https://code.visualstudio.com/docs/setup/copilot)
with your approved GitHub account. [Copilot Free](https://docs.github.com/en/copilot/get-started/plans)
offers eligible accounts limited AI assistance at no cost. Usage and feature
limits apply; a longer session may require a paid plan. Completing this entire
Fast Pass within the Free allowance has not been validated.

You review tool requests and approve cloud changes and compute. You still sign
in, obtain permissions, select **Create** in Azure and enter the Esri key
privately yourself. Copilot does not replace those responsibilities.
Prefer to run every command yourself? The manual route is equally valid.

> [!IMPORTANT]
> Free Copilot access does not make the deployment free. Azure resources,
> Fabric capacity and Esri licensing have separate costs and terms.

## Who is this for

ArcGIS GeoAnalytics brings capabilities used in GIS data science and engineering.
This guide makes them approachable for people who work with data but are
**not traditional GIS specialists**:

* Business and operations analysts who want to explore how location changes
  questions about coverage, access, exposure or service delivery.
* Power BI developers and analytics engineers who want to connect spatial
  results to familiar Fabric tables and SQL workflows.
* Data engineers, data scientists and solution architects who want to evaluate
  spatial computation alongside their existing analytics tools.

You do not need to be a GIS specialist to follow the demo. You will use terminal
commands and configure cloud resources. If that is not your day-to-day role,
work through setup with an Azure/Fabric administrator or data engineer.
You bring the questions; they can help with the platform access and approvals.

## What you will learn and take away

The objective is to make spatial analytics tangible: run an example, see its
geography, and verify the underlying data rather than stop at deployment success.

* Connect a Fabric workspace to a private Azure Key Vault and securely provide
  the Esri credential.
* Authorize GeoAnalytics and run a small synthetic simulation with bounded inputs.
* Open a reusable Results notebook to see the study grid, reached cells and origin.
* Inspect six persisted output tables and compare SQL row counts with the run's
  verification receipt.

You finish with a working example in your own environment and a starting point
for evaluating spatial questions with your team. This is functional validation,
not a performance benchmark or production-scale workload. Applying it to your
own data is a separate next step.

The scenario adapts [Sean McGinnis's zombie outbreak demo](https://github.com/SeanKMcG/fabric_zombie_outbreak).
The fictional model is not a public-health forecast. The Results map is a
local projection, not the original ArcGIS basemap or an ArcGIS publication.

## Prerequisites before you choose a route

Both walkthroughs require the same Azure, Fabric and Esri access.

> [!TIP]
> **Already equipped? Your ready-to-start shortcut**
>
> You can begin without new subscriptions or capacity purchases when you have:
>
> * Active Azure subscription deployment and vault role-assignment permissions,
>   such as an appropriately scoped **Owner**, or **Contributor plus Role Based
>   Access Control Administrator**, with the required resource providers registered.
> * An **active F capacity, such as F2**, in the intended tenant/region, Data
>   Engineering access, permission to create the workspace/items and capacity
>   **Admin or Contributor** rights to assign the workspace. **ArcGIS GeoAnalytics
>   for Fabric Runtime** must be enabled for that capacity.
> * An **active Esri GeoAnalytics for Microsoft Fabric entitlement and its
>   authorized API key**, available privately to you.
> * The Windows/local tools listed below, approved networking and costs, and
>   approved Copilot access if you choose the Copilot route.
>
> **Have all four? [Begin at 01 Start here](./01-start-here/README.md).**
> Skip the acquisition links below, not the guided identity, validation and
> approval checks. Being an Azure or Fabric administrator alone does not supply
> the Esri entitlement/key; an F2 SKU alone does not guarantee capacity headroom.

**Starting from zero?** Use the links below to obtain access or find the owner
who can provide it. Signups do not automatically grant deployment permissions.

| You need | What to confirm | How to get it if missing |
| -------- | --------------- | ------------------------ |
| Azure subscription and deployment permissions | A work/school user authorized to run subscription deployments, create the dedicated resource group/private Key Vault/networking, and create the vault role assignment. An appropriately scoped Owner, or Contributor plus Role Based Access Control Administrator, is an example; Contributor alone is not enough. | [Get started with an Azure account](https://azure.microsoft.com/en-us/free/) or request an approved subscription from your Azure administrator. Review [deployment and role-assignment permissions](./01-start-here/manual.md#step-04-confirm-azure-deployment-and-role-assignment-permissions). Account offers have eligibility, credit and billing terms; do not assume they cover this deployment. |
| Microsoft Fabric capacity and access | An **active supported F capacity**, Data Engineering access, permission to create the workspace/items and assign the workspace to capacity. An administrator must enable **ArcGIS GeoAnalytics for Fabric Runtime** for your tenant or selected capacity. | Ask your Fabric administrator to reuse an approved F capacity, or review Microsoft's [F-capacity purchase guide](https://learn.microsoft.com/en-us/fabric/enterprise/buy-capacity) and [licensing guide](https://learn.microsoft.com/en-us/fabric/enterprise/licenses). If none exists, obtain approval for the [new-capacity option in Step 13](./02-deploy-azure/manual.md#step-13-load-the-private-template-and-enter-the-azure-parameters). Have the administrator [enable GeoAnalytics](https://learn.microsoft.com/en-us/fabric/data-engineering/spark-arcgis-geoanalytics#enable-arcgis-geoanalytics). |
| Esri entitlement and API key | An active **ArcGIS GeoAnalytics for Microsoft Fabric** entitlement and its authorized **API key**. A generic ArcGIS basemap/location-services key will not authorize this workload. | Review [Esri's Microsoft Marketplace offering](https://go.esri.com/arcgis-geoanalytics-for-fabric-marketplace) with your purchasing/subscription owner for licensing, pricing and any evaluation options. Ask that owner or Esri to provide the GeoAnalytics API key through an approved private channel; see [Esri's authorization requirements](https://developers.arcgis.com/geoanalytics-fabric/authorization/#api-key). Purchasing a license is not the same as receiving the key. |
| A Windows workstation and local tools | Permission to use VS Code, **PowerShell 7**, Git, Azure CLI, Bicep and Python. Windows PowerShell 5.1 is not sufficient. | [Install VS Code](https://code.visualstudio.com/download), then follow the [manual tool-installation checklist](./01-start-here/manual.md). Ask your IT administrator if software installation is restricted. |
| Administrator, networking and cost approvals | Azure/Fabric owners approve private networking, required service access and paid compute. Register `Microsoft.KeyVault` and `Microsoft.Network`; `Microsoft.Fabric` registration is needed only when explicitly creating new capacity. | Use the [administrator approval request](./01-start-here/manual.md#step-12-confirm-networking-costs-and-administrator-approvals) and [capacity-access checks](./01-start-here/manual.md#step-09-confirm-capacity-access-assignment-rights-and-region). Obtain approval before creating resources or accepting purchase terms. |
| Copilot access, only for the Copilot route | A GitHub account with approved Copilot access and usage allowance. **Copilot is optional**; the manual walkthrough reaches the same outcome. | [Set up Copilot in VS Code](https://code.visualstudio.com/docs/setup/copilot) with an existing employer-approved plan or eligible Free access. Compare [Free and paid plans](https://docs.github.com/en/copilot/get-started/plans); allowances and available features differ. |

A Fabric free user license or trial alone is **not a substitute for the active
F capacity required by this Fast Pass**. If starting with new accounts, work with
your administrator to put the Azure subscription and Fabric access in the same
Microsoft Entra tenant before deploying.

Use the same work/school user and tenant for Azure portal, Azure CLI and Fabric.
Keep the API key in approved secret storage until the secure Azure credential
step. Never paste it into Copilot chat, configuration files or a notebook.

Missing a prerequisite? You can still explore the guide and identify the right
owner to help. Obtain the required access and approvals before deploying.
Folder 01 walks you through confirming them; it does not supply a subscription,
capacity or Esri license.

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
