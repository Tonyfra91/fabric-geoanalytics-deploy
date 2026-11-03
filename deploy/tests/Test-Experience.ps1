#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Tests the Azure portal to Fabric handoff offline.
.DESCRIPTION
    Uses dependency-free Azure mocks and rejects mismatches before Fabric mutations.
.PARAMETER RepositoryRoot
    Root of the deployment experience.
.EXAMPLE
    .\deploy\tests\Test-Experience.ps1
.NOTES
    Never accesses Azure, Fabric, or secrets.
#>
[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Module = Import-Module (Join-Path $RepositoryRoot 'deploy\scripts\Accelerator.psm1') -Force -PassThru
        & $Module {
            $script:Count = 0
            function Assert-Check([string]$Name, [bool]$Condition) {
                if (-not $Condition) { throw "FAIL: $Name" }
                $script:Count++
                Write-Host "PASS: $Name"
            }
            function Assert-Fails([string]$Name, [scriptblock]$Action, [string]$Pattern) {
                $Failure = $null
                try { & $Action | Out-Null } catch { $Failure = $_.Exception.Message }
                Assert-Check $Name ([bool]($Failure -and $Failure -match $Pattern))
            }
            $script:Account = @{id='11111111-1111-1111-1111-111111111111';tenantId='22222222-2222-2222-2222-222222222222';user=@{type='user'}}
            $script:UserId = '33333333-3333-3333-3333-333333333333'
            $script:CapacityId = '44444444-4444-4444-4444-444444444444'
            $script:Azure = @{
                properties=@{
                    provisioningState='Succeeded'
                    parameters=@{
                        deploymentName=@{value='geo-demo'};location=@{value='centralus'}
                        resourceGroupName=@{value='rg-geo-demo'};keyVaultName=@{value='kv-geo-demo'}
                        userObjectId=@{value=$script:UserId};shouldCreateCapacity=@{value=$false}
                        capacityName=@{value=$null};capacitySku=@{value='F2'};capacityAdministrators=@{value=@()}
                    }
                    outputs=@{
                        experienceVersion=@{value='1.0'}
                        keyVaultUri=@{value='https://kv-geo-demo.vault.azure.net/'}
                        keyVaultId=@{value="/subscriptions/$($script:Account.id)/resourceGroups/rg-geo-demo/providers/Microsoft.KeyVault/vaults/kv-geo-demo"}
                        capacityResourceId=@{value=$null}
                    }
                }
            }
            $script:Calls = [System.Collections.Generic.List[string]]::new()
            function script:Invoke-AzJson {
                param([string[]]$Arguments)
                $script:Calls.Add(($Arguments -join ' '))
                if ($Arguments[0] -eq 'account') { return $script:Account }
                if ($Arguments[0] -eq 'ad') { return @{id=$script:UserId} }
                if (($Arguments[0..2] -join ' ') -eq 'deployment sub show') { return $script:Azure }
                if (($Arguments[0..1] -join ' ') -eq 'resource list') { return @(@{name='kv-geo-demo'}) }
                throw "Unexpected Azure mutation or request: $($Arguments -join ' ')"
            }
            $Config = New-PortalCustomerConfig -AzureDeploymentName 'portal-record' -ExistingCapacityId $script:CapacityId
            Assert-Check 'Existing capacity GUID retained' ($Config.capacity.id -eq $script:CapacityId)
            Assert-Check 'Portal parameters mapped, record name not confused with ownership name' ($Config.deploymentName -eq 'geo-demo')
            Assert-Check 'All five confirmations remain false' (@($Config.confirmations.Values | Where-Object { $_ -eq $false }).Count -eq 5)
            Assert-Check 'Names are generated safely' ($Config.lakehouseName -eq 'Geo_geo_demo')
            $null = Get-VerifiedAzureDeployment -Config $Config -DeploymentName 'portal-record'
            Assert-Check 'Successful matching Azure handoff accepted' $true
            Assert-Fails 'Missing existing capacity rejected' { New-PortalCustomerConfig -AzureDeploymentName 'portal-record' } 'ExistingCapacityId'
            Assert-Fails 'ARM capacity ID rejected' { New-PortalCustomerConfig -AzureDeploymentName 'portal-record' -ExistingCapacityId '/subscriptions/example/capacity' } 'GUID'
            $Config.location = 'westus'
            Assert-Fails 'Changed region rejected' { Get-VerifiedAzureDeployment $Config 'portal-record' } 'mismatch: location'
            $Config.location = 'centralus'
            $Config.tenantId = '55555555-5555-5555-5555-555555555555'
            Assert-Fails 'Changed tenant rejected' { Get-VerifiedAzureDeployment $Config 'portal-record' } 'account'
            $Config.tenantId = $script:Account.tenantId
            $script:Azure.properties.provisioningState = 'Failed'
            Assert-Fails 'Failed Azure deployment rejected' { Get-CompletedAzureDeployment 'portal-record' } 'not succeeded'
            $script:Azure.properties.provisioningState = 'Succeeded'
            $script:Azure.properties.outputs.experienceVersion.value = 'unknown'
            Assert-Fails 'Unknown handoff version rejected' { Get-CompletedAzureDeployment 'portal-record' } 'supported handoff'
            $script:Azure.properties.outputs.experienceVersion.value = '1.0'
            $script:Azure.properties.parameters.userObjectId.value = 'another-user'
            Assert-Fails 'Different executing user rejected' { Get-CompletedAzureDeployment 'portal-record' } 'signed-in user'
            $script:Azure.properties.parameters.userObjectId.value = $script:UserId
            $script:Azure.properties.outputs.keyVaultUri.value = 'https://unexpected.example/'
            Assert-Fails 'Unexpected vault endpoint rejected' { Get-CompletedAzureDeployment 'portal-record' } 'vault outputs'
            $script:Azure.properties.outputs.keyVaultUri.value = 'https://kv-geo-demo.vault.azure.net/'
            $script:Account.user.type = 'servicePrincipal'
            Assert-Fails 'Unattended identity rejected' { Get-CompletedAzureDeployment 'portal-record' } 'interactive user'
            $script:Account.user.type = 'user'
            $script:Azure.properties.parameters.shouldCreateCapacity.value = $true
            $script:Azure.properties.parameters.capacityName.value = 'geocapacity'
            $script:Azure.properties.parameters.capacityAdministrators.value = @('admin@customer.example')
            $script:Azure.properties.outputs.capacityResourceId.value = "/subscriptions/$($script:Account.id)/resourceGroups/rg-geo-demo/providers/Microsoft.Fabric/capacities/geocapacity"
            $NewConfig = New-PortalCustomerConfig -AzureDeploymentName 'portal-record'
            Assert-Check 'New capacity parameters preserved' ($NewConfig.capacity.mode -eq 'new' -and $NewConfig.capacity.name -eq 'geocapacity')
            Assert-Fails 'Conflicting capacity choice rejected' { New-PortalCustomerConfig -AzureDeploymentName 'portal-record' -ExistingCapacityId $script:CapacityId } 'Do not supply'
            $NewConfig.capacity.sku = 'F4'
            Assert-Fails 'Changed new capacity SKU rejected' { Get-VerifiedAzureDeployment $NewConfig 'portal-record' } 'new capacity'
            $script:Azure.properties.parameters.shouldCreateCapacity.value = $false
            Assert-Check 'Initialization and handoff verification issue only reads' (@($script:Calls | Where-Object { $_ -notmatch '^(account show|ad signed-in-user show|deployment sub show)' }).Count -eq 0)

            function script:Test-Prerequisite { param([hashtable]$Config) return @([pscustomobject]@{Status='Pass'}) }
            function script:Save-DeploymentManifest { param([hashtable]$Manifest) $script:SavedManifest = $Manifest }
            function script:Read-DeploymentManifest { param([hashtable]$Config) throw 'Offline test must not reuse a manifest.' }
            function script:Get-ServiceCollection {
                param([string]$Uri)
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces') {
                    return @(@{id='workspace';displayName='geo-demo GeoAnalytics';description='fabric-zombie-outbreak:geo-demo';capacityId=$script:CapacityId})
                }
                if ($Uri -match '/roleAssignments$') { return @(@{principal=@{id=$script:UserId};role='Admin'}) }
                throw "Unexpected service read: $Uri"
            }
            function script:Invoke-ServiceRequest { throw 'No HTTP mutation is expected before the offline stop.' }
            function script:Get-OrCreateFabricItem { throw 'Offline stop at first Fabric item.' }
            $script:StateDirectory = Join-Path ([IO.Path]::GetTempPath()) "geo-handoff-$([guid]::NewGuid().ToString('N'))"
            try {
                Assert-Fails 'Portal handoff reaches Fabric without deploying Azure again' { Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record' } 'Offline stop'
                Assert-Check 'No Azure create or what-if command issued' (@($script:Calls | Where-Object { $_ -match '^deployment sub (create|what-if)' }).Count -eq 0)
                Assert-Check 'Azure stage persisted with verified outputs' ($script:SavedManifest.keyVaultUri -eq 'https://kv-geo-demo.vault.azure.net/')
                Assert-Fails 'WhatIf cannot silently start Fabric handoff' { Invoke-Deployment $Config -WhatIf -AzureDeploymentName 'portal-record' } 'cannot be combined'
            }
            finally {
                $ParameterPath = Join-Path $script:StateDirectory 'geo-demo.parameters.json'
                if (Test-Path -LiteralPath $ParameterPath) { Remove-Item -LiteralPath $ParameterPath }
                if (Test-Path -LiteralPath $script:StateDirectory) { Remove-Item -LiteralPath $script:StateDirectory }
            }
            Write-Host "Experience checks passed: $script:Count"
        }
        $Template = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy\azuredeploy.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        if ($Template.'$schema' -notmatch 'subscriptionDeploymentTemplate') { throw 'Portal template must be subscription scoped.' }
        if ($Template.outputs.experienceVersion.value -ne '1.0') { throw 'Portal template handoff version mismatch.' }
        if ($Template.parameters.shouldCreateCapacity.defaultValue -ne $false) { throw 'New capacity must remain opt-in.' }
        if (@($Template.parameters.Keys | Where-Object { $_ -match 'secret|password|token|apiKey' }).Count) {
            throw 'Portal template must not accept workload secrets.'
        }
        foreach ($File in Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -Filter '*.md' -File) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            foreach ($Match in [regex]::Matches($Content, '\]\((\.\.?/[^)]+)\)')) {
                $Parts = $Match.Groups[1].Value -split '#',2
                $Target = [IO.Path]::GetFullPath((Join-Path $File.DirectoryName ($Parts[0] -replace '/', [IO.Path]::DirectorySeparatorChar)))
                if (-not (Test-Path -LiteralPath $Target)) { throw "Broken documentation link in $($File.Name): $($Match.Groups[1].Value)" }
                if ($Parts.Count -eq 2) {
                    $TargetContent = Get-Content -LiteralPath $Target -Raw
                    $Anchors = @([regex]::Matches($TargetContent, '(?m)^#{1,6} (.+)\r?$') | ForEach-Object {
                        ($_.Groups[1].Value.Trim().ToLowerInvariant() -replace '[^\w\s-]','' -replace '\s','-')
                    })
                    if ($Parts[1] -notin $Anchors) { throw "Broken heading link in $($File.Name): $($Match.Groups[1].Value)" }
                }
            }
        }
        $ExpectedUrl = 'https://raw.githubusercontent.com/Tonyfra91/fabric-geoanalytics-deploy/v0.1.0/deploy/azuredeploy.json'
        foreach ($Path in @('README.md','docs\getting-started.md')) {
            $Content = Get-Content -LiteralPath (Join-Path $RepositoryRoot $Path) -Raw
            $Button = [regex]::Match($Content, 'https://portal\.azure\.com/#create/Microsoft\.Template/uri/([^)]+)')
            if (-not $Button.Success -or [uri]::UnescapeDataString($Button.Groups[1].Value) -cne $ExpectedUrl) {
                throw "Deployment button is missing or points to the wrong release in $Path."
            }
        }
        $SkillPath = Join-Path $RepositoryRoot '.github\skills\fabric-geoanalytics-fast-pass\SKILL.md'
        $Skill = Get-Content -LiteralPath $SkillPath -Raw
        $Header = [regex]::Match($Skill, '\A---\r?\n(?<fields>.*?)\r?\n---\r?\n', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $Header.Success) { throw 'Fast Pass skill requires YAML frontmatter.' }
        $Fields = $Header.Groups['fields'].Value
        $Name = [regex]::Match($Fields, '(?m)^name: (?<name>[a-z0-9]+(?:-[a-z0-9]+)*)\r?$').Groups['name'].Value
        if ($Name -ne (Split-Path (Split-Path $SkillPath -Parent) -Leaf) -or $Name.Length -gt 64) {
            throw 'Fast Pass skill name must match its folder and discovery constraints.'
        }
        $Description = [regex]::Match($Fields, '(?m)^description: "(?<description>[^"\r\n]+)"\r?$').Groups['description'].Value
        if (-not $Description -or $Description.Length -gt 1024 -or $Description -notmatch 'Fast Pass') {
            throw 'Fast Pass skill discovery description is missing or invalid.'
        }
        if ($Fields -notmatch '(?m)^user-invocable: true\r?$' -or
            $Fields -notmatch '(?m)^disable-model-invocation: false\r?$') {
            throw 'Fast Pass skill must remain discoverable and directly user-invocable.'
        }
        $FastPass = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'docs\copilot-fast-pass.md') -Raw
        $Steps = @([regex]::Matches($FastPass, '(?m)^## FP(?<number>\d\d) '))
        if ($Steps.Count -ne 16 -or
            (@($Steps | ForEach-Object { [int]$_.Groups['number'].Value }) -join ',') -ne ((1..16) -join ',')) {
            throw 'Fast Pass guide must contain FP01-FP16 in order.'
        }
        Write-Host 'PASS: Fast Pass skill discovery metadata, user invocation and 16 ordered guide steps.'
        Write-Host 'PASS: Portal scope, handoff version, opt-in capacity, secret boundaries, documentation links, and release button URLs.'
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
