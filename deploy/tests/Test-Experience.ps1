#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Tests the Azure portal to Fabric handoff offline.
.DESCRIPTION
    Uses dependency-free Azure mocks and rejects mismatches before Fabric mutations.
    Checks guide navigation, reader checkpoints, and the compact diagram/source.
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
            $ConfigPath = Join-Path ([IO.Path]::GetTempPath()) "geo-config-$([guid]::NewGuid().ToString('N')).json"
            try {
                $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
                $Validated = Read-CustomerConfig -Path $ConfigPath
                Assert-Check 'Generated configuration passes the real configuration reader' ($Validated.environmentName -eq 'geo-demo Runtime 1-3')
                $Sample = Get-Content -LiteralPath (Join-Path $script:Root 'deploy\config\customer.sample.json') -Raw | ConvertFrom-Json -AsHashtable
                $Sample.subscriptionId = $script:Account.id
                $Sample.tenantId = $script:Account.tenantId
                $Sample.capacity.id = $script:CapacityId
                $Sample | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
                $Validated = Read-CustomerConfig -Path $ConfigPath
                Assert-Check 'Sample configuration passes the real reader after supplying GUIDs' ($Validated.environmentName -eq 'GeoAnalytics Runtime 1-3')
            } finally {
                if (Test-Path -LiteralPath $ConfigPath) { Remove-Item -LiteralPath $ConfigPath }
            }
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
            $script:WorkspaceCapacityId = $script:CapacityId
            $script:FabricCalls = [System.Collections.Generic.List[string]]::new()
            function script:Get-ServiceCollection {
                param([string]$Uri)
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces') {
                    return @(@{id='workspace';displayName='geo-demo GeoAnalytics';description='fabric-zombie-outbreak:geo-demo';capacityId=$script:WorkspaceCapacityId})
                }
                if ($Uri -match '/roleAssignments$') { return @(@{principal=@{id=$script:UserId};role='Admin'}) }
                throw "Unexpected service read: $Uri"
            }
            function script:Invoke-ServiceRequest {
                param([string]$Uri, [string]$Method = 'GET', [object]$Body)
                $script:FabricCalls.Add("$Method $Uri")
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces/workspace/assignToCapacity' -and $Method -eq 'POST') {
                    if ($Body.capacityId -ne $script:CapacityId) { throw 'Unexpected capacity assignment target.' }
                    return @{StatusCode=202;Headers=@{}}
                }
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces/workspace' -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{id='workspace';capacityId=$script:CapacityId}}
                }
                throw 'Unexpected HTTP call before the offline stop.'
            }
            function script:Get-OrCreateFabricItem { $script:ItemAttempted=$true; throw 'Offline stop at first Fabric item.' }
            function script:Initialize-KeyVaultManagedPrivateEndpoint {
                param([hashtable]$Manifest)
                if ($script:PendingNetwork) { throw 'Azure approval Pending offline checkpoint.' }
                return @{provisioningState='Succeeded';approvalState='Approved'}
            }
            $script:StateDirectory = Join-Path ([IO.Path]::GetTempPath()) "geo-handoff-$([guid]::NewGuid().ToString('N'))"
            try {
                Assert-Fails 'Portal handoff reaches Fabric without deploying Azure again' { Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record' } 'Offline stop'
                Assert-Check 'Already assigned workspace does not resubmit capacity assignment' ($script:FabricCalls.Count -eq 0)
                $script:WorkspaceCapacityId = $null
                Assert-Fails 'Capacity assignment 202 without Location reaches the first Fabric item' {
                    Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record'
                } 'Offline stop'
                Assert-Check 'Capacity assignment is submitted once and verified by a workspace GET' (
                    $script:FabricCalls.Count -eq 2 -and
                    $script:FabricCalls[0] -eq 'POST https://api.fabric.microsoft.com/v1/workspaces/workspace/assignToCapacity' -and
                    $script:FabricCalls[1] -eq 'GET https://api.fabric.microsoft.com/v1/workspaces/workspace')
                Assert-Check 'No Azure create or what-if command issued' (@($script:Calls | Where-Object { $_ -match '^deployment sub (create|what-if)' }).Count -eq 0)
                Assert-Check 'Azure stage persisted with verified outputs' ($script:SavedManifest.keyVaultUri -eq 'https://kv-geo-demo.vault.azure.net/')
                Assert-Fails 'WhatIf cannot silently start Fabric handoff' { Invoke-Deployment $Config -WhatIf -AzureDeploymentName 'portal-record' } 'cannot be combined'

                $script:WorkspaceCapacityId = $script:CapacityId
                $script:FabricCalls.Clear()
                $script:ItemAttempted=$false
                $script:PendingNetwork=$true
                Assert-Fails 'Pending endpoint approval stops Fabric finish before item mutation' {
                    Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record'
                } 'Azure approval Pending'
                Assert-Check 'Pending approval neither imports nor republishes existing assets' (
                    -not $script:ItemAttempted -and $script:FabricCalls.Count -eq 0)
                $script:PendingNetwork=$false
                $script:PublishScenario = 'success'
                $script:EnvironmentReads = 0
                $script:FabricCalls.Clear()
                function script:Get-OrCreateFabricItem {
                    param([string]$WorkspaceId, [string]$Name, [string]$Type, [string]$Owner, [hashtable]$Definition)
                    $script:FabricCalls.Add("ITEM $Type")
                    return @{id="$Type-id";created=$false}
                }
                function script:New-DeployableNotebook { return @{cells=@();metadata=@{}} }
                function script:Get-DeploymentStatus { param([hashtable]$Config) return @{stage=$script:SavedManifest.stage;managedPrivateEndpointReady=$true} }
                function script:Start-Sleep { param([int]$Seconds) }
                function script:Invoke-ServiceRequest {
                    param([string]$Uri, [string]$Method = 'GET', [object]$Body)
                    $script:FabricCalls.Add("$Method $Uri")
                    $EnvironmentBase = 'https://api.fabric.microsoft.com/v1/workspaces/workspace/environments/Environment-id'
                    if ($Uri -eq "$EnvironmentBase/staging/sparkcompute?beta=false" -and $Method -eq 'PATCH') {
                        return @{StatusCode=200;Data=@{}}
                    }
                    if ($Uri -eq "$EnvironmentBase/staging/publish?beta=false" -and $Method -eq 'POST') {
                        return @{StatusCode=202;Headers=@{Location='https://wabi-us-central-b-primary-redirect.analysis.windows.net/offline-operation'}}
                    }
                    if ($Uri -eq $EnvironmentBase -and $Method -eq 'GET') {
                        $script:EnvironmentReads++
                        $State = if ($script:EnvironmentReads -eq 1) { 'Success' } elseif ($script:PublishScenario -eq 'failed') {
                            'Failed'
                        } elseif ($script:EnvironmentReads -eq 2) { 'Running' } else { 'Success' }
                        return @{StatusCode=200;Data=@{properties=@{publishDetails=@{state=$State}}}}
                    }
                    if ($Uri -eq "$EnvironmentBase/sparkcompute?beta=false" -and $Method -eq 'GET') {
                        return @{StatusCode=200;Data=@{runtimeVersion='1.3';sparkProperties=@(@{key='spark.native.enabled';value='false'})}}
                    }
                    if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces/workspace/items/Notebook-id/updateDefinition' -and $Method -eq 'POST') {
                        if (-not $Body.definition.parts -or $Body.parts) { throw 'Notebook update must wrap the definition in the documented request body.' }
                        return @{StatusCode=202;Headers=@{
                            Location='https://wabi-us-central-b-primary-redirect.analysis.windows.net/offline-update'
                            'x-ms-operation-id'='66666666-6666-4666-8666-666666666666';'Retry-After'='0'
                        }}
                    }
                    if ($Uri -eq 'https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666' -and $Method -eq 'GET') {
                        return @{StatusCode=200;Headers=@{};Data=@{status='Succeeded'}}
                    }
                    throw 'Unexpected HTTP call in offline Environment publication checks.'
                }
                Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record'
                Assert-Check 'Regional publication Location does not block a verified Fabric finish' (
                    $script:SavedManifest.stage -eq 'Configured' -and $script:SavedManifest.notebookId -eq 'Notebook-id')
                Assert-Check 'Environment publication never follows the regional Location' (
                    @($script:FabricCalls | Where-Object { $_ -match 'analysis.windows.net' }).Count -eq 0)
                Assert-Check 'Notebook resume update uses the canonical resultless operation contract' (
                    $script:FabricCalls.Contains('POST https://api.fabric.microsoft.com/v1/workspaces/workspace/items/Notebook-id/updateDefinition') -and
                    $script:FabricCalls.Contains('GET https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666') -and
                    -not $script:FabricCalls.Contains('GET https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666/result'))
                $EnvironmentGet = 'GET https://api.fabric.microsoft.com/v1/workspaces/workspace/environments/Environment-id'
                Assert-Check 'Notebook import waits for trusted Environment polling to report Success' (
                    $script:EnvironmentReads -eq 3 -and
                    $script:FabricCalls.IndexOf('ITEM Notebook') -gt $script:FabricCalls.LastIndexOf($EnvironmentGet))
                $script:PublishScenario = 'failed'
                $script:EnvironmentReads = 0
                $script:FabricCalls.Clear()
                Assert-Fails 'Failed Environment publication blocks Fabric finish despite accepted submission' {
                    Invoke-Deployment -Config $Config -AzureDeploymentName 'portal-record'
                } 'publication did not succeed: Failed'
                Assert-Check 'Failed Environment publication never imports a Notebook' (-not $script:FabricCalls.Contains('ITEM Notebook'))
            }
            finally {
                $ParameterPath = Join-Path $script:StateDirectory 'geo-demo.parameters.json'
                if (Test-Path -LiteralPath $ParameterPath) { Remove-Item -LiteralPath $ParameterPath }
                $NotebookPath = Join-Path $script:StateDirectory 'Zombie_Outbreak_Deployable.ipynb'
                if (Test-Path -LiteralPath $NotebookPath) { Remove-Item -LiteralPath $NotebookPath }
                if (Test-Path -LiteralPath $script:StateDirectory) { Remove-Item -LiteralPath $script:StateDirectory }
            }
            Write-Host "Experience checks passed: $script:Count"
        }
        & {
            $BuildRoot = Join-Path ([IO.Path]::GetTempPath()) "geo-bicep-$([guid]::NewGuid().ToString('N'))"
            $BuildScript = Join-Path $BuildRoot 'scripts\Build-Template.ps1'
            $CompiledTemplates = @{}
            $BuildExitCode = 0
            function az {
                param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
                if (($Arguments[0..1] -join ' ') -ne 'bicep build') { throw 'Unexpected CLI call in offline template checks.' }
                $Source = Split-Path $Arguments[[array]::IndexOf($Arguments, '--file') + 1] -Leaf
                $Output = $Arguments[[array]::IndexOf($Arguments, '--outfile') + 1]
                if ($BuildExitCode -eq 0) { Set-Content -LiteralPath $Output -Value $CompiledTemplates[$Source] -Encoding utf8 }
                $global:LASTEXITCODE = $BuildExitCode
            }
            try {
                $null = New-Item -ItemType Directory -Path (Join-Path $BuildRoot 'scripts')
                Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'deploy\scripts\Build-Template.ps1') -Destination $BuildScript
                $Originals = @{}
                foreach ($Pair in @(
                    @{source='main.bicep';output='azuredeploy.json'},
                    @{source='secret-setup.bicep';output='secret-setup.azuredeploy.json'}
                )) {
                    $Originals[$Pair.source] = Get-Content -LiteralPath (Join-Path $RepositoryRoot "deploy\$($Pair.output)") -Raw
                    Copy-Item -LiteralPath (Join-Path $RepositoryRoot "deploy\$($Pair.output)") -Destination (Join-Path $BuildRoot $Pair.output)
                }
                $Cases = @(
                    @{name='original 0.48.1 compiler output';kind='original';exit=0},
                    @{name='0.49.x root and nested compiler provenance only';kind='compiler';exit=0},
                    @{name='parameter default drift';kind='parameter';exit=1},
                    @{name='nested resource drift';kind='resource';exit=1},
                    @{name='output expression drift';kind='output';exit=1},
                    @{name='noncompiler metadata drift';kind='metadata';exit=1},
                    @{name='generator name drift';kind='generator';exit=1},
                    @{name='credential template drift';kind='credential';exit=1},
                    @{name='compiler failure';kind='failure';exit=1}
                )
                foreach ($Case in $Cases) {
                    foreach ($Source in $Originals.Keys) {
                        $CompiledTemplates[$Source] = $Originals[$Source]
                        if ($Case.kind -ne 'original') {
                            $CompiledTemplates[$Source] = $CompiledTemplates[$Source].Replace('0.48.1.52935','0.49.2.12345') -replace '"templateHash": "\d+"','"templateHash": "12345"'
                        }
                    }
                    $BuildExitCode = if ($Case.kind -eq 'failure') { 1 } else { 0 }
                    switch ($Case.kind) {
                        'parameter' {
                            $CompiledTemplates['main.bicep'] = $CompiledTemplates['main.bicep'].Replace('"defaultValue": "F2"','"defaultValue": "F4"')
                        }
                        'resource' {
                            $CompiledTemplates['main.bicep'] = $CompiledTemplates['main.bicep'].Replace('"publicNetworkAccess": "Disabled"','"publicNetworkAccess": "Enabled"')
                        }
                        'output' {
                            $CompiledTemplates['main.bicep'] = $CompiledTemplates['main.bicep'].Replace('"value": "1.0"','"value": "changed"')
                        }
                        'metadata' {
                            $CompiledTemplates['main.bicep'] = $CompiledTemplates['main.bicep'].Replace('"name": "Fabric GeoAnalytics deployment experience"','"name": "changed"')
                        }
                        'generator' {
                            $CompiledTemplates['main.bicep'] = $CompiledTemplates['main.bicep'].Replace('"name": "bicep"','"name": "changed"')
                        }
                        'credential' {
                            $CompiledTemplates['secret-setup.bicep'] = $CompiledTemplates['secret-setup.bicep'].Replace('"type": "securestring"','"type": "string"')
                        }
                    }
                    $BuildOutput = & $BuildScript -Check *>&1 | Out-String
                    if ($LASTEXITCODE -ne $Case.exit -or
                        ($Case.exit -eq 0 -and [regex]::Matches($BuildOutput, 'Portal template matches Bicep source:').Count -ne 2) -or
                        ($Case.exit -eq 1 -and $BuildOutput -notmatch 'Portal template is stale|Bicep compilation failed')) {
                        throw "Template check did not handle $($Case.name): $BuildOutput"
                    }
                    if (@(Get-ChildItem -LiteralPath $BuildRoot -Filter '*.tmp').Count) { throw 'Template check left temporary compiler output behind.' }
                    Write-Host "PASS: Template freshness handles $($Case.name)"
                }
                foreach ($Pair in @(
                    @{source='main.bicep';output='azuredeploy.json'},
                    @{source='secret-setup.bicep';output='secret-setup.azuredeploy.json'}
                )) {
                    if ((Get-Content -LiteralPath (Join-Path $BuildRoot $Pair.output) -Raw) -cne $Originals[$Pair.source]) {
                        throw 'Check mode must never rewrite published templates.'
                    }
                }
                Write-Host "Bicep template compatibility checks passed: $($Cases.Count); published templates unchanged."
            }
            finally {
                if (Test-Path -LiteralPath $BuildRoot) { Remove-Item -LiteralPath $BuildRoot -Recurse }
            }
        }
        $Template = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy\azuredeploy.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        if ($Template.'$schema' -notmatch 'subscriptionDeploymentTemplate') { throw 'Portal template must be subscription scoped.' }
        if ($Template.outputs.experienceVersion.value -ne '1.0') { throw 'Portal template handoff version mismatch.' }
        if ($Template.parameters.shouldCreateCapacity.defaultValue -ne $false) { throw 'New capacity must remain opt-in.' }
        if (@($Template.parameters.Keys | Where-Object {
            $_ -match 'secret|password|token|apiKey' -or
            $Template.parameters[$_].type -in @('secureString','secureObject')
        }).Count) {
            throw 'Portal template must not accept workload secrets.'
        }
        $Foundations = @($Template.resources.Values | Where-Object { $_.properties.template.outputs.privateEndpointId })
        if ($Foundations.Count -ne 1) { throw 'Portal template must contain one private Key Vault foundation.' }
        $Foundation = $Foundations[0].properties.template
        $Vaults = @($Foundation.resources | Where-Object type -eq 'Microsoft.KeyVault/vaults')
        if ($Vaults.Count -ne 1 -or $Vaults[0].properties.publicNetworkAccess -ne 'Disabled' -or
            $Vaults[0].properties.networkAcls.defaultAction -ne 'Deny' -or
            $Vaults[0].properties.networkAcls.bypass -ne 'None' -or
            $Vaults[0].properties.enableRbacAuthorization -ne $true) {
            throw 'Key Vault must retain RBAC and disable public access without a firewall bypass.'
        }
        $Networks = @($Foundation.resources | Where-Object type -eq 'Microsoft.Network/virtualNetworks')
        if ($Networks.Count -ne 1 -or $Networks[0].name -ne "[parameters('virtualNetworkName')]" -or
            $Networks[0].properties.addressSpace.addressPrefixes[0] -ne "[parameters('virtualNetworkAddressPrefix')]" -or
            $Networks[0].properties.subnets.Count -ne 1 -or
            $Networks[0].properties.subnets[0].name -ne "[parameters('privateEndpointSubnetName')]" -or
            $Networks[0].properties.subnets[0].properties.addressPrefix -ne "[parameters('privateEndpointSubnetPrefix')]" -or
            $Networks[0].properties.subnets[0].properties.privateEndpointNetworkPolicies -ne 'Disabled') {
            throw 'Private endpoint network and dedicated subnet must use customer parameters.'
        }
        $Endpoints = @($Foundation.resources | Where-Object type -eq 'Microsoft.Network/privateEndpoints')
        if ($Endpoints.Count -ne 1 -or $Endpoints[0].name -ne "[parameters('privateEndpointName')]" -or
            $Endpoints[0].properties.customNetworkInterfaceName -ne "[parameters('privateEndpointNetworkInterfaceName')]" -or
            $Endpoints[0].properties.ContainsKey('ipConfigurations') -or
            $Endpoints[0].properties.subnet.id -ne "[format('{0}/subnets/{1}', resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworkName')), parameters('privateEndpointSubnetName'))]" -or
            $Endpoints[0].properties.privateLinkServiceConnections.Count -ne 1 -or
            $Endpoints[0].properties.privateLinkServiceConnections[0].properties.groupIds[0] -ne 'vault' -or
            $Endpoints[0].properties.privateLinkServiceConnections[0].properties.privateLinkServiceId -notmatch "resourceId\('Microsoft.KeyVault/vaults', parameters\('name'\)\)") {
            throw 'Private endpoint must target the deployed vault with a dynamically allocated IP and parameterized NIC.'
        }
        $Zones = @($Foundation.resources | Where-Object type -eq 'Microsoft.Network/privateDnsZones')
        $Links = @($Foundation.resources | Where-Object type -eq 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
        $ZoneGroups = @($Foundation.resources | Where-Object type -eq 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups')
        if ($Zones.Count -ne 1 -or $Zones[0].name -ne 'privatelink.vaultcore.azure.net' -or
            $Links.Count -ne 1 -or $Links[0].properties.registrationEnabled -ne $false -or
            $Links[0].properties.virtualNetwork.id -notmatch "resourceId\('Microsoft.Network/virtualNetworks', parameters\('virtualNetworkName'\)\)" -or
            $ZoneGroups.Count -ne 1 -or $ZoneGroups[0].properties.privateDnsZoneConfigs.Count -ne 1 -or
            $ZoneGroups[0].properties.privateDnsZoneConfigs[0].properties.privateDnsZoneId -notmatch 'privatelink.vaultcore.azure.net') {
            throw 'Private DNS zone, VNet link, and endpoint zone group must be wired to the deployed resources.'
        }
        if (@($Foundation.resources | Where-Object { $_.type -in @('Microsoft.Compute/virtualMachines','Microsoft.Network/publicIPAddresses','Microsoft.Network/bastionHosts','Microsoft.Network/virtualNetworkGateways') }).Count -or
            ($Foundation | ConvertTo-Json -Depth 100) -match 'SecurityControl|10\.0\.0\.4') {
            throw 'Private foundation must not introduce bootstrap compute, public IPs, exclusion tags, or a fixed endpoint IP.'
        }
        foreach ($Parameter in @('virtualNetworkName','virtualNetworkAddressPrefix','privateEndpointSubnetName',
            'privateEndpointSubnetPrefix','privateEndpointName','privateEndpointNetworkInterfaceName','privateDnsLinkName')) {
            if (-not $Template.parameters[$Parameter].ContainsKey('defaultValue') -or
                $Foundations[0].properties.parameters[$Parameter].value -ne "[parameters('$Parameter')]") {
                throw "Private network parameter is missing a default or module wiring: $Parameter"
            }
        }
        Write-Host 'Private Azure foundation contracts passed.'
        foreach ($File in Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -Filter '*.md' -File) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            foreach ($Match in [regex]::Matches($Content, '\]\((\.\.?/[^)]+|#[^)]+)\)')) {
                $Parts = $Match.Groups[1].Value -split '#',2
                $Target = if ($Parts[0]) {
                    [IO.Path]::GetFullPath((Join-Path $File.DirectoryName ($Parts[0] -replace '/', [IO.Path]::DirectorySeparatorChar)))
                } else {
                    $File.FullName
                }
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
        $TemplateCommit = '357293c2c850d855aa511bb08ead30736bacf5e5'
        $RawTemplateUrl = "https://raw.githubusercontent.com/Tonyfra91/fabric-geoanalytics-deploy/$TemplateCommit/deploy/azuredeploy.json"
        $PortalBase = 'https://portal.azure.com/#create/Microsoft.Template/uri/'
        $PortalUrl = $PortalBase + [uri]::EscapeDataString($RawTemplateUrl)
        $TemplateText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy\azuredeploy.json') -Raw -Encoding utf8
        $TemplateHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes(($TemplateText -replace "`r`n","`n"))))
        if ($TemplateHash -cne '7F5D7698D6B3A915F5012D91AC8B22B0A0A243AF96365EB2E85F7E425B7EBD50') {
            throw 'Compiled foundation differs from the approved button pin; verify and update the pin before publishing.'
        }
        function Assert-PrivateAzureButton([string]$Content) {
            $Badges = [regex]::Matches($Content, '\[!\[[^\]\r\n]*\]\((?<image>[^)\r\n]+)\)\]\((?<target>[^)\r\n]+)\)')
            if ($Badges.Count -ne 1 -or
                $Badges[0].Groups['image'].Value -cne 'https://aka.ms/deploytoazurebutton' -or
                $Badges[0].Value -notmatch '^\[!\[Deploy to Azure\]' -or
                $Badges[0].Groups['target'].Value -cne $PortalUrl) {
                throw 'Step 13 requires exactly one Microsoft Deploy to Azure badge targeting the approved immutable private template.'
            }
            $DecodedUrl = [uri]::UnescapeDataString($Badges[0].Groups['target'].Value.Substring($PortalBase.Length))
            if ($DecodedUrl -cnotmatch '^https://raw\.githubusercontent\.com/Tonyfra91/fabric-geoanalytics-deploy/[a-f0-9]{40}/deploy/azuredeploy\.json$' -or
                $DecodedUrl -cne $RawTemplateUrl) {
                throw 'Azure button must load only the approved commit-pinned compiled foundation without credential parameters.'
            }
            $Step13 = $Content.IndexOf('### Step 13 ')
            $Step14 = $Content.IndexOf('### Step 14 ')
            if ($Step13 -lt 0 -or $Step14 -le $Step13 -or
                $Badges[0].Index -le $Step13 -or $Badges[0].Index -ge $Step14) {
                throw 'Azure button must remain inside Step 13, after preparation and before Fabric handoff.'
            }
        }
        $ButtonGuide = Get-Content -LiteralPath (Join-Path $RepositoryRoot '02-deploy-azure\manual.md') -Raw
        Assert-PrivateAzureButton $ButtonGuide
        $Badge = [regex]::Match($ButtonGuide, '\[!\[Deploy to Azure\]\([^)]+\)\]\([^)]+\)')
        $InvalidButtons = @(
            @{name='missing button';content=$ButtonGuide.Replace($Badge.Value,'')},
            @{name='non-Microsoft image';content=$ButtonGuide.Replace('https://aka.ms/deploytoazurebutton','https://example.invalid/button.png')},
            @{name='non-Azure portal';content=$ButtonGuide.Replace($PortalBase,'https://example.invalid/uri/')},
            @{name='mutable main';content=$ButtonGuide.Replace($TemplateCommit,'main')},
            @{name='legacy release';content=$ButtonGuide.Replace($TemplateCommit,'v0.1.0')},
            @{name='unapproved commit';content=$ButtonGuide.Replace($TemplateCommit,('0' * 40))},
            @{name='credential template';content=$ButtonGuide.Replace('%2Fdeploy%2Fazuredeploy.json','%2Fdeploy%2Fsecret-setup.azuredeploy.json')},
            @{name='credential URL parameter';content=$ButtonGuide.Replace($PortalUrl,($PortalUrl + '?geoAnalyticsApiKey=synthetic'))},
            @{name='duplicate button';content=($ButtonGuide + "`n" + $Badge.Value)},
            @{name='button before preparation';content=($Badge.Value + "`n" + $ButtonGuide.Replace($Badge.Value,''))}
        )
        foreach ($Invalid in $InvalidButtons) {
            $Failure = $null
            try { Assert-PrivateAzureButton $Invalid.content } catch { $Failure = $_.Exception.Message }
            if (-not $Failure) { throw "Button contract accepted $($Invalid.name)." }
            Write-Host "PASS: Azure button rejects $($Invalid.name)"
        }
        Write-Host "Private Azure button contracts passed: approved pin/checksum and $($InvalidButtons.Count) rejected variants."
        foreach ($Path in @('README.md','02-deploy-azure\manual.md')) {
            $Content = Get-Content -LiteralPath (Join-Path $RepositoryRoot $Path) -Raw
            if ($Content -notmatch 'Load file' -or $Content -notmatch 'deploy/azuredeploy.json' -or
                $Content -notmatch 'subscription-scoped' -or $Content -notmatch 'Disabled') {
                throw "Private Azure entry or same-template Load file fallback is missing in $Path."
            }
        }
        $RunGuide = Get-Content -LiteralPath (Join-Path $RepositoryRoot '04-run-and-verify\manual.md') -Raw
        foreach ($Output in @(
            @{name='cells_daily';rows=3},@{name='arrival';rows=1},@{name='front_daily';rows=3},
            @{name='grid_population_vulnerability';rows=17},@{name='origin';rows=1},
            @{name='vulnerability_summary';rows=0})) {
            if ($RunGuide -notmatch [regex]::Escape("[dbo].[zombie_<run_id_lowercase>_$($Output.name)]") -or
                $RunGuide -notmatch "\| ``$($Output.name)`` \| $($Output.rows) \|") {
                throw "Six-table SQL query/reference count missing for $($Output.name)."
            }
        }
        if ([regex]::Matches($RunGuide, 'COUNT_BIG\(\*\)').Count -ne 6 -or
            $RunGuide -notmatch 'no Spark job' -or $RunGuide -notmatch 'Open Results > Run all' -or
            $RunGuide -notmatch 'arbitrary parameterized' -or $RunGuide -notmatch 'NOT RUN') {
            throw 'Map, publication-only, SQL or bounded-validation guidance is incomplete.'
        }
        $CustomerPaths = @('README.md','deploy\README.md','01-start-here','02-deploy-azure','03-finish-fabric','04-run-and-verify','05-next-steps')
        foreach ($Path in $CustomerPaths) {
            foreach ($File in Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot $Path) -Filter '*.md' -File -Recurse) {
                $Content = Get-Content -LiteralPath $File.FullName -Raw
                if ($Content -match 'hidden (?:terminal )?prompt|public-network Key Vault|public access with RBAC|ipywidgets|getpass') {
                    throw "Retired secret/network experiment remains in customer guidance: $($File.Name)."
                }
                foreach ($Link in [regex]::Matches($Content, 'https://portal\.azure\.com/#create/Microsoft\.Template/uri/[^\s)<>"]+', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                    if ($File.FullName -ne (Join-Path $RepositoryRoot '02-deploy-azure\manual.md') -or
                        $Link.Value -cne $PortalUrl) {
                        throw "Unapproved or misplaced Azure deployment URI in customer guidance: $($File.Name)."
                    }
                }
            }
        }
        if (Test-Path -LiteralPath (Join-Path $RepositoryRoot 'deploy\fabric\notebook\setup-esri-api-key.ipynb')) {
            throw 'Retired setup notebook must not remain among deployable product definitions.'
        }
        $Evidence = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'engineering\validation-notes.md') -Raw
        foreach ($Finding in @('ForbiddenByConnection','Password-widget','getpass','Cloud Shell','Secure ARM','LIVE VALIDATED','REPOSITORY TESTED ONLY')) {
            if ($Evidence -notmatch [regex]::Escape($Finding)) { throw "Engineering evidence missing: $Finding" }
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
        $JourneyFolders = @('01-start-here','02-deploy-azure','03-finish-fabric','04-run-and-verify','05-next-steps')
        $RootReadme = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'README.md') -Raw
        $CopilotParts = @()
        $ManualParts = @()
        $CopilotCounts = @(8,1,3,4)
        $ManualCounts = @(12,2,6,5)
        foreach ($Index in 0..4) {
            $Folder = $JourneyFolders[$Index]
            $StageReadme = Get-Content -LiteralPath (Join-Path $RepositoryRoot "$Folder\README.md") -Raw
            foreach ($Field in @('Where','Do','See','Next')) {
                if ($StageReadme -notmatch "(?m)^### $Field\r?$") {
                    throw "$Folder needs its $Field orientation section."
                }
            }
            if (-not $RootReadme.Contains("](./$Folder/README.md)")) { throw "Root README must link to $Folder." }
            if ($Index -lt 4) {
                if (-not $StageReadme.Contains("](../$($JourneyFolders[$Index + 1])/README.md)")) {
                    throw "$Folder must link to the next numbered stage."
                }
                foreach ($Route in @('copilot','manual')) {
                    if (-not $StageReadme.Contains("](./$Route.md)")) { throw "$Folder needs its $Route route link." }
                    $Part = Get-Content -LiteralPath (Join-Path $RepositoryRoot "$Folder\$Route.md") -Raw
                    $Pattern = if ($Route -eq 'copilot') { '(?m)^## FP\d\d ' } else { '(?m)^### Step \d\d ' }
                    $Expected = if ($Route -eq 'copilot') { $CopilotCounts[$Index] } else { $ManualCounts[$Index] }
                    if ([regex]::Matches($Part, $Pattern).Count -ne $Expected) {
                        throw "$Folder has the wrong number of $Route steps."
                    }
                    if (-not $Skill.Contains("../../../$Folder/$Route.md")) {
                        throw "Copilot skill must reference $Folder/$Route.md."
                    }
                    if ($Index -lt 3) {
                        $NextRoute = [regex]::Escape("../$($JourneyFolders[$Index + 1])/$Route.md#")
                        if ($Part -notmatch "(?m)^(?:\| Next +\| |Next: ).*\]\($NextRoute") {
                            throw "$Folder/$Route.md needs a Next link continuing the same route in the next folder."
                        }
                    }
                    if ($Route -eq 'copilot') { $CopilotParts += $Part } else { $ManualParts += $Part }
                }
            }
        }
        if (-not $RootReadme.Contains('[Open 01 Start here](./01-start-here/README.md)') -or
            $RootReadme -match '(?m)^## (Preferred quick start|CLI reminder)\r?$') {
            throw 'Root README must have one numbered starting point, not competing quick starts.'
        }
        $FastPass = $CopilotParts -join "`n"
        $Steps = @([regex]::Matches($FastPass, '(?ms)^## FP(?<number>\d\d) [^\r\n]+\r?\n(?<body>.*?)(?=^## |\z)'))
        if ($Steps.Count -ne 16 -or
            (@($Steps | ForEach-Object { [int]$_.Groups['number'].Value }) -join ',') -ne ((1..16) -join ',')) {
            throw 'Fast Pass guide must contain FP01-FP16 in order.'
        }
        foreach ($Step in $Steps) {
            foreach ($Field in @('Where','Do','See','Next')) {
                if ($Step.Groups['body'].Value -notmatch "(?m)^\| +$Field +\| +\S[^\r\n]+\| *\r?$") {
                    throw "FP$($Step.Groups['number'].Value) is missing its $Field checkpoint."
                }
            }
            if ($Step.Groups['body'].Value -notmatch '(?m)^\| Next +\| .*?\[[^\]]+\]\([^)]+\)') {
                throw "FP$($Step.Groups['number'].Value) needs a linked next action."
            }
        }
        $Manual = $ManualParts -join "`n"
        $ManualSteps = @([regex]::Matches($Manual, '(?ms)^### Step (?<number>\d\d) [^\r\n]+\r?\n(?<body>.*?)(?=^### Step |^## |\z)'))
        if ($ManualSteps.Count -ne 25 -or
            (@($ManualSteps | ForEach-Object { [int]$_.Groups['number'].Value }) -join ',') -ne ((1..25) -join ',')) {
            throw 'Manual guide must contain Steps 01-25 in order.'
        }
        foreach ($Step in $ManualSteps) {
            $Body = $Step.Groups['body'].Value
            if ($Body -notmatch '(?m)^Where to be: \S[^\r\n]+' -or
                $Body -notmatch '(?im)\bexpect(?:ed)?\b' -or
                $Body -notmatch '(?m)^Next: .*?\[[^\]]+\]\((?:#[^)]+|\.\.?/[^)]+)\)') {
                throw "Manual Step $($Step.Groups['number'].Value) needs location, expected result and linked next action."
            }
        }
        foreach ($Route in @(@{Path='docs\copilot-fast-pass.md'; Steps=$Steps}, @{Path='docs\getting-started.md'; Steps=$ManualSteps})) {
            $Legacy = Get-Content -LiteralPath (Join-Path $RepositoryRoot $Route.Path) -Raw
            foreach ($Step in $Route.Steps) {
                $Heading = ($Step.Value -split '\r?\n',2)[0]
                if (-not $Legacy.Contains($Heading)) { throw "Legacy guide lost its heading: $Heading" }
            }
        }
        $DiagramPath = Join-Path $RepositoryRoot 'docs\images\accelerator-journey.drawio'
        $SvgPath = Join-Path $RepositoryRoot 'docs\images\accelerator-journey.svg'
        $Diagram = [xml](Get-Content -LiteralPath $DiagramPath -Raw)
        $Svg = [xml](Get-Content -LiteralPath $SvgPath -Raw)
        $Cells = @($Diagram.mxfile.diagram.mxGraphModel.root.mxCell)
        $Stages = @($Cells | Where-Object { $_.id -match '^stage-[1-5]$' -and $_.vertex -eq '1' })
        $Edges = @($Cells | Where-Object { $_.edge -eq '1' })
        if ($Stages.Count -ne 5 -or $Edges.Count -ne 4) { throw 'Overview must remain five stages with four connectors.' }
        $SvgText = (@($Svg.SelectNodes("//*[local-name()='text']") | ForEach-Object { $_.InnerText }) -join ' ') -replace '\s+',' '
        foreach ($Stage in $Stages) {
            $Index = [int]($Stage.id -replace '^stage-','') - 1
            if (-not $Stage.value.Contains($JourneyFolders[$Index])) {
                throw "Diagram stage $($Stage.id) must name its numbered folder."
            }
            foreach ($Line in ($Stage.value -split '\r?\n')) {
                if (-not $SvgText.Contains(($Line -replace '\s+',' '))) {
                    throw "SVG label differs from draw.io stage $($Stage.id): $Line"
                }
            }
        }
        foreach ($Index in 1..4) {
            if (@($Edges | Where-Object { $_.source -eq "stage-$Index" -and $_.target -eq "stage-$($Index + 1)" }).Count -ne 1) {
                throw "Draw.io overview must connect stage $Index to stage $($Index + 1)."
            }
        }
        $ViewBox = @($Svg.DocumentElement.GetAttribute('viewBox') -split '\s+' | ForEach-Object {
            [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
        })
        if ($ViewBox.Count -ne 4 -or $ViewBox[2] -le 0 -or $ViewBox[3] -le 0 -or
            $ViewBox[3] -gt 420 -or $ViewBox[2] / $ViewBox[3] -lt 2.5) {
            throw 'SVG overview must stay compact: positive viewBox, height <= 420 and width/height >= 2.5.'
        }
        foreach ($Index in 0..1) {
            $Dimension = @('width','height')[$Index]
            $Value = $Svg.DocumentElement.GetAttribute($Dimension)
            if ($Value -notmatch '^\d+(?:\.\d+)?(?:px)?$' -or
                [double]::Parse(($Value -replace 'px$',''), [Globalization.CultureInfo]::InvariantCulture) -ne $ViewBox[2 + $Index]) {
                throw "SVG $Dimension must match its viewBox to avoid a browser-default thumbnail."
            }
        }
        if ($Svg.SelectNodes("//*[local-name()='script' or local-name()='foreignObject']").Count -gt 0) {
            throw 'Overview SVG must use portable, script-free SVG text, not HTML labels.'
        }
        foreach ($Path in @('README.md','01-start-here\copilot.md')) {
            $Content = Get-Content -LiteralPath (Join-Path $RepositoryRoot $Path) -Raw
            if ($Content -notmatch '!\[[^\]]+\]\([^)]*accelerator-journey\.svg\)' -or $Content -match '```mermaid') {
                throw "$Path must display the shared SVG overview rather than a tall Mermaid flowchart."
            }
        }
        Write-Host 'PASS: Fast Pass skill discovery metadata, user invocation and 16 ordered guide steps.'
        Write-Host 'PASS: 16 Fast Pass checkpoint cards and 25 ordered, located manual steps with linked next actions.'
        Write-Host 'PASS: Five root stage folders, route boundaries, Copilot references and legacy step headings.'
        Write-Host 'PASS: Compact five-stage SVG, matching draw.io labels, numbered folder names and ordered connectors.'
        Write-Host 'PASS: Private template entry, handoff, opt-in capacity, secret boundaries, map/SQL guidance, engineering evidence and documentation links.'
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
