#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Creates local nonsecret configuration from a successful Azure portal deployment.
.DESCRIPTION
    Reads Azure deployment metadata. Never creates cloud resources or approves prerequisites.
.PARAMETER AzureDeploymentName
    Subscription deployment record name shown in the Azure portal, not the deploymentName template parameter.
.PARAMETER ExistingCapacityId
    Existing Fabric capacity GUID. Required if the portal did not create a capacity.
.PARAMETER ConfigPath
    New configuration path. An existing file is never overwritten.
.EXAMPLE
    .\Initialize-Experience.ps1 -AzureDeploymentName Microsoft.Template-123 -ExistingCapacityId '<guid>'
.NOTES
    Sign in as the userObjectId supplied to the portal template.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$AzureDeploymentName,
    [string]$ExistingCapacityId,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'deploy\config\customer.json')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'deploy\scripts\Accelerator.psm1') -Force

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (Test-Path -LiteralPath $ConfigPath) { throw 'Configuration already exists. Review it or choose a new ConfigPath; it will not be overwritten.' }
        $Config = New-PortalCustomerConfig -AzureDeploymentName $AzureDeploymentName -ExistingCapacityId $ExistingCapacityId
        $TemporaryPath = "$ConfigPath.tmp"
        try {
            $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $TemporaryPath -Encoding utf8
            $null = Read-CustomerConfig -Path $TemporaryPath
            Move-Item -LiteralPath $TemporaryPath -Destination $ConfigPath
        }
        finally {
            if (Test-Path -LiteralPath $TemporaryPath) { Remove-Item -LiteralPath $TemporaryPath }
        }
        Write-Host "Created $ConfigPath. Review all administrator confirmations before running validate."
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
