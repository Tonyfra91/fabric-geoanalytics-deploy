#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Compiles the foundation and secure credential Azure portal templates.
.DESCRIPTION
    Check mode verifies the checked-in template without rewriting it.
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
                    $Compiled = (Get-Content -LiteralPath $TemporaryPath -Raw).Replace("`r`n","`n").Trim()
                    $Published = (Get-Content -LiteralPath $TemplatePath -Raw).Replace("`r`n","`n").Trim()
                    if ($Compiled -cne $Published) { throw "Portal template is stale: $($Template.Output). Regenerate using Bicep 0.48.1." }
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
