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
                if ($Uri -like '*vault.azure.net*') {
                    if ($script:Scenario -eq 'secret-denied') { throw 'HTTP 403' }
                    $Secrets = if ($script:Scenario -eq 'secret-missing') {@()} else {
                        @(@{id='https://kv-offline-zombie.vault.azure.net/secrets/geoanalytics-api-key';attributes=@{enabled=$true}})
                    }
                    return @{Data=@{value=$Secrets}}
                }
                if ($Uri -like '*/items' -and $Method -eq 'GET') { return @{Data=@{value=@()}} }
                if ($script:Scenario -eq 'import-failure') { throw 'Notebook import failed' }
                if ($script:Scenario -eq 'job-failure') { return @{StatusCode=200;Headers=@{};Data=@{status='Failed';id='job'}} }
                if ($script:Scenario -in @('job-run-failure','job-complete')) {
                    if ($Method -eq 'POST') { return @{StatusCode=202;Headers=@{Location='https://api.fabric.microsoft.com/v1/jobs/offline'}} }
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
            foreach ($Scenario in @('missing-azure','missing-fabric','missing-capacity','bad-region','vault-conflict','workspace-incompatible','workspace-no-admin')) {
                $script:Scenario = $Scenario
                $Report = Test-Prerequisite $script:Fixture
                Assert-Check "Validation reports $Scenario explicitly" (@($Report | Where-Object Status -eq 'Fail').Count -gt 0)
            }
            $script:Scenario = 'workspace-compatible'
            $Report = Test-Prerequisite $script:Fixture
            Assert-Check 'Compatible owned workspace is reusable' (@($Report | Where-Object Status -eq 'Fail').Count -eq 0)
            $SecretManifest = @{keyVaultUri='https://kv-offline-zombie.vault.azure.net/'}
            $script:Scenario = 'secret-missing'
            Assert-Fails 'Missing key fails explicitly' { Test-SecretMetadata $SecretManifest } 'Missing'
            $script:Scenario = 'secret-denied'
            Assert-Fails 'Secret access denied fails explicitly' { Test-SecretMetadata $SecretManifest } '403'
            $script:Scenario = 'publish-failure'
            function script:Start-Sleep { param([int]$Seconds) }
            Assert-Fails 'Failed asynchronous publication propagates' {
                Wait-FabricOperation @{StatusCode=202;Headers=@{Location='https://api.fabric.microsoft.com/v1/operations/offline'}}
            } 'Failed'
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
            $Completed = Invoke-NotebookJob -Manifest @{workspaceId='w';notebookId='n'} -Parameters @(@{name='SIM_DAYS';value=2;type='Integer'})
            Assert-Check 'Completed notebook job exit value is captured' ($Completed.run_id -eq 'offline')
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
