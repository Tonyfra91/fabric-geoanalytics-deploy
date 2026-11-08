#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Tests bounded result viewing without accessing Fabric or executing Spark.
.DESCRIPTION
    Checks generated Python, map rendering, publication-only lifecycle and historical job persistence.
.PARAMETER RepositoryRoot
    Root of this checkout.
.EXAMPLE
    .\deploy\tests\Test-ResultsPreview.ps1
.NOTES
    Python standard library only. Temporary fixtures are removed.
#>
[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $Temporary = [IO.Path]::GetTempFileName()
    try {
        $Module = Import-Module (Join-Path $RepositoryRoot 'deploy\scripts\Accelerator.psm1') -Force -PassThru
        & $Module {
            param($Fixture)
            $script:Checks = 0
            function Assert-Check([string]$Name, [bool]$Condition) {
                if (-not $Condition) { throw "FAIL: $Name" }
                $script:Checks++
                Write-Host "PASS: $Name"
            }
            function Assert-Fails([string]$Name, [scriptblock]$Action, [string]$Pattern) {
                $Failure = $null
                try { & $Action | Out-Null } catch { $Failure = $_.Exception.Message }
                Assert-Check $Name ([bool]($Failure -and $Failure -match $Pattern))
            }
            $Capacity = @{id='capacity';displayName='Offline';state='Active';sku='F2'}
            Assert-Check 'Active F capacity passes shared readiness check' ((Get-ActiveFabricCapacity @($Capacity) 'capacity').state -eq 'Active')
            $Capacity.state = 'Inactive'
            Assert-Fails 'Inactive capacity explains resume action before Environment calls' { Get-ActiveFabricCapacity @($Capacity) 'capacity' } 'not active.*resume'
            $Capacity.state = 'Active'
            Assert-Fails 'Ambiguous capacity is rejected' { Get-ActiveFabricCapacity @($Capacity,$Capacity) 'capacity' } 'uniquely visible'
            $Capacity.sku = 'P1'
            Assert-Fails 'Unsupported capacity SKU is rejected' { Get-ActiveFabricCapacity @($Capacity) 'capacity' } 'supported F SKU'
            $script:Manifest = @{
                deploymentName='offline';stage='Configured';resources=@{}
                workspaceId='11111111-1111-1111-1111-111111111111'
                lakehouseId='22222222-2222-2222-2222-222222222222'
                environmentId='33333333-3333-3333-3333-333333333333'
                notebookId='44444444-4444-4444-4444-444444444444'
                lastJobUri='https://api.fabric.microsoft.com/v1/original-simulation'
                lastResult=@{run_id='offline_run';outputs=@{
                    grid_population_vulnerability=@{table='grid';rows=2}
                    arrival=@{table='arrival';rows=1};origin=@{table='origin';rows=1}
                }}
            }
            $Notebook = New-ResultsNotebook -Manifest $script:Manifest -LakehouseName 'Lakehouse'
            $Notebook | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Fixture -Encoding utf8
            $Source = $Notebook.cells[1].source
            Assert-Check 'Viewer contains no credentials, input widgets, simulation or writes' (
                $Source -notmatch 'getSecret|putSecret|credentials|geoanalytics|Password|saveAsTable|\.write\.|fs\.put')
            Assert-Check 'Viewer binds only the existing Lakehouse and Environment' (
                $Notebook.metadata.dependencies.lakehouse.default_lakehouse -eq $script:Manifest.lakehouseId -and
                $Notebook.metadata.dependencies.environment.environmentId -eq $script:Manifest.environmentId)
            Assert-Check 'Viewer starts without saved outputs' ($Notebook.cells[1].outputs.Count -eq 0 -and $null -eq $Notebook.cells[1].execution_count)
            $script:Manifest.lastResult.outputs.origin.rows = 0
            Assert-Fails 'Missing origin blocks publication' { New-ResultsNotebook $script:Manifest 'Lakehouse' } 'one origin'
            $script:Manifest.lastResult.outputs.origin.rows = 1
            $script:Manifest.lastResult.outputs.arrival.rows = 5001
            Assert-Fails 'Oversized preview blocks publication rather than truncating' { New-ResultsNotebook $script:Manifest 'Lakehouse' } 'oversized'
            $script:Manifest.lastResult.outputs.arrival.rows = 1
            $script:Manifest.lastResult.outputs.arrival.rows = '1'
            Assert-Fails 'Noninteger receipt counts block publication' { New-ResultsNotebook $script:Manifest 'Lakehouse' } 'oversized'
            $script:Manifest.lastResult.outputs.arrival.rows = 1
            $script:Manifest.lastResult.outputs.arrival.table = 'arrival; DROP TABLE grid'
            Assert-Fails 'Invalid identifiers block publication' { New-ResultsNotebook $script:Manifest 'Lakehouse' } 'oversized'
            $script:Manifest.lastResult.outputs.arrival.table = 'arrival'
            $script:Mode = 'Definition'
            $script:SavedDefinition = $null
            $script:JobCalls = 0
            $script:BadDefinition = $false
            $script:BadBindings = $false
            $script:ItemCalls = 0
            $script:CreateCalls = 0
            $script:UpdateCalls = 0
            $script:PreviewId = '55555555-5555-5555-5555-555555555555'
            $script:PreviewUri = "https://api.fabric.microsoft.com/v1/workspaces/$($script:Manifest.workspaceId)/items/$script:PreviewId/jobs/instances/66666666-6666-6666-6666-666666666666"
            $script:Manifest.deploymentName = [IO.Path]::GetFileName($Fixture)
            $script:RealJob = (Get-Command Invoke-NotebookJob).ScriptBlock
            function script:Read-DeploymentManifest { param($Config) return $script:Manifest }
            function script:Get-DeploymentStatus { param($Config) return @{Lakehouse=@{name='Lakehouse'}} }
            function script:Save-DeploymentManifest { param($Manifest) $script:RecordedPreviewUri = $Manifest.lastPreviewJobUri }
            function script:Get-OrCreateFabricItem {
                param($WorkspaceId,$Name,$Type,$Owner,$Definition)
                if ($Type -ne 'Notebook' -or $Name -ne "$($script:Manifest.deploymentName) Results" -or
                    $Owner -ne "fabric-zombie-outbreak:$($script:Manifest.deploymentName)") {
                    throw 'Attempt to publish an asset other than the owned Results notebook.'
                }
                $script:ItemCalls++
                $Created = $script:ItemCalls -eq 1
                if ($Created) { $script:CreateCalls++ }
                $script:SavedDefinition = $Definition
                return @{id=$script:PreviewId;created=$Created}
            }
            function script:Invoke-ServiceRequest {
                param($Uri,$Method='GET',$Body)
                if ($script:Mode -eq 'Definition' -and $Uri -like '*/updateDefinition' -and $Method -eq 'POST') {
                    $script:UpdateCalls++
                    return @{StatusCode=200;Data=@{}}
                }
                if ($script:Mode -eq 'Definition' -and $Uri -like '*/getDefinition?format=ipynb' -and $Method -eq 'POST') {
                    if ($script:BadDefinition) { return @{StatusCode=200;Data=@{definition=@{parts=@()}}} }
                    if ($script:BadBindings) {
                        $Payload = [text.encoding]::UTF8.GetString([Convert]::FromBase64String($script:SavedDefinition.parts[0].payload)) |
                            ConvertFrom-Json -AsHashtable -Depth 100
                        $Payload.metadata.dependencies.environment.workspaceId = 'wrong-workspace'
                        $Encoded = [Convert]::ToBase64String([text.encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 100)))
                        return @{StatusCode=200;Data=@{definition=@{parts=@(
                            @{path='artifact.content.ipynb';payloadType='InlineBase64';payload=$Encoded}
                        )}}}
                    }
                    return @{StatusCode=200;Data=@{definition=$script:SavedDefinition}}
                }
                if ($script:Mode -eq 'Job' -and $Method -eq 'POST' -and $Uri -like '*/notebooks/*/jobs/execute/instances?beta=false') {
                    $script:SubmittedUri = $Uri
                    return @{StatusCode=202;Headers=@{Location=$script:PreviewUri;'Retry-After'='0'}}
                }
                if ($Uri -eq $script:PreviewUri) { return @{Data=@{id='66666666-6666-6666-6666-666666666666';status=$script:JobStatus}} }
                if ($script:Mode -eq 'Job' -and $Uri -like '*/jobs/execute/instances/*?beta=true') {
                    return @{Data=@{properties=@{exitValue='{"preview":"passed"}'}}}
                }
                throw "Unexpected request: $Method $Uri"
            }
            function script:Invoke-NotebookJob {
                param($Manifest,$Parameters,$NotebookId,$JobField)
                $script:JobCalls++
                throw 'Publication must not execute any Spark job.'
            }
            $Before = $script:Manifest.lastResult | ConvertTo-Json -Depth 10 -Compress
                Publish-ResultsNotebook @{}
                Assert-Check 'Publication submits no compute and preserves simulation job and result' (
                    $script:JobCalls -eq 0 -and $script:Manifest.lastJobUri -eq 'https://api.fabric.microsoft.com/v1/original-simulation' -and
                    ($script:Manifest.lastResult | ConvertTo-Json -Depth 10 -Compress) -ceq $Before)
                Assert-Check 'Only nonsecret Results identity is persisted; no preview state added' (
                    $script:Manifest.resultsNotebookId -eq $script:PreviewId -and
                    $script:Manifest.resources.ResultsNotebook.id -eq $script:PreviewId -and
                    -not $script:Manifest.ContainsKey('lastPreviewResult') -and
                    -not $script:Manifest.ContainsKey('lastPreviewJobUri'))
                $script:Manifest.lastPreviewJobUri = $script:PreviewUri
                $script:Manifest.lastPreviewResult = @{run_id='historical';svgPath='historical.svg'}
                $Historical = $script:Manifest.lastPreviewResult | ConvertTo-Json -Compress
                $script:JobStatus = 'InProgress'
                Assert-Fails 'An active historical preview blocks publication' { Publish-ResultsNotebook @{} } 'still be active'
                Assert-Check 'Active historical job caused no publication or compute' ($script:ItemCalls -eq 1 -and $script:JobCalls -eq 0)
                $script:JobStatus = 'Completed'
                Publish-ResultsNotebook @{}
                Assert-Check 'Rerun reuses one Results notebook without new creation or compute' (
                    $script:CreateCalls -eq 1 -and $script:UpdateCalls -eq 1 -and $script:JobCalls -eq 0)
                Assert-Check 'Historical preview fields and simulation receipt remain compatible and unchanged' (
                    $script:Manifest.lastPreviewJobUri -eq $script:PreviewUri -and
                    ($script:Manifest.lastPreviewResult | ConvertTo-Json -Compress) -ceq $Historical -and
                    ($script:Manifest.lastResult | ConvertTo-Json -Depth 10 -Compress) -ceq $Before)
                $script:BadDefinition = $true
                Assert-Fails 'Unverified saved definition fails publication explicitly' { Publish-ResultsNotebook @{} } 'saved results notebook'
                Assert-Check 'Definition mismatch submits no job' ($script:JobCalls -eq 0)
                $script:BadDefinition = $false
                $script:BadBindings = $true
                Assert-Fails 'Wrong Results workspace binding fails before compute' { Publish-ResultsNotebook @{} } 'source or bindings differ'
                Assert-Check 'Binding mismatch submits no job' ($script:JobCalls -eq 0)
                $script:Mode = 'Job'
                function script:Start-Sleep { param($Seconds) }
                $null = & $script:RealJob -Manifest $script:Manifest -Parameters @() -NotebookId $script:PreviewId -JobField lastPreviewJobUri
                Assert-Check 'Real job helper records preview separately before polling' (
                    $script:RecordedPreviewUri -eq $script:PreviewUri -and $script:Manifest.lastJobUri -eq 'https://api.fabric.microsoft.com/v1/original-simulation')
                $null = & $script:RealJob -Manifest $script:Manifest -Parameters @(@{name='CHECK_ONLY';value=$true;type='Boolean'})
                Assert-Check 'Default job helper still targets and records the workload notebook' (
                    $script:SubmittedUri -like "*/notebooks/$($script:Manifest.notebookId)/jobs/execute/instances?beta=false" -and
                    $script:Manifest.lastJobUri -eq $script:PreviewUri -and $script:Manifest.lastPreviewJobUri -eq $script:PreviewUri)
            Write-Host "$script:Checks results-viewer checks passed."
        } $Temporary
        & python -B (Join-Path $PSScriptRoot 'Test-ResultsPreview.py') --notebook $Temporary
        if ($LASTEXITCODE -ne 0) { throw 'Python results-preview tests failed.' }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
    finally {
        if (Test-Path -LiteralPath $Temporary) { Remove-Item -LiteralPath $Temporary }
    }
}
#endregion
