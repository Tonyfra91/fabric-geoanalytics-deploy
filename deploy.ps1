#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
Lifecycle commands for the Fabric GeoAnalytics Fast Pass.
.DESCRIPTION
    Separates read-only validation, provisioning, secret setup, and execution.
.PARAMETER Command
    Lifecycle operation. Omit for help.
.PARAMETER ConfigPath
    Nonsecret customer configuration.
.PARAMETER ParametersPath
    Optional JSON object of simulation parameters for run.
.PARAMETER WhatIf
    Run Azure deployment what-if instead of provisioning.
.PARAMETER AzureDeploymentName
    Complete Fabric setup from an existing successful subscription deployment without redeploying Azure.
.EXAMPLE
    .\deploy.ps1 validate -ConfigPath .\deploy\config\customer.json
.NOTES
    Uses the interactive Azure CLI user; never accepts a credential parameter.
#>
[CmdletBinding()]
param(
    [ValidateSet('help', 'validate', 'deploy', 'configure-network', 'configure-secret', 'verify-secret', 'run', 'view-results', 'status', 'remove')]
    [string]$Command = 'help',
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'deploy\config\customer.json'),
    [string]$ParametersPath,
    [string]$AzureDeploymentName,
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'deploy\scripts\Accelerator.psm1') -Force

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($Command -eq 'help') {
            Write-Host @'
One-Command Deployment
Bicep-led deployment automation for Azure and Microsoft Fabric resources

  .\deploy.ps1 validate [-ConfigPath <file>]
  .\deploy.ps1 deploy [-WhatIf]
  .\deploy.ps1 deploy -AzureDeploymentName <portal-deployment-name>
  .\deploy.ps1 configure-network
  .\deploy.ps1 configure-secret
  .\deploy.ps1 verify-secret
  .\deploy.ps1 run [-ParametersPath <file>]
  .\deploy.ps1 view-results
  .\deploy.ps1 status

Copy deploy\config\customer.sample.json to customer.json first.
Deployment never executes a notebook. Removal is intentionally not automated.
view-results prepares the Results notebook only; open it and Run all in Fabric.
'@
        }
        elseif ($Command -eq 'remove') {
            throw 'Removal is not implemented: automatic ownership-safe deletion has not been verified. See deploy\README.md.'
        }
        else {
            if ($AzureDeploymentName -and ($Command -ne 'deploy' -or $WhatIf)) {
                throw 'AzureDeploymentName is only supported for deploy without WhatIf.'
            }
            $Config = Read-CustomerConfig -Path $ConfigPath
            switch ($Command) {
                'validate' {
                    $Report = Test-Prerequisite -Config $Config
                    $Report | Format-Table -AutoSize -Wrap | Out-Host
                    if (@($Report | Where-Object Status -eq 'Fail').Count) { exit 1 }
                    if (@($Report | Where-Object Status -eq 'Manual').Count) { exit 2 }
                }
                'deploy' { Invoke-Deployment -Config $Config -WhatIf:$WhatIf -AzureDeploymentName $AzureDeploymentName }
                'configure-network' { Set-DeploymentNetwork -Config $Config }
                'configure-secret' { Set-GeoAnalyticsSecret -Config $Config }
                'verify-secret' {
                    Test-GeoAnalyticsSecret -Config $Config
                    Write-Host 'Secret metadata verified; runtime access is checked during run.'
                }
                'run' { Invoke-Simulation -Config $Config -ParametersPath $ParametersPath }
                'view-results' { Publish-ResultsNotebook -Config $Config }
                'status' { Get-DeploymentStatus -Config $Config | ConvertTo-Json -Depth 20 | Out-Host }
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
