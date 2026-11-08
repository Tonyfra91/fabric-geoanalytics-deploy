#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Tests the secure ARM credential step and metadata gate offline.
.DESCRIPTION
    Uses the real compiled template and lifecycle helpers with mocked ARM responses.
.PARAMETER RepositoryRoot
    Root of this checkout.
.EXAMPLE
    .\deploy\tests\Test-SecretProvisioning.ps1
.NOTES
    Never deploys resources, prompts for a credential, or retrieves a secret value.
#>
[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Module = Import-Module (Join-Path $RepositoryRoot 'deploy\scripts\Accelerator.psm1') -Force -PassThru
        & $Module {
            $script:CheckCount = 0
            function Assert-Check([string]$Name, [bool]$Condition) {
                if (-not $Condition) { throw "FAIL: $Name" }
                $script:CheckCount++
                Write-Host "PASS: $Name"
            }
            function Assert-Fails([string]$Name, [scriptblock]$Action, [string]$Pattern) {
                $Failure = $null
                try { & $Action | Out-Null } catch { $Failure = $_.Exception.Message }
                Assert-Check $Name ([bool]($Failure -and $Failure -match $Pattern))
            }
            $Template = Get-Content (Join-Path $script:Root 'deploy\secret-setup.azuredeploy.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 50
            Assert-Check 'Credential template is resource-group scoped' ($Template.'$schema' -match '/deploymentTemplate.json#')
            Assert-Check 'Exactly one secure credential input, without a default' (
                $Template.parameters.Count -eq 2 -and $Template.parameters.geoAnalyticsApiKey.type -eq 'securestring' -and
                -not $Template.parameters.geoAnalyticsApiKey.ContainsKey('defaultValue') -and $Template.parameters.geoAnalyticsApiKey.minLength -eq 1)
            $Resources = @($Template.resources)
            Assert-Check 'Only the secret child resource is deployed, never the existing vault or networking' (
                $Resources.Count -eq 1 -and $Resources[0].type -eq 'Microsoft.KeyVault/vaults/secrets' -and
                $Resources[0].apiVersion -eq '2025-05-01')
            Assert-Check 'Production secret name is fixed, enabled, and supplied unchanged from the secure parameter' (
                $Resources[0].name -eq "[format('{0}/{1}', parameters('keyVaultName'), 'geoanalytics-api-key')]" -and
                $Resources[0].properties.value -eq "[parameters('geoAnalyticsApiKey')]" -and
                $Resources[0].properties.attributes.enabled -eq $true)
            Assert-Check 'No outputs, debug settings, deployment scripts, or template-retrieval flag' (
                -not $Template.outputs -and ($Template | ConvertTo-Json -Depth 50) -notmatch 'debugSetting|deploymentScripts|enabledForTemplateDeployment')
            $script:Manifest = @{
                stage='Configured';subscriptionId='11111111-1111-1111-1111-111111111111'
                resourceGroupName='rg-offline';keyVaultName='kv-offline';resources=@{
                    keyVault=@{id='/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-offline/providers/Microsoft.KeyVault/vaults/kv-offline'}
                }
            }
            $script:VaultId = $script:Manifest.resources.keyVault.id
            $script:Calls = [System.Collections.Generic.List[object]]::new()
            $script:PublicAccess = 'Disabled'
            $script:Denied = $false
            $script:PageIndex = 0
            $script:Pages = @()
            function Reset-Pages {
                $script:PageIndex = 0
                $script:Calls.Clear()
                $script:Pages = @(@{value=@(@{
                    id="$script:VaultId/secrets/geoanalytics-api-key"
                    properties=@{attributes=@{enabled=$true};value='OFFLINE-SENSITIVE-SENTINEL'}
                })})
            }
            function script:Invoke-ServiceRequest {
                param([string]$Uri, [string]$Method='GET', [object]$Body, [string]$Audience)
                $script:Calls.Add(@{uri=$Uri;method=$Method;audience=$Audience})
                if ($Method -ne 'GET' -or $Audience -ne 'https://management.azure.com/') { throw 'Unexpected write or data-plane access.' }
                if ($script:Denied) { throw 'HTTP 403' }
                if ($Uri -eq "https://management.azure.com${script:VaultId}?api-version=2025-05-01") {
                    return @{Data=@{id=$script:VaultId;properties=@{publicNetworkAccess=$script:PublicAccess}}}
                }
                if ($script:PageIndex -ge $script:Pages.Count) { throw 'Unexpected extra request.' }
                $Page = $script:Pages[$script:PageIndex]
                $script:PageIndex++
                return @{Data=$Page}
            }
            function script:Read-DeploymentManifest { param([hashtable]$Config) return $script:Manifest }
            function script:Read-Host { throw 'A credential prompt must never run.' }
            Reset-Pages
            $Before = $script:Manifest | ConvertTo-Json -Depth 10 -Compress
            $Metadata = Get-GeoAnalyticsSecretMetadata $script:Manifest
            Assert-Check 'Enabled ARM metadata succeeds using only management-plane GETs' (
                $Metadata.enabled -eq $true -and $script:Calls.Count -eq 2 -and
                @($script:Calls | Where-Object { $_.method -ne 'GET' -or $_.audience -ne 'https://management.azure.com/' }).Count -eq 0)
            Assert-Check 'Metadata projection cannot return a provider value field' (
                ($Metadata | ConvertTo-Json) -notmatch 'SENTINEL|value' -and $Metadata.id -eq "$script:VaultId/secrets/geoanalytics-api-key")
            Assert-Check 'Metadata checks never persist or change deployment state' (($script:Manifest | ConvertTo-Json -Depth 10 -Compress) -ceq $Before)
            Reset-Pages
            $script:Pages = @(@{value=@()})
            Assert-Fails 'Missing production credential fails explicitly' { Test-SecretMetadata $script:Manifest } 'Missing geoanalytics-api-key'
            Reset-Pages
            $script:Pages[0].value[0].id = "$script:VaultId/secrets/fastpass-arm-probe"
            Assert-Fails 'A synthetic probe cannot satisfy the production credential gate' { Test-SecretMetadata $script:Manifest } 'Missing'
            foreach ($Attributes in @(@{enabled=$false},@{},@{enabled='true'},@{enabled=$true;exp=0},@{enabled=$true;nbf=99999999999})) {
                Reset-Pages
                $script:Pages[0].value[0].properties.attributes = $Attributes
                Assert-Fails 'Invalid, disabled, expired, or future metadata blocks execution' { Test-SecretMetadata $script:Manifest } 'disabled, expired'
            }
            Reset-Pages
            $script:Pages = @(@{value=@();nextLink="https://management.azure.com$script:VaultId/secrets?api-version=2025-05-01&skiptoken=offline"},$script:Pages[0])
            Test-SecretMetadata $script:Manifest
            Assert-Check 'ARM metadata pagination reaches the exact production secret' ($script:Calls.Count -eq 3)
            foreach ($Link in @('https://untrusted.invalid/secrets', "https://management.azure.com$script:VaultId/secrets/geoanalytics-api-key?api-version=2025-05-01", "https://management.azure.com$script:VaultId/secrets?api-version=2025-05-01")) {
                Reset-Pages
                $script:Pages = @(@{value=@();nextLink=$Link})
                Assert-Fails 'Untrusted, wrong-path, or repeated continuation is blocked' { Test-SecretMetadata $script:Manifest } 'continuation'
                Assert-Check 'Unsafe continuation is not requested' ($script:Calls.Count -eq 2)
            }
            Reset-Pages
            $script:Pages = @(@{value=@{}})
            Assert-Fails 'Malformed metadata fails closed' { Test-SecretMetadata $script:Manifest } 'Invalid'
            $script:Denied = $true
            Assert-Fails 'ARM permission failure is not hidden by a fallback' { Test-SecretMetadata $script:Manifest } '403'
            $script:Denied = $false
            $script:PublicAccess = 'Enabled'
            Assert-Fails 'Public vault access is rejected rather than changed' { Test-SecretMetadata $script:Manifest } 'Public network access must remain Disabled'
            $script:PublicAccess = 'Disabled'
            $script:Manifest.resources.keyVault.id = '/subscriptions/other/resourceGroups/other/providers/Microsoft.KeyVault/vaults/other'
            Reset-Pages
            Assert-Fails 'Wrong target vault is rejected before requests' { Test-SecretMetadata $script:Manifest } 'matching Key Vault ARM ID'
            Assert-Check 'Wrong-vault check issues no request' ($script:Calls.Count -eq 0)
            $script:Manifest.resources.keyVault.id = $script:VaultId
            Reset-Pages
            $script:Pages = @(@{value=@()})
            $Instructions = & { Set-GeoAnalyticsSecret -Config @{} } 6>&1 | Out-String
            Assert-Check 'Missing credential produces secure UI instructions, not a local prompt' (
                $Instructions -match 'Customer action required' -and $Instructions -match 'Load file' -and
                $Instructions -match 'verify-secret' -and $Instructions -notmatch 'SENTINEL')
            Reset-Pages
            $Instructions = & { Set-GeoAnalyticsSecret -Config @{} } 6>&1 | Out-String
            Assert-Check 'Existing credential is verified without resubmission or rotation' (
                $Instructions -match 'Secret metadata verified' -and $Instructions -notmatch 'Customer action required')
            Assert-Check 'Production secret handoff contains no credential-input or write implementation' (
                ${function:Set-GeoAnalyticsSecret}.ToString() -notmatch 'Read-Host|SecureString|Method\s+(PUT|POST)|-Body')
            Assert-Check 'Run retains the real metadata gate before runtime authorization' (
                ${function:Invoke-Simulation}.ToString().IndexOf('Test-SecretMetadata') -lt
                ${function:Invoke-Simulation}.ToString().IndexOf('Invoke-NotebookJob'))
            $PublicCommand = Get-Command -Name Test-GeoAnalyticsSecret -Module Accelerator
            Assert-Check 'Credential verification is exported for the CLI' (
                (Get-Module Accelerator).ExportedCommands.ContainsKey('Test-GeoAnalyticsSecret'))
            Reset-Pages
            & $PublicCommand -Config @{}
            Assert-Check 'Public verification command reaches the metadata gate' ($script:Calls.Count -eq 2)
            Reset-Pages
            $script:Pages = @(@{value=@()})
            Assert-Fails 'Public verification fails explicitly for a missing credential' {
                & $PublicCommand -Config @{}
            } 'Missing geoanalytics-api-key'
            Write-Host "Secure ARM secret checks passed: $script:CheckCount"
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
