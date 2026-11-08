#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Runs dependency-free offline accelerator regression checks.
.DESCRIPTION
    Mocks Azure and Fabric calls. Never provisions resources or accesses a secret.
.PARAMETER RepositoryRoot
    Root of this checkout.
.EXAMPLE
    .\deploy\tests\Test-Accelerator.ps1
.NOTES
    Python syntax validation uses only the local standard library, not Fabric packages.
#>
[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Module = Import-Module (Join-Path $RepositoryRoot 'deploy\scripts\Accelerator.psm1') -Force -PassThru
        & $Module {
            $script:HttpCount = 0
            function Assert-Check([string]$Name, [bool]$Condition) {
                if (-not $Condition) { throw "FAIL: $Name" }
                $script:HttpCount++
                Write-Host "PASS: $Name"
            }
            function Assert-Fails([string]$Name, [scriptblock]$Action, [string]$Pattern) {
                $Failure = $null
                try { & $Action | Out-Null } catch { $Failure = $_.Exception.Message }
                Assert-Check $Name ([bool]($Failure -and $Failure -match $Pattern))
            }
            $script:HttpCalls = [System.Collections.Generic.List[string]]::new()
            $script:CredentialCalls = 0
            $script:WorkspaceReads = 0
            $script:HttpScenario = 'success'
            function script:Invoke-AzJson {
                param([string[]]$Arguments)
                if (($Arguments -join ' ') -ne 'account get-access-token --resource https://api.fabric.microsoft.com') {
                    throw 'Unexpected CLI call in offline HTTP checks.'
                }
                $script:CredentialCalls++
                return @{accessToken='offline-test-token'}
            }
            function script:Invoke-WebRequest {
                param([string]$Uri, [string]$Method, [hashtable]$Headers, [switch]$SkipHttpErrorCheck, [int]$TimeoutSec)
                $script:HttpCalls.Add("$Method $Uri")
                if ($Method -ne 'GET') { throw 'Offline HTTP checks only expect GET requests.' }
                if ($Uri -eq 'https://api.fabric.microsoft.com/v1/workspaces/offline') {
                    $script:WorkspaceReads++
                    $CapacityId = switch ($script:HttpScenario) {
                        'capacity-pending' { if ($script:WorkspaceReads -ge 2) { 'capacity' } }
                        'capacity-wrong' { 'other-capacity' }
                        default { $null }
                    }
                    $Data = @{id='offline';capacityId=$CapacityId}
                    if ($script:HttpScenario -eq 'capacity-invalid') { $Data.id = 'different-workspace' }
                } elseif ($Uri -in @('https://api.fabric.microsoft.com/v1/operations/offline/result','https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666/result')) {
                    $Data = @{id='created-item'}
                } elseif ($Uri -in @('https://api.fabric.microsoft.com/v1/operations/offline','https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666')) {
                    $State = switch ($script:HttpScenario) {
                        'failed' { 'Failed' }
                        'cancelled' { 'Cancelled' }
                        'unknown' { 'Unexpected' }
                        default { 'Succeeded' }
                    }
                    $Data = @{status=$State}
                } else {
                    throw 'Unexpected URL in offline HTTP checks.'
                }
                return @{StatusCode=200;Headers=@{};Content=($Data | ConvertTo-Json -Compress)}
            }
            function script:Start-Sleep { param([int]$Seconds) }
            foreach ($Location in @('https://api.fabric.microsoft.com/v1/operations/offline','/v1/operations/offline')) {
                $Result = Wait-FabricOperation @{StatusCode=202;Headers=@{Location=$Location;'Retry-After'='0'}}
                Assert-Check "Operation completes with Location $Location" ($Result.id -eq 'created-item')
            }
            Assert-Check 'Operation polling and result reads use the trusted Fabric origin' (
                @($script:HttpCalls | Where-Object { $_ -notmatch '^GET https://api\.fabric\.microsoft\.com/v1/operations/offline(/result)?$' }).Count -eq 0)
            $CanonicalUri = 'https://api.fabric.microsoft.com/v1/operations/66666666-6666-4666-8666-666666666666'
            $script:HttpCalls.Clear()
            $Result = Wait-FabricOperation @{StatusCode=202;Headers=@{
                Location='https://wabi-us-central-b-primary-redirect.analysis.windows.net/offline-operation'
                'x-ms-operation-id'='66666666-6666-4666-8666-666666666666';'Retry-After'='0'
            }}
            Assert-Check 'Regional Location is ignored in favor of a validated operation ID on the trusted origin' (
                $Result.id -eq 'created-item' -and $script:HttpCalls.Count -eq 2 -and
                $script:HttpCalls[0] -eq "GET $CanonicalUri" -and $script:HttpCalls[1] -eq "GET $CanonicalUri/result")
            $Result = Wait-FabricOperation @{StatusCode=202;Headers=@{'x-ms-operation-id'='66666666-6666-4666-8666-666666666666';'Retry-After'='0'}}
            Assert-Check 'Operation ID works without a Location header' ($Result.id -eq 'created-item')
            $script:HttpCalls.Clear()
            $Result = Wait-FabricOperation -NoResult -Response @{StatusCode=202;Headers=@{
                'x-ms-operation-id'='66666666-6666-4666-8666-666666666666';'Retry-After'='0'
            }}
            Assert-Check 'Resultless operations verify success without requesting a result endpoint' (
                $null -eq $Result -and $script:HttpCalls.Count -eq 1 -and $script:HttpCalls[0] -eq "GET $CanonicalUri")
            foreach ($OperationId in @('invalid-operation-id','00000000-0000-0000-0000-000000000000')) {
                Assert-Fails 'Invalid operation IDs are rejected without falling back to Location' {
                    Wait-FabricOperation @{StatusCode=202;Headers=@{'x-ms-operation-id'=$OperationId;Location='/v1/operations/offline'}}
                } 'invalid x-ms-operation-id'
            }
            Assert-Check 'Non-asynchronous result is returned unchanged' (
                (Wait-FabricOperation @{StatusCode=201;Data=@{id='synchronous'}}).id -eq 'synchronous')
            Assert-Fails 'Missing operation Location fails without resubmitting' {
                Wait-FabricOperation @{StatusCode=202;Headers=@{}}
            } 'did not return Location'
            foreach ($State in @('failed','cancelled','unknown')) {
                $script:HttpScenario = $State
                Assert-Fails "Operation $State fails explicitly" {
                    Wait-FabricOperation @{StatusCode=202;Headers=@{Location='/v1/operations/offline';'Retry-After'='0'}}
                } 'Failed|Cancelled|Unexpected'
            }
            Assert-Fails 'Operation timeout warns that the operation may still be running' {
                Wait-FabricOperation -Response @{StatusCode=202;Headers=@{Location='/v1/operations/offline'}} -TimeoutSeconds 0
            } 'may still be running'
            $BeforeCredentials = $script:CredentialCalls
            $BeforeRequests = $script:HttpCalls.Count
            foreach ($Location in @(
                'https://unexpected.example/v1/operations/offline',
                '//unexpected.example/v1/operations/offline',
                'http://api.fabric.microsoft.com/v1/operations/offline',
                'https://user:private-marker@api.fabric.microsoft.com/v1/operations/offline',
                'https://api.fabric.microsoft.com:8443/v1/operations/offline',
                'https://api.fabric.microsoft.com/v1/operations/offline#fragment'
            )) {
                Assert-Fails 'Unsafe operation Location is rejected before credential acquisition' {
                    Wait-FabricOperation @{StatusCode=202;Headers=@{Location=$Location}}
                } 'Refusing'
            }
            Assert-Fails 'Service URL guard still rejects an unexpected host' {
                Invoke-ServiceRequest -Uri 'https://unexpected.example/private-path?private-query'
            } 'method=GET, scheme=https, host=unexpected.example'
            $Diagnostic = $null
            try {
                Resolve-FabricOperationUri 'https://user:private-marker@unexpected.example/private-path?private-query'
            } catch { $Diagnostic = $_.Exception.Message }
            Assert-Check 'URL rejection diagnostics omit credentials, path, and query' (
                $Diagnostic -match 'host=unexpected.example' -and $Diagnostic -notmatch 'private-marker|private-path|private-query')
            Assert-Check 'Unsafe URLs acquired no credentials and issued no HTTP requests' (
                $script:CredentialCalls -eq $BeforeCredentials -and $script:HttpCalls.Count -eq $BeforeRequests)
            $script:HttpScenario = 'capacity-pending'
            $script:WorkspaceReads = 0
            $Workspace = Wait-WorkspaceCapacity -WorkspaceId 'offline' -CapacityId 'capacity'
            Assert-Check 'Capacity assignment polls workspace metadata until the requested capacity is visible' (
                $Workspace.capacityId -eq 'capacity' -and $script:WorkspaceReads -eq 2)
            $script:HttpScenario = 'capacity-wrong'
            Assert-Fails 'Capacity polling refuses another capacity' {
                Wait-WorkspaceCapacity -WorkspaceId 'offline' -CapacityId 'capacity'
            } 'different capacity'
            $script:HttpScenario = 'capacity-invalid'
            Assert-Fails 'Capacity polling rejects unrelated workspace metadata' {
                Wait-WorkspaceCapacity -WorkspaceId 'offline' -CapacityId 'capacity'
            } 'unexpected workspace metadata'
            $script:HttpScenario = 'capacity-timeout'
            Assert-Fails 'Capacity assignment timeout does not report success or resubmit' {
                Wait-WorkspaceCapacity -WorkspaceId 'offline' -CapacityId 'capacity' -TimeoutSeconds 0
            } 'timed out.*may still be running'
            Write-Host "HTTP compatibility checks passed: $script:HttpCount"
        }
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
                Assert-Check $Name ($Failure -and $Failure -match $Pattern)
            }
            $Notebook = New-DeployableNotebook -WorkspaceId '11111111-1111-1111-1111-111111111111' `
                -LakehouseId '22222222-2222-2222-2222-222222222222' -EnvironmentId '33333333-3333-3333-3333-333333333333' `
                -LakehouseName 'ZombieOutbreak' -KeyVaultUri 'https://kv-example.vault.azure.net/'
            $Json = $Notebook | ConvertTo-Json -Depth 100
            Assert-Check 'Exactly one Fabric parameter cell' (@($Notebook.cells | Where-Object { 'parameters' -in $_.metadata.tags }).Count -eq 1)
            Assert-Check 'No cached outputs' (@($Notebook.cells | Where-Object { $_.cell_type -eq 'code' -and $_.outputs.Count }).Count -eq 0)
            Assert-Check 'Author workspace and Lakehouse bindings removed' ($Json -notmatch '6a30c14f|1692bff1')
            Assert-Check 'Publishing removed entirely' ($Json -notmatch 'AGOL_|PUBLISH_TO_|register_gis')
            Assert-Check 'No infrastructure or secret parameters' ($Notebook.cells[1].source -notmatch 'keyVault|workspace|lakehouse|environment|api_key')
            Assert-Check 'Runtime secret retrieval present' ($Json -match 'credentials.getSecret')
            Assert-Check 'Delta and WKT writes present' ($Json -match 'saveAsTable' -and $Json -match 'ST.as_text')
            Assert-Check 'Original simulation code preserved' ($Notebook.cells[7].source -eq ((Get-Content (Join-Path $script:Root 'Zombie_Outbreak_Spread.ipynb') -Raw | ConvertFrom-Json).cells[13].source -join ''))
            $Python = Get-Command python -ErrorAction Stop
            $SyntaxCheck = @'
