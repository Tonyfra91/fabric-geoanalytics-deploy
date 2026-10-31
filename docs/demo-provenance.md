---
title: Demo provenance and redistribution boundaries
description: Upstream notebook attribution, immutable source pin, and local adapter behavior.
ms.date: 2026-10-30
---

## Upstream demo

The spatial teaching workload comes from
[SeanKMcG/fabric_zombie_outbreak](https://github.com/SeanKMcG/fabric_zombie_outbreak).
The adapter targets
[commit 29ac7cdeee63d7cadc8538a128384b58f13aa2c8](https://github.com/SeanKMcG/fabric_zombie_outbreak/tree/29ac7cdeee63d7cadc8538a128384b58f13aa2c8).

This repository does not copy the upstream README, blog, banner, or notebook
into its published source. Its original guidance focuses on Bicep deployment,
the Azure/Fabric handoff, operational boundaries, and verification.

The pinned upstream tree did not contain a license file when inspected.
Public availability is not a redistribution license.
Obtain permission from the upstream owner before redistributing the notebook
or generated derivatives. The license for this repository's tooling does not
relicense upstream material.

## Local retrieval and integrity

```powershell
.\Get-DemoNotebook.ps1
```

Alternatively, supply a copy you are authorized to use:

```powershell
.\Get-DemoNotebook.ps1 -SourcePath 'C:\your-demo-copy\Zombie_Outbreak_Spread.ipynb'
```

The script installs the notebook locally at the adapter's expected path and
rejects an unexpected hash. The source notebook and generated deployment state
are ignored by Git.

Two verified SHA256 byte forms are supported for the same pinned content:

| Form | SHA256 |
|---|---|
| Raw GitHub file, LF line endings | `5ED29ADEAF63C977FEC3535A01F72E07865F0D11D80F7120DBC6E9D0AD645738` |
| Original Windows checkout, CRLF line endings | `01BAB46195C2CFE4D5AF84E5446477CEB7BE9713DF8430F427945CBC52D1C53A` |

Their decoded contents were verified equal after CRLF-to-LF normalization.
The adapter also checks notebook layout and expected cells before transformation.
Changing the source pin requires compatibility review and regression tests.

## Adapter behavior

The adapter leaves the local original unchanged. It builds a separate workload
that removes author resource bindings, cached outputs, and ArcGIS publication;
adds runtime Key Vault retrieval; supplies small simulation defaults; and writes
six Delta outputs with WKT geometry and a receipt.

The upstream demo remains the authority for its simulation logic.
Neither its fictional model nor this deployment experience is a claim of
production suitability or a real-world outbreak forecast.
