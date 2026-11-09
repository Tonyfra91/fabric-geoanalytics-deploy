#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Compiles the foundation and secure credential Azure portal templates.
.DESCRIPTION
    Check mode verifies the checked-in template without rewriting it, ignoring
    only Bicep generator version/hash metadata in root and nested templates.
.PARAMETER Check
    Fail if a checked-in portal template differs from freshly compiled Bicep.
.EXAMPLE
    .\deploy\scripts\Build-Template.ps1 -Check
.NOTES
    Requires Azure CLI-managed Bicep, but does not require Azure authentication.
#>
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'

#region Functions
function Remove-BicepCompilerProvenance {
    <#
    .SYNOPSIS
        Removes compiler-specific version/hash metadata before template comparison.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Template)
    if ($Template.metadata._generator.name -ceq 'bicep') {
        $Template.metadata._generator.Remove('version')
        $Template.metadata._generator.Remove('templateHash')
    }
    $Resources = if ($Template.resources -is [System.Collections.IDictionary]) {
        $Template.resources.Values
    } else {
        $Template.resources
    }
    foreach ($Resource in $Resources) {
        if ($Resource.type -eq 'Microsoft.Resources/deployments' -and
            $Resource.properties.template -is [System.Collections.IDictionary]) {
            Remove-BicepCompilerProvenance -Template $Resource.properties.template
        }
    }
}
#endregion

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $DeployRoot = Split-Path $PSScriptRoot -Parent
    try {
        foreach ($Template in @(
            @{Source='main.bicep';Output='azuredeploy.json'},
            @{Source='secret-setup.bicep';Output='secret-setup.azuredeploy.json'}
        )) {
            $TemplatePath = Join-Path $DeployRoot $Template.Output
            $TemporaryPath = "$TemplatePath.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                & az bicep build --file (Join-Path $DeployRoot $Template.Source) --outfile $TemporaryPath
                if ($LASTEXITCODE -ne 0) { throw "Bicep compilation failed: $($Template.Source)." }
                if ($Check) {
                    if (-not (Test-Path -LiteralPath $TemplatePath)) { throw 'Portal template is missing. Run Build-Template.ps1.' }
                    $Compiled = Get-Content -LiteralPath $TemporaryPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
                    $Published = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
                    Remove-BicepCompilerProvenance -Template $Compiled
                    Remove-BicepCompilerProvenance -Template $Published
                    if (($Compiled | ConvertTo-Json -Depth 100 -Compress) -cne ($Published | ConvertTo-Json -Depth 100 -Compress)) {
                        throw "Portal template is stale: $($Template.Output). Review the compiled content changes, then regenerate using Build-Template.ps1. Bicep CLI 0.48.1 or later is required; compiler version/hash metadata alone is ignored."
                    }
                    Write-Host "Portal template matches Bicep source: $($Template.Output)."
                } else {
                    Move-Item -LiteralPath $TemporaryPath -Destination $TemplatePath -Force
                    Write-Host "Portal template generated: $($Template.Output)."
                }
            }
            finally {
                if (Test-Path -LiteralPath $TemporaryPath) { Remove-Item -LiteralPath $TemporaryPath }
            }
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
