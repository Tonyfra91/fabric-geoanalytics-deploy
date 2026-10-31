#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Compiles the Bicep source into the public Azure portal template.
.DESCRIPTION
    Check mode verifies the checked-in template without rewriting it.
.PARAMETER Check
    Fail if azuredeploy.json differs from freshly compiled Bicep.
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
    $TemplatePath = Join-Path $DeployRoot 'azuredeploy.json'
    $TemporaryPath = Join-Path $DeployRoot "azuredeploy.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        & az bicep build --file (Join-Path $DeployRoot 'main.bicep') --outfile $TemporaryPath
        if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
        if ($Check) {
            if (-not (Test-Path -LiteralPath $TemplatePath)) { throw 'Portal template is missing. Run Build-Template.ps1.' }
            $Compiled = (Get-Content -LiteralPath $TemporaryPath -Raw).Replace("`r`n","`n").Trim()
            $Published = (Get-Content -LiteralPath $TemplatePath -Raw).Replace("`r`n","`n").Trim()
            if ($Compiled -cne $Published) { throw 'Portal template is stale. Regenerate azuredeploy.json using Bicep 0.48.1 before committing.' }
            Write-Host 'Portal template matches Bicep source.'
        } else {
            Move-Item -LiteralPath $TemporaryPath -Destination $TemplatePath -Force
            Write-Host 'Portal template generated.'
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) { Remove-Item -LiteralPath $TemporaryPath }
    }
}
#endregion