import ast, json, sys
notebook = json.load(sys.stdin)
for index, cell in enumerate(notebook["cells"]):
    if cell["cell_type"] == "code":
        ast.parse(cell["source"], filename=f"cell_{index}")
assert notebook["cells"][1]["metadata"]["tags"] == ["parameters"]
print("All generated Python cells parse.")

class Frame:
    def __init__(self, rows=1):
        self.rows = rows
        self.write = self
    def withColumn(self, *args):
        return self
    def drop(self, *args):
        return self
    def format(self, value):
        assert value == "delta"
        return self
    def mode(self, value):
        assert value in ("errorifexists", "overwrite")
        return self
    def saveAsTable(self, name):
        written[name] = self
    def count(self):
        return self.rows

from types import SimpleNamespace
written = {}
receipts = []
exits = []
env = {
    name: Frame() for name in
    ("cells_daily", "arrival", "front", "cell_attrs", "origin_df", "by_quintile")
}
env.update({
    "F": SimpleNamespace(lit=lambda value: value),
    "ST": SimpleNamespace(as_text=lambda column: column),
    "RUN_ID": "offline_run", "TABLE_PREFIX": "zombie", "OVERWRITE": False,
    "OUT": "Files/zombie_outbreak/run_id=offline_run", "json": json,
    "spark": SimpleNamespace(
        catalog=SimpleNamespace(tableExists=lambda name: name in written),
        table=lambda name: written[name],
    ),
    "notebookutils": SimpleNamespace(
        fs=SimpleNamespace(put=lambda *args: receipts.append(args)),
        notebook=SimpleNamespace(exit=lambda value: exits.append(json.loads(value))),
    ),
})
exec(notebook["cells"][-1]["source"], env)
assert len(written) == 6 and len(receipts) == 1
assert exits[0]["run_id"] == "offline_run"
assert all(output["rows"] == 1 for output in exits[0]["outputs"].values())
try:
    exec(notebook["cells"][-1]["source"], env)
