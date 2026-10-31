#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Generates a separate, clean notebook from the pinned upstream notebook.
.DESCRIPTION
    Loaded by Accelerator.psm1. Never edits the upstream notebook.
.EXAMPLE
    .\deploy.ps1 validate
.NOTES
    Upstream cell layout and source fingerprint are checked before transformation.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

#region Functions
function New-DeployableNotebook {
    <#
    .SYNOPSIS
        Removes author bindings, publishing, and cached output; adds secure authorization and Delta writes.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][guid]$WorkspaceId,
        [Parameter(Mandatory)][guid]$LakehouseId,
        [Parameter(Mandatory)][guid]$EnvironmentId,
        [Parameter(Mandatory)][string]$LakehouseName,
        [Parameter(Mandatory)][string]$KeyVaultUri
    )
    $OriginalPath = Join-Path $script:Root 'Zombie_Outbreak_Spread.ipynb'
    if ((Get-FileHash -LiteralPath $OriginalPath -Algorithm SHA256).Hash -notin @(
        '5ED29ADEAF63C977FEC3535A01F72E07865F0D11D80F7120DBC6E9D0AD645738'
        '01BAB46195C2CFE4D5AF84E5446477CEB7BE9713DF8430F427945CBC52D1C53A'
    )) {
        throw 'Upstream notebook fingerprint changed. Review and test the adapter before updating its pin.'
    }
    $Original = Get-Content -LiteralPath $OriginalPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ($Original.nbformat -ne 4 -or $Original.cells.Count -ne 26 -or
        ($Original.cells[3].source -join '') -notmatch 'PARAMETERS' -or
        ($Original.cells[15].source -join '') -notmatch 'cells_daily =') {
        throw 'Upstream notebook layout changed. Review the notebook adapter before deploying.'
    }
    $Parameters = (($Original.cells[3].source -join '') -split '# --- Publish to ArcGIS Online')[0]
    $Parameters = $Parameters -replace '(?m)^OUTPUT_ROOT\s*=.*\r?\n', ''
    $Parameters = $Parameters -replace '(?m)^SIM_DAYS\s*=.*$', 'SIM_DAYS = 2'
    $Parameters = $Parameters -replace '(?m)^STUDY_RADIUS_KM\s*=.*$', 'STUDY_RADIUS_KM = 10'
    $Parameters = $Parameters -replace '(?m)^H3_RESOLUTION\s*=.*$', 'H3_RESOLUTION = 6'
    $Parameters += "`nTABLE_PREFIX = `"zombie`"`nOVERWRITE = False`nCHECK_ONLY = False`n"
    $Setup = $Original.cells[5].source -join ''
    $Setup = $Setup -replace '(?m)^assert AGOL_WRITE_MODE.*\r?\n', ''
    $Setup = $Setup -replace '(?m)^AGOL_EXISTING_SERVICES =.*\r?\n', ''
    $Setup = $Setup.Replace('OUT = f"{OUTPUT_ROOT}/run_id={RUN_ID}"', 'OUT = f"Files/zombie_outbreak/run_id={RUN_ID}"')
    $Setup += @'

import re
if not re.fullmatch(r"[a-zA-Z0-9_]{1,48}", RUN_ID):
    raise ValueError("RUN_ID must contain 1-48 alphanumeric/underscore characters.")
if not re.fullmatch(r"[a-z][a-z0-9_]{0,23}", TABLE_PREFIX):
    raise ValueError("TABLE_PREFIX must be a lowercase SQL identifier of at most 24 characters.")
if not isinstance(OVERWRITE, bool) or not isinstance(CHECK_ONLY, bool):
    raise ValueError("OVERWRITE and CHECK_ONLY must be booleans.")
'@
    $Cells = [System.Collections.Generic.List[object]]::new()
    $Cells.Add(@{cell_type='markdown';metadata=@{};source='## Fabric-only zombie outbreak POC. Small defaults; no ArcGIS publication. Geometry is persisted as WKT (EPSG:4326).'})
    $Cells.Add(@{cell_type='code';metadata=@{tags=@('parameters')};source=$Parameters;outputs=@();execution_count=$null})
    $ConfigJson = @{keyVaultUri=$KeyVaultUri;secretName='geoanalytics-api-key'} | ConvertTo-Json -Compress
    $ConfigLiteral = $ConfigJson | ConvertTo-Json -Compress
    $Bootstrap = "import json`nDEPLOYMENT_CONFIG = json.loads($ConfigLiteral)`n" +
        (Get-Content -LiteralPath (Join-Path $script:Root 'deploy\fabric\notebook\bootstrap.txt') -Raw)
    foreach ($Code in @($Bootstrap,$Setup)) {
        $Cells.Add(@{cell_type='code';metadata=@{};source=$Code;outputs=@();execution_count=$null})
    }
    foreach ($Index in @(7,9,11,13,15,22)) {
        $Cells.Add(@{cell_type='code';metadata=@{};source=($Original.cells[$Index].source -join '');outputs=@();execution_count=$null})
    }
    $Cells.Add(@{
        cell_type='code';metadata=@{};outputs=@();execution_count=$null
        source=(Get-Content -LiteralPath (Join-Path $script:Root 'deploy\fabric\notebook\delta-output.txt') -Raw)
    })
    $Notebook = @{
        nbformat=4;nbformat_minor=5;cells=$Cells.ToArray()
        metadata=@{
            kernel_info=@{name='synapse_pyspark'}
            language_info=@{name='python'}
            dependencies=@{
                lakehouse=@{
                    default_lakehouse=$LakehouseId.ToString();default_lakehouse_name=$LakehouseName
                    default_lakehouse_workspace_id=$WorkspaceId.ToString()
                    known_lakehouses=@(@{id=$LakehouseId.ToString()})
                }
                environment=@{environmentId=$EnvironmentId.ToString();workspaceId=$WorkspaceId.ToString()}
            }
        }
    }
    $Serialized = $Notebook | ConvertTo-Json -Depth 100
    if ($Serialized -match '1692bff1-d4c7-4977-b5f5-57af93808cd3|6a30c14f-a876-466e-baad-2c563d3baf37|AGOL_|PUBLISH_TO_|register_gis|feature-service.*write') {
        throw 'Author binding or publishing reference leaked into the generated notebook.'
    }
    return $Notebook
}
#endregion
