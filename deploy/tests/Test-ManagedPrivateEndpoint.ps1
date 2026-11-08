#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Validates managed private endpoint lifecycle contracts offline.
.DESCRIPTION
    Uses real lifecycle and schema persistence with mocked service responses.
.PARAMETER RepositoryRoot
    Root of the deployment experience.
.EXAMPLE
    .\deploy\tests\Test-ManagedPrivateEndpoint.ps1
.NOTES
    Never accesses Azure, Fabric, credentials, or secret values.
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
            function Reset-Fixture {
                $script:Manifest = @{
                    deploymentName='geo-test';deploymentVersion='0.1.0'
                    subscriptionId='11111111-1111-1111-1111-111111111111'
                    tenantId='22222222-2222-2222-2222-222222222222'
                    userObjectId='33333333-3333-3333-3333-333333333333'
                    workspaceId='44444444-4444-4444-4444-444444444444'
                    capacityId='55555555-5555-5555-5555-555555555555';capacityMode='existing'
                    resourceGroupName='rg-geo-test';location='centralus';keyVaultName='kv-geo-test'
                    keyVaultUri='https://kv-geo-test.vault.azure.net/';keyVaultSecretName='geoanalytics-api-key'
                    createdAt=[datetime]::UtcNow.ToString('o');updatedAt=[datetime]::UtcNow.ToString('o')
                    stage='AzureDeployed';resources=@{
                        keyVault=@{id='/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-geo-test/providers/Microsoft.KeyVault/vaults/kv-geo-test';created=$true}
                    }
                }
                $script:RawEndpoint = @{
                    id='66666666-6666-6666-6666-666666666666';name='mpe-kv-geo-test'
                    targetPrivateLinkResourceId=$script:Manifest.resources.keyVault.id
                    targetSubresourceType='vault';provisioningState='Succeeded';connectionState=@{status='Pending'}
                }
                $script:Endpoints = @()
                $script:Calls = [System.Collections.Generic.List[object]]::new()
                $script:CreateCount = 0
                $script:PublicNetworkAccess = 'Disabled'
                $script:CreateStatusCode = 201
                $script:CreateOmitsApproval = $false
                $script:ApprovalAfterRead = $null
                $script:IsAdmin = $true
                $script:Paginate = $false
                $script:Base = "https://api.fabric.microsoft.com/v1/workspaces/$($script:Manifest.workspaceId)"
            }
            function script:Invoke-AzJson {
                param([string[]]$Arguments)
                if (($Arguments -join ' ') -eq 'account show') {
                    return @{id=$script:Manifest.subscriptionId;tenantId=$script:Manifest.tenantId;user=@{type='user'}}
                }
                if (($Arguments -join ' ') -eq 'ad signed-in-user show') { return @{id=$script:Manifest.userObjectId} }
                throw 'Unexpected Azure operation in offline network tests.'
            }
            function script:Invoke-ServiceRequest {
                param([string]$Uri, [string]$Method='GET', [object]$Body, [string]$Audience='https://api.fabric.microsoft.com')
                $script:Calls.Add(@{uri=$Uri;method=$Method;body=$Body;audience=$Audience})
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/capacities' -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{value=@(@{id=$script:Manifest.capacityId;displayName='Offline capacity';sku='F2';state='Active'})}}
                }
                if ($Uri -eq "https://management.azure.com$($script:Manifest.resources.keyVault.id)?api-version=2025-05-01" -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{id=$script:Manifest.resources.keyVault.id;properties=@{publicNetworkAccess=$script:PublicNetworkAccess}}}
                }
                if ($Uri -eq $script:Base -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{id=$script:Manifest.workspaceId;capacityId=$script:Manifest.capacityId;description='fabric-zombie-outbreak:geo-test'}}
                }
                if ($Uri -eq "$script:Base/roleAssignments" -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{value=@(@{principal=@{id=$script:Manifest.userObjectId};role=$(if ($script:IsAdmin) {'Admin'} else {'Viewer'})})}}
                }
                if ($Uri -eq "$script:Base/managedPrivateEndpoints" -and $Method -eq 'GET') {
                    if ($script:Paginate) {
                        return @{StatusCode=200;Data=@{value=@();continuationUri="$script:Base/managedPrivateEndpoints?continuationToken=offline"}}
                    }
                    return @{StatusCode=200;Data=@{value=$script:Endpoints}}
                }
                if ($Uri -eq "$script:Base/managedPrivateEndpoints?continuationToken=offline" -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{value=$script:Endpoints}}
                }
                if ($Uri -eq "$script:Base/managedPrivateEndpoints" -and $Method -eq 'POST') {
                    $script:CreateCount++
                    $script:Endpoints = @($script:RawEndpoint)
                    $Data = $script:RawEndpoint | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
                    if ($script:CreateOmitsApproval) { $null = $Data.Remove('connectionState') }
                    return @{StatusCode=$script:CreateStatusCode;Data=$Data}
                }
                if ($Uri -eq "$script:Base/managedPrivateEndpoints/$($script:RawEndpoint.id)" -and $Method -eq 'GET') {
                    if ($script:ApprovalAfterRead) {
                        $script:RawEndpoint.provisioningState='Succeeded'
                        $script:RawEndpoint.connectionState.status=$script:ApprovalAfterRead
                    }
                    return @{StatusCode=200;Data=$script:RawEndpoint}
                }
                foreach ($Type in @('Lakehouse','Environment','Notebook')) {
                    $Id = $script:Manifest["$($Type.ToLowerInvariant())Id"]
                    if ($Id -and $Uri -eq "$script:Base/items/$Id" -and $Method -eq 'GET') {
                        return @{StatusCode=200;Data=@{id=$Id;type=$Type;displayName=$Type;description='fabric-zombie-outbreak:geo-test'}}
                    }
                }
                if ($script:Manifest.environmentId -and $Uri -eq "$script:Base/environments/$($script:Manifest.environmentId)/sparkcompute?beta=false" -and $Method -eq 'GET') {
                    return @{StatusCode=200;Data=@{runtimeVersion='1.3';sparkProperties=@(@{key='spark.native.enabled';value='false'})}}
                }
                if ($script:Manifest.notebookId -and $Uri -eq "$script:Base/notebooks/$($script:Manifest.notebookId)/getDefinition?format=ipynb" -and $Method -eq 'POST') {
                    $Notebook = @{
                        cells=@(@{metadata=@{tags=@('parameters')}})
                        metadata=@{dependencies=@{
                            lakehouse=@{default_lakehouse=$script:Manifest.lakehouseId;default_lakehouse_workspace_id=$script:Manifest.workspaceId}
                            environment=@{environmentId=$script:Manifest.environmentId}
                        }}
                    } | ConvertTo-Json -Depth 10
                    return @{StatusCode=200;Data=@{definition=@{parts=@(@{
                        path='notebook.ipynb';payloadType='InlineBase64'
                        payload=[Convert]::ToBase64String([text.encoding]::UTF8.GetBytes($Notebook))
                    })}}}
                }
                throw "Unexpected service operation: $Method $Uri"
            }
            function script:Start-Sleep { param([int]$Seconds) }
            $script:StateDirectory = Join-Path ([IO.Path]::GetTempPath()) "geo-mpe-$([guid]::NewGuid().ToString('N'))"
            $StatePath = Join-Path $script:StateDirectory 'geo-test.json'
            try {
                Reset-Fixture
                Assert-Fails 'Succeeded activation with Pending approval stops at the Azure checkpoint' {
                    Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                } 'Azure approval Pending.*Networking.*configure-network'
                $Post = @($script:Calls | Where-Object method -eq 'POST')[0]
                Assert-Check 'Create uses the supported endpoint route and exactly four nonsecret fields' (
                    $Post.uri -eq "$script:Base/managedPrivateEndpoints" -and $Post.body.Count -eq 4 -and
                    $Post.body.name -eq 'mpe-kv-geo-test' -and
                    $Post.body.targetPrivateLinkResourceId -eq $script:Manifest.resources.keyVault.id -and
                    $Post.body.targetSubresourceType -eq 'vault' -and
                    $Post.body.requestMessage -eq 'Fabric GeoAnalytics Fast Pass access to Key Vault')
                Assert-Check 'Discovery precedes creation and private-only vault is checked' (
                    $script:Calls[0].method -eq 'GET' -and $script:Calls[0].uri -eq "$script:Base/managedPrivateEndpoints" -and
                    $script:Calls[1].audience -eq 'https://management.azure.com/')
                $Saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json -AsHashtable
                Assert-Check 'Pending checkpoint persists independent activation and approval states' (
                    $Saved.managedPrivateEndpoint.provisioningState -eq 'Succeeded' -and
                    $Saved.managedPrivateEndpoint.approvalState -eq 'Pending' -and
                    $Saved.resources.ManagedPrivateEndpoint.created -eq $true)
                $Status = Get-DeploymentStatus -Config $script:Manifest
                Assert-Check 'Read-only status reports pending network and incomplete assets without claiming readiness' (
                    $Status.managedPrivateEndpointReady -eq $false -and $Status.fabricItemsVerified -eq $false -and
                    $Status.managedPrivateEndpoint.approvalState -eq 'Pending' -and $script:CreateCount -eq 1)
                $script:RawEndpoint.connectionState.status='Approved'
                $Result = Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                $null = Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                Assert-Check 'Approval resume and repeated rerun reuse the same endpoint without duplicates' (
                    $script:CreateCount -eq 1 -and $Result.approvalState -eq 'Approved' -and
                    $script:Manifest.resources.ManagedPrivateEndpoint.created -eq $true)
                $Schema = Join-Path $script:Root 'deploy\fabric\deployment-manifest.schema.json'
                $Json = Get-Content -LiteralPath $StatePath -Raw
                Assert-Check 'Real persisted endpoint state passes the nonsecret schema' (Test-Json -Json $Json -SchemaFile $Schema)
                $Saved = $Json | ConvertFrom-Json -AsHashtable
                $Saved.managedPrivateEndpoint.apiKey='not-a-real-key'
                Assert-Check 'Endpoint state rejects secret and unknown fields' (
                    -not (Test-Json -Json ($Saved | ConvertTo-Json -Depth 20) -SchemaFile $Schema -ErrorAction SilentlyContinue))
                $script:Manifest.stage='Configured'
                $script:Manifest.lakehouseId='77777777-7777-7777-7777-777777777777'
                $script:Manifest.environmentId='88888888-8888-8888-8888-888888888888'
                $script:Manifest.notebookId='99999999-9999-9999-9999-999999999999'
                Save-DeploymentManifest $script:Manifest
                $Status = Get-DeploymentStatus -Config $script:Manifest
                Assert-Check 'Approved status preserves existing runtime and notebook binding verification' (
                    $Status.managedPrivateEndpointReady -eq $true -and $Status.notebookBindingsVerified -eq $true -and
                    $Status.runtimeVersion -eq '1.3' -and $Status.stage -eq 'Configured')
                $script:RawEndpoint.connectionState.status='Pending'
                $Status = Get-DeploymentStatus -Config $script:Manifest
                Assert-Check 'Configured assets do not imply readiness when approval becomes Pending' (
                    $Status.managedPrivateEndpointReady -eq $false -and $Status.notebookBindingsVerified -eq $true)

                Reset-Fixture
                $script:Endpoints=@($script:RawEndpoint)
                $script:RawEndpoint.connectionState.status='Approved'
                $null = Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                Assert-Check 'Existing matching manually created endpoint is reused and marked not created' (
                    $script:CreateCount -eq 0 -and $script:Manifest.resources.ManagedPrivateEndpoint.created -eq $false)
                $script:Paginate=$true
                $null = Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                Assert-Check 'Endpoint discovery follows pagination before deciding whether to create' (
                    $script:CreateCount -eq 0 -and @($script:Calls | Where-Object uri -like '*continuationToken=offline').Count -eq 1)
                $script:Paginate=$false
                $script:Endpoints=@($script:RawEndpoint,$script:RawEndpoint)
                Assert-Fails 'Duplicate expected names fail safely' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'Multiple managed'

                Reset-Fixture
                $script:Endpoints=@($script:RawEndpoint)
                $script:RawEndpoint.targetPrivateLinkResourceId='/subscriptions/other/resourceGroups/other/providers/Microsoft.KeyVault/vaults/other'
                Assert-Fails 'Expected name with wrong target fails without adoption' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'ownership/configuration'
                Assert-Check 'Target collision submits no mutation' ($script:CreateCount -eq 0)
                $script:RawEndpoint.targetPrivateLinkResourceId=$script:Manifest.resources.keyVault.id
                $script:RawEndpoint.targetSubresourceType='blob'
                Assert-Fails 'Expected name with wrong subresource fails without replacement' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'ownership/configuration'
                $script:RawEndpoint.targetSubresourceType='vault'
                $script:Manifest.managedPrivateEndpoint=@{id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'}
                Assert-Fails 'Recorded endpoint ID conflict is not silently adopted' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'ID differs'
                $script:Manifest.Remove('managedPrivateEndpoint')
                $script:RawEndpoint.provisioningState='Unexpected'
                Assert-Fails 'Unknown API state fails explicitly rather than reporting readiness' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'Unknown managed'

                Reset-Fixture
                $script:Manifest.resources.keyVault.id='/subscriptions/wrong/resourceGroups/rg-geo-test/providers/Microsoft.KeyVault/vaults/kv-geo-test'
                Assert-Fails 'Unverified target resource ID in state blocks even discovery' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'matching Key Vault ARM ID'
                Assert-Check 'Invalid state performs no service calls' ($script:Calls.Count -eq 0)
                $Sample = Get-Content -LiteralPath (Join-Path $script:Root 'deploy\config\customer.sample.json') -Raw | ConvertFrom-Json -AsHashtable
                $Sample.subscriptionId='11111111-1111-1111-1111-111111111111'
                $Sample.tenantId='22222222-2222-2222-2222-222222222222'
                $Sample.capacity.id='55555555-5555-5555-5555-555555555555'
                $Sample.apiKey='not-a-real-key'
                $Sample | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding utf8
                Assert-Fails 'Customer configuration continues to reject API-key fields' { Read-CustomerConfig -Path $StatePath } 'Unknown.*apiKey'

                Reset-Fixture
                $script:PublicNetworkAccess='Enabled'
                Assert-Fails 'Public Key Vault access blocks creation and is not changed' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'must remain Disabled'
                Assert-Check 'Network policy failure does not submit POST, PATCH or PUT' (
                    @($script:Calls | Where-Object method -ne 'GET').Count -eq 0)

                Reset-Fixture
                $script:RawEndpoint.provisioningState='Provisioning'
                $script:CreateOmitsApproval=$true
                $script:ApprovalAfterRead='Approved'
                $null = Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest
                Assert-Check 'Creation without approval metadata polls the recorded endpoint to actual approval' (
                    $script:Manifest.managedPrivateEndpoint.provisioningState -eq 'Succeeded' -and
                    $script:Manifest.managedPrivateEndpoint.approvalState -eq 'Approved' -and $script:CreateCount -eq 1)

                Reset-Fixture
                $script:RawEndpoint.provisioningState='Provisioning'
                $script:CreateOmitsApproval=$true
                Assert-Fails 'Activation timeout retains ID and does not resubmit' {
                    Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest -TimeoutSeconds 0
                } 'timed out'
                Assert-Check 'Timeout persists unknown approval as null rather than inventing approval' (
                    $null -eq $script:Manifest.managedPrivateEndpoint.approvalState -and $script:CreateCount -eq 1)
                $script:Endpoints=@()
                Assert-Fails 'Recorded endpoint absent from discovery is not recreated' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'missing from discovery'
                Assert-Check 'Missing recorded endpoint submits no duplicate' ($script:CreateCount -eq 1)

                Reset-Fixture
                $script:RawEndpoint.connectionState.status='Rejected'
                Assert-Fails 'Rejected connection fails explicitly and persists failure metadata' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'approval failed'
                Assert-Check 'Rejected approval remains recorded' ($script:Manifest.managedPrivateEndpoint.approvalState -eq 'Rejected')
                Reset-Fixture
                $script:CreateStatusCode=202
                Assert-Fails 'Unexpected create response is not treated as the supported 201 contract' { Initialize-KeyVaultManagedPrivateEndpoint $script:Manifest } 'HTTP 201'
                Assert-Check 'Unexpected submission result is never automatically resubmitted' ($script:CreateCount -eq 1)

                Reset-Fixture
                $script:Endpoints=@($script:RawEndpoint)
                $script:RawEndpoint.connectionState.status='Approved'
                Save-DeploymentManifest $script:Manifest
                Set-DeploymentNetwork -Config $script:Manifest
                Assert-Check 'Network-only resume never republishes, imports, runs, grants roles or approves Azure' (
                    @($script:Calls | Where-Object method -ne 'GET').Count -eq 0 -and
                    $script:Manifest.stage -eq 'AzureDeployed')
                $script:IsAdmin=$false
                Assert-Fails 'Network-only resume refuses missing Admin role' { Set-DeploymentNetwork -Config $script:Manifest } 'must be workspace Admin'
                Assert-Check 'All tested mutations are only Fabric managed endpoint POSTs' (
                    @($script:Calls | Where-Object { $_.method -ne 'GET' -and $_.uri -ne "$script:Base/managedPrivateEndpoints" }).Count -eq 0)
                Write-Host "Managed private endpoint checks passed: $script:CheckCount"
            }
            finally {
                if (Test-Path -LiteralPath $StatePath) { Remove-Item -LiteralPath $StatePath }
                if (Test-Path -LiteralPath "$StatePath.tmp") { Remove-Item -LiteralPath "$StatePath.tmp" }
                if (Test-Path -LiteralPath $script:StateDirectory) { Remove-Item -LiteralPath $script:StateDirectory }
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