except RuntimeError as error:
    assert "already exist" in str(error)
else:
    raise AssertionError("Existing tables must not be overwritten by default")
print("Delta output contract, read-back counts, and overwrite guard passed (mock Spark).")
'@
            $Json | & $Python.Source -c $SyntaxCheck
            Assert-Check 'Generated Python syntax' ($LASTEXITCODE -eq 0)
            $Values = @(ConvertTo-SimulationParameter @{SIM_DAYS=2;STUDY_RADIUS_KM=10.5;USE_REAL_POPULATION=$false})
            Assert-Check 'Numeric REST parameters use Number, not Decimal' (($Values | Where-Object name -eq 'STUDY_RADIUS_KM').type -eq 'Number')
            Assert-Check 'Unique safe run ID generated' (($Values | Where-Object name -eq 'RUN_ID').value -match '^[a-zA-Z0-9_]{1,48}$')
            Assert-Fails 'Unknown/secret parameter rejected' { ConvertTo-SimulationParameter @{API_KEY='not-a-real-key'} } 'Unsupported'
            Assert-Fails 'Parameter casing enforced' { ConvertTo-SimulationParameter @{sim_days=2} } 'casing'
            Assert-Fails 'Boolean string rejected' { ConvertTo-SimulationParameter @{OVERWRITE='false'} } 'JSON type'
            Assert-Fails 'Nonpositive simulation rejected' { ConvertTo-SimulationParameter @{SIM_DAYS=0} } 'positive'
            Assert-Fails 'Incompatible H3 resolution rejected' { ConvertTo-SimulationParameter @{H3_RESOLUTION=4} } 'between'
            Assert-Fails 'SQL identifier injection rejected' { ConvertTo-SimulationParameter @{TABLE_PREFIX='x;drop'} } 'TABLE_PREFIX'
            Assert-Fails 'Path traversal run ID rejected' { ConvertTo-SimulationParameter @{RUN_ID='..\elsewhere'} } 'RUN_ID'
            Assert-Fails 'Invalid coordinates rejected' { ConvertTo-SimulationParameter @{OUTBREAK_LAT=91} } 'Latitude'

            $script:Fixture = Get-Content (Join-Path $script:Root 'deploy\config\customer.sample.json') -Raw | ConvertFrom-Json -AsHashtable
            $script:Fixture.subscriptionId = '11111111-1111-1111-1111-111111111111'
            $script:Fixture.tenantId = '22222222-2222-2222-2222-222222222222'
            $script:Fixture.capacity.id = '33333333-3333-3333-3333-333333333333'
            $script:Fixture.keyVaultName = 'kv-offline-zombie'
            $script:Scenario = 'ready'
            $script:Methods = [System.Collections.Generic.List[string]]::new()
            function script:Invoke-AzJson {
                param([string[]]$Arguments)
                $script:Methods.Add(($Arguments -join ' '))
                switch ($Arguments[0]) {
                    'account' {
                        if ($script:Scenario -eq 'missing-azure') { throw 'Missing Azure authentication' }
                        return @{id=$script:Fixture.subscriptionId;tenantId=$script:Fixture.tenantId;user=@{type='user'}}
                    }
                    'provider' {
                        if ($script:Scenario -eq 'missing-network-provider' -and $Arguments -contains 'Microsoft.Network') {
                            return @{registrationState='NotRegistered';resourceTypes=@()}
                        }
                        $Locations = if ($script:Scenario -eq 'bad-region') {@('West Europe')} else {@('Central US')}
                        return @{registrationState='Registered';resourceTypes=@(@{resourceType='vaults';locations=$Locations},@{resourceType='capacities';locations=$Locations})}
                    }
                    'group' { return $false }
                    'resource' { return @() }
                    'keyvault' { return @{nameAvailable=($script:Scenario -ne 'vault-conflict');reason='AlreadyExists'} }
                    'ad' { return @{id='44444444-4444-4444-4444-444444444444'} }
                    default { throw "Unexpected CLI operation in offline validation: $($Arguments -join ' ')" }
                }
            }
            function script:Invoke-ServiceRequest {
                param([string]$Uri, [string]$Method = 'GET', [object]$Body, [string]$Audience)
                $script:Methods.Add("$Method $Uri")
                if ($script:Scenario -eq 'missing-fabric') { throw 'Missing Fabric permission' }
                if ($Uri -like '*/capacities') {
                    $Capacities = if ($script:Scenario -eq 'missing-capacity') {@()} else {
                        @(@{id=$script:Fixture.capacity.id;displayName='Offline capacity';sku='F2';state='Active';region='Central US'})
                    }
                    return @{Data=@{value=$Capacities}}
                }
                if ($Uri -like '*/workspaces') {
                    $Workspaces = @()
                    if ($script:Scenario -in @('workspace-compatible','workspace-incompatible','workspace-no-admin')) {
                        $Description = if ($script:Scenario -eq 'workspace-incompatible') {'Someone else owns this'} else {"fabric-zombie-outbreak:$($script:Fixture.deploymentName)"}
                        $Workspaces = @(@{displayName=$script:Fixture.workspaceName;description=$Description;id='55555555-5555-5555-5555-555555555555';capacityId=$script:Fixture.capacity.id})
                    }
                    return @{Data=@{value=$Workspaces}}
                }
                if ($Uri -like '*/roleAssignments') {
                    $Roles = if ($script:Scenario -eq 'workspace-no-admin') {@()} else {@(@{principal=@{id='44444444-4444-4444-4444-444444444444'};role='Admin'})}
                    return @{Data=@{value=$Roles}}
                }
                if ($Uri -like 'https://management.azure.com*/providers/Microsoft.KeyVault/vaults/*') {
                    if ($script:Scenario -eq 'secret-denied') { throw 'HTTP 403' }
                    $VaultId = "/subscriptions/$($script:Fixture.subscriptionId)/resourceGroups/$($script:Fixture.resourceGroupName)/providers/Microsoft.KeyVault/vaults/$($script:Fixture.keyVaultName)"
                    if ($Uri -eq "https://management.azure.com${VaultId}?api-version=2025-05-01") {
                        return @{Data=@{id=$VaultId;properties=@{publicNetworkAccess='Disabled'}}}
                    }
                    $Secrets = @(if ($script:Scenario -ne 'secret-missing') {
                        @{id="$VaultId/secrets/geoanalytics-api-key";properties=@{attributes=@{enabled=$true}}}
                    })
                    return @{Data=@{value=$Secrets}}
                }
                if ($Uri -like '*/items' -and $Method -eq 'GET') {
                    $Lakehouse = @{id='lakehouse';displayName='Offline Lakehouse';type='Lakehouse';description='offline-owner'}
                    $Endpoint = @{id='endpoint';displayName='Offline Lakehouse';type='SQLEndpoint';description=''}
                    $Items = @(switch ($script:Scenario) {
                        'items-pair' { $Lakehouse; $Endpoint }
                        'items-unowned' { $Lakehouse.description = 'someone-else'; $Lakehouse; $Endpoint }
                        'items-duplicate' { $Lakehouse; @{id='duplicate';displayName=$Lakehouse.displayName;type='Lakehouse';description='offline-owner'}; $Endpoint }
                        'items-endpoint-only' { $Endpoint }
                        'items-wrong-type' { @{id='environment';displayName=$Lakehouse.displayName;type='Environment';description='offline-owner'} }
                        'items-unrelated-conflict' { $Lakehouse; @{id='notebook';displayName=$Lakehouse.displayName;type='Notebook';description='offline-owner'}; $Endpoint }
                    })
                    return @{Data=@{value=$Items}}
                }
                if ($script:Scenario -eq 'import-failure') { throw 'Notebook import failed' }
                if ($script:Scenario -eq 'job-failure') { return @{StatusCode=200;Headers=@{};Data=@{status='Failed';id='job'}} }
                if ($script:Scenario -in @('job-run-failure','job-complete')) {
                    if ($Method -eq 'POST') {
                        $Location = if ($script:Scenario -eq 'job-complete') { '/v1/jobs/offline' } else { 'https://api.fabric.microsoft.com/v1/jobs/offline' }
                        return @{StatusCode=202;Headers=@{Location=$Location}}
                    }
                    if ($Uri -like '*beta=true') { return @{Data=@{properties=@{exitValue='{"run_id":"offline","outputs":{}}'}}} }
                    return @{StatusCode=200;Headers=@{};Data=@{status=$(if ($script:Scenario -eq 'job-complete') {'Completed'} else {'Failed'});id='offline'}}
                }
                if ($script:Scenario -eq 'publish-failure') { return @{StatusCode=200;Headers=@{};Data=@{status='Failed'}} }
                throw "Unexpected HTTP operation in offline check: $Uri"
            }
            $Report = Test-Prerequisite $script:Fixture
            Assert-Check 'Ready environment has no failed automated checks' (@($Report | Where-Object Status -eq 'Fail').Count -eq 0)
            Assert-Check 'Unconfirmed administrative prerequisites stay manual' (@($Report | Where-Object Status -eq 'Manual').Count -eq 5)
            Assert-Check 'Validate issues no mutation requests' (@($script:Methods | Where-Object { $_ -match '^(POST|PATCH|PUT|DELETE) |^(group create|deployment|provider register)' }).Count -eq 0)
            Assert-Check 'Existing-capacity validation requires Network but not Azure Fabric registration' (
                @($Report | Where-Object Check -eq 'Microsoft.Network').Count -eq 1 -and
                @($Report | Where-Object Check -eq 'Microsoft.Fabric').Count -eq 0)
            $script:Fixture.capacity.mode = 'new'
            $NewReport = Test-Prerequisite $script:Fixture
            Assert-Check 'Explicit new-capacity mode checks Azure Fabric registration' (
                @($NewReport | Where-Object Check -eq 'Microsoft.Fabric').Count -eq 1)
            $script:Fixture.capacity.mode = 'existing'
            foreach ($Scenario in @('missing-azure','missing-fabric','missing-capacity','bad-region','vault-conflict','workspace-incompatible','workspace-no-admin','missing-network-provider')) {
                $script:Scenario = $Scenario
                $Report = Test-Prerequisite $script:Fixture
                Assert-Check "Validation reports $Scenario explicitly" (@($Report | Where-Object Status -eq 'Fail').Count -gt 0)
            }
            $script:Scenario = 'workspace-compatible'
            $Report = Test-Prerequisite $script:Fixture
            Assert-Check 'Compatible owned workspace is reusable' (@($Report | Where-Object Status -eq 'Fail').Count -eq 0)
            $SecretManifest = @{
                keyVaultUri='https://kv-offline-zombie.vault.azure.net/'
                subscriptionId=$script:Fixture.subscriptionId;resourceGroupName=$script:Fixture.resourceGroupName
                keyVaultName=$script:Fixture.keyVaultName
                resources=@{keyVault=@{id="/subscriptions/$($script:Fixture.subscriptionId)/resourceGroups/$($script:Fixture.resourceGroupName)/providers/Microsoft.KeyVault/vaults/$($script:Fixture.keyVaultName)"}}
            }
            $script:Scenario = 'secret-missing'
            Assert-Fails 'Missing key fails explicitly' { Test-SecretMetadata $SecretManifest } 'Missing'
            $script:Scenario = 'secret-denied'
            Assert-Fails 'Secret access denied fails explicitly' { Test-SecretMetadata $SecretManifest } '403'
            $script:Scenario = 'publish-failure'
            function script:Start-Sleep { param([int]$Seconds) }
            Assert-Fails 'Failed asynchronous publication propagates' {
                Wait-FabricOperation @{StatusCode=202;Headers=@{Location='https://api.fabric.microsoft.com/v1/operations/offline'}}
            } 'Failed'
            $BeforeItemChecks = $script:Methods.Count
            $script:Scenario = 'items-pair'
            $Item = Get-OrCreateFabricItem -WorkspaceId 'w' -Name 'Offline Lakehouse' -Type Lakehouse -Owner 'offline-owner'
            Assert-Check 'Owned Lakehouse is reused alongside its same-named SQL endpoint' ($Item.id -eq 'lakehouse' -and $Item.created -eq $false)
            foreach ($Case in @(
                @{Scenario='items-unowned';Pattern='Incompatible or unowned';Name='Unowned Lakehouse is not adopted beside its SQL endpoint'},
                @{Scenario='items-duplicate';Pattern='Ambiguous';Name='Duplicate Lakehouses remain ambiguous beside a SQL endpoint'},
                @{Scenario='items-endpoint-only';Pattern='Incompatible or unowned';Name='SQL endpoint alone is not adopted as a Lakehouse'},
                @{Scenario='items-wrong-type';Pattern='Incompatible or unowned';Name='Another item type is not adopted as a Lakehouse'},
                @{Scenario='items-unrelated-conflict';Pattern='Ambiguous';Name='Non-endpoint name conflicts remain ambiguous'}
            )) {
                $script:Scenario = $Case.Scenario
                Assert-Fails $Case.Name {
                    Get-OrCreateFabricItem -WorkspaceId 'w' -Name 'Offline Lakehouse' -Type Lakehouse -Owner 'offline-owner'
                } $Case.Pattern
            }
            Assert-Check 'Lakehouse resume checks issue only item metadata GETs' (
                @($script:Methods | Select-Object -Skip $BeforeItemChecks | Where-Object { $_ -ne 'GET https://api.fabric.microsoft.com/v1/workspaces/w/items' }).Count -eq 0)
            $script:Scenario = 'import-failure'
            Assert-Fails 'Notebook import failure propagates' {
                Get-OrCreateFabricItem -WorkspaceId 'w' -Name 'n' -Type Notebook -Owner 'owner' -Definition @{format='ipynb'}
            } 'Notebook import failed'
            $script:Scenario = 'job-failure'
            Assert-Fails 'Job submission failure propagates' {
                Invoke-NotebookJob -Manifest @{workspaceId='w';notebookId='n'} -Parameters @(@{name='SIM_DAYS';value=2;type='Integer'})
            } 'submission'
            function script:Save-DeploymentManifest { param([hashtable]$Manifest) }
            $script:Scenario = 'job-run-failure'
            Assert-Fails 'Submitted notebook job failure propagates' {
                Invoke-NotebookJob -Manifest @{workspaceId='w';notebookId='n'} -Parameters @(@{name='SIM_DAYS';value=2;type='Integer'})
            } 'Notebook job Failed'
            $script:Scenario = 'job-complete'
            $JobManifest = @{workspaceId='w';notebookId='n'}
            $Completed = Invoke-NotebookJob -Manifest $JobManifest -Parameters @(@{name='SIM_DAYS';value=2;type='Integer'})
            Assert-Check 'Completed notebook job exit value and normalized polling URL are captured' (
                $Completed.run_id -eq 'offline' -and $JobManifest.lastJobUri -eq 'https://api.fabric.microsoft.com/v1/jobs/offline')
            $Schema = Join-Path $script:Root 'deploy\fabric\deployment-manifest.schema.json'
            $Manifest = @{
                deploymentName='offline';deploymentVersion='0.1.0';subscriptionId=$script:Fixture.subscriptionId
                tenantId=$script:Fixture.tenantId;userObjectId='44444444-4444-4444-4444-444444444444'
                resourceGroupName='rg-offline';location='centralus';createdAt=[datetime]::UtcNow.ToString('o')
                updatedAt=[datetime]::UtcNow.ToString('o');stage='AzureDeployed';resources=@{}
                capacityId=$script:Fixture.capacity.id;capacityMode='existing';keyVaultName='kv-offline-zombie'
                keyVaultUri=$SecretManifest.keyVaultUri;keyVaultSecretName='geoanalytics-api-key'
            }
            Assert-Check 'Nonsecret manifest schema accepts partial provisioning state' (Test-Json -Json ($Manifest | ConvertTo-Json -Depth 10) -SchemaFile $Schema)
            $Manifest.apiKey = 'not-a-real-key'
            Assert-Check 'Manifest schema rejects secret/unknown fields' (-not (Test-Json -Json ($Manifest | ConvertTo-Json -Depth 10) -SchemaFile $Schema -ErrorAction SilentlyContinue))
            Write-Host "Offline checks passed: $script:CheckCount"
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
