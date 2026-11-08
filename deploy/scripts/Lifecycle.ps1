#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Provisioning, secrets, and execution for the interactive POC.
.DESCRIPTION
    Loaded by Accelerator.psm1. All mutations require an explicit lifecycle command.
.EXAMPLE
    .\deploy.ps1 deploy -WhatIf
.NOTES
    Runtime access is proven by a separate preflight job only during run.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

#region State
function Save-DeploymentManifest {
    <#
    .SYNOPSIS
        Persists nonsecret state atomically after each provisioning milestone.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Manifest)
    $null = New-Item -ItemType Directory -Path $script:StateDirectory -Force
    $Path = Join-Path $script:StateDirectory "$($Manifest.deploymentName).json"
    $Json = $Manifest | ConvertTo-Json -Depth 30
    if (-not (Test-Json -Json $Json -SchemaFile (Join-Path $script:Root 'deploy\fabric\deployment-manifest.schema.json'))) {
        throw 'Deployment manifest failed the nonsecret state schema.'
    }
    $Json | Set-Content -LiteralPath "$Path.tmp" -Encoding utf8
    Move-Item -LiteralPath "$Path.tmp" -Destination $Path -Force
}

function Read-DeploymentManifest {
    <#
    .SYNOPSIS
        Loads state and prevents cross-tenant, cross-subscription, or cross-user execution.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Path = Join-Path $script:StateDirectory "$($Config.deploymentName).json"
    $Manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    $Account = Invoke-AzJson @('account','show')
    $User = Invoke-AzJson @('ad','signed-in-user','show')
    if ($Manifest.subscriptionId -ne $Config.subscriptionId -or $Manifest.tenantId -ne $Config.tenantId -or
        $Manifest.deploymentName -ne $Config.deploymentName -or $Account.id -ne $Manifest.subscriptionId -or
        $Account.tenantId -ne $Manifest.tenantId -or $Account.user.type -ne 'user' -or $User.id -ne $Manifest.userObjectId) {
        throw 'Manifest and authenticated interactive identity do not match. Use the original user or redeploy explicitly with the authorized user.'
    }
    if ($Manifest.keyVaultUri -ne "https://$($Config.keyVaultName).vault.azure.net/" -or
        $Manifest.keyVaultSecretName -ne 'geoanalytics-api-key' -or $Manifest.resourceGroupName -ne $Config.resourceGroupName) {
        throw 'Manifest does not match configuration.'
    }
    return $Manifest
}
#endregion

#region Managed private endpoint
function ConvertTo-KeyVaultManagedPrivateEndpoint {
    <#
    .SYNOPSIS
        Validates endpoint ownership and projects only nonsecret API metadata.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Manifest, [Parameter(Mandatory)][hashtable]$Endpoint)
    $Id = [guid]::Empty
    if (-not [guid]::TryParse($Endpoint.id, [ref]$Id) -or $Id -eq [guid]::Empty -or
        $Endpoint.name -ne "mpe-$($Manifest.keyVaultName)" -or
        ([string]$Endpoint.targetPrivateLinkResourceId).TrimEnd('/') -ne ([string]$Manifest.resources.keyVault.id).TrimEnd('/') -or
        $Endpoint.targetSubresourceType -ne 'vault') {
        throw 'Managed private endpoint ownership/configuration mismatch: expected the Fast Pass name, recorded Key Vault resource ID, and vault subresource. Nothing will be replaced.'
    }
    if ($Manifest.managedPrivateEndpoint -and $Manifest.managedPrivateEndpoint.id -ne $Endpoint.id) {
        throw 'Managed private endpoint ID differs from recorded state. Inspect the existing connection; it will not be adopted or replaced.'
    }
    if ($Endpoint.provisioningState -notin @('Provisioning','Updating','Succeeded','Failed','Deleting') -or
        ($Endpoint.connectionState.status -and $Endpoint.connectionState.status -notin @('Pending','Approved','Rejected','Disconnected'))) {
        throw "Unknown managed private endpoint state: activation=$($Endpoint.provisioningState), approval=$($Endpoint.connectionState.status). Inspect the connection before continuing."
    }
    return @{
        id=$Endpoint.id;name=$Endpoint.name;targetPrivateLinkResourceId=$Manifest.resources.keyVault.id
        targetSubresourceType=$Endpoint.targetSubresourceType;provisioningState=$Endpoint.provisioningState
        approvalState=$(if ($Endpoint.connectionState.status) { $Endpoint.connectionState.status } else { $null })
    }
}

function Get-KeyVaultManagedPrivateEndpoint {
    <#
    .SYNOPSIS
        Discovers and inspects the expected endpoint without creating or modifying it.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Manifest)
    $WorkspaceId = [guid]::Empty
    $VaultId = [string]$Manifest.resources.keyVault.id
    if (-not [guid]::TryParse($Manifest.workspaceId, [ref]$WorkspaceId) -or $WorkspaceId -eq [guid]::Empty -or
        $VaultId -notmatch '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.KeyVault/vaults/([^/]+)/?$' -or
        $Matches[1] -ne $Manifest.subscriptionId -or $Matches[2] -ne $Manifest.resourceGroupName -or
        $Matches[3] -ne $Manifest.keyVaultName) {
        throw 'Managed private endpoint requires a valid workspace ID and matching Key Vault ARM ID from deployment state.'
    }
    $Name = "mpe-$($Manifest.keyVaultName)"
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)/managedPrivateEndpoints"
    $Endpoints = @(Get-ServiceCollection $Base | Where-Object name -eq $Name)
    if ($Endpoints.Count -gt 1) { throw "Multiple managed private endpoints named $Name. No endpoint will be created or replaced." }
    if (-not $Endpoints.Count) {
        if ($Manifest.managedPrivateEndpoint) {
            throw 'Recorded managed private endpoint is missing from discovery. Inspect its connection before another submission; it will not be recreated automatically.'
        }
        return
    }
    $Listed = ConvertTo-KeyVaultManagedPrivateEndpoint -Manifest $Manifest -Endpoint $Endpoints[0]
    $Endpoint = (Invoke-ServiceRequest -Uri "$Base/$($Listed.id)").Data
    if ($Endpoint.id -ne $Listed.id) { throw 'Managed private endpoint inspection returned a different endpoint ID.' }
    return ConvertTo-KeyVaultManagedPrivateEndpoint -Manifest $Manifest -Endpoint $Endpoint
}

function Initialize-KeyVaultManagedPrivateEndpoint {
    <#
    .SYNOPSIS
        Creates or resumes the Fabric endpoint and stops until activation and Azure approval succeed.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Manifest, [int]$TimeoutSeconds = 1800)
    $Endpoint = Get-KeyVaultManagedPrivateEndpoint -Manifest $Manifest
    $VaultId = $Manifest.resources.keyVault.id
    $Vault = (Invoke-ServiceRequest -Uri "https://management.azure.com$($VaultId.TrimEnd('/'))?api-version=2025-05-01" `
        -Audience 'https://management.azure.com/').Data
    if (([string]$Vault.id).TrimEnd('/') -ne $VaultId.TrimEnd('/') -or $Vault.properties.publicNetworkAccess -ne 'Disabled') {
        throw 'Key Vault identity or networking differs from the private Fast Pass baseline. Public network access must remain Disabled; no networking settings were changed.'
    }
    $Disposition = 'Existing'
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)/managedPrivateEndpoints"
    if (-not $Endpoint) {
        $Response = Invoke-ServiceRequest -Uri $Base -Method POST -Body @{
            name="mpe-$($Manifest.keyVaultName)";targetPrivateLinkResourceId=$VaultId
            targetSubresourceType='vault';requestMessage='Fabric GeoAnalytics Fast Pass access to Key Vault'
        }
        if ($Response.StatusCode -ne 201) {
            throw 'Managed private endpoint creation did not return HTTP 201. Inspect workspace connections before another submission; no automatic retry will be made.'
        }
        $Endpoint = ConvertTo-KeyVaultManagedPrivateEndpoint -Manifest $Manifest -Endpoint $Response.Data
        $Disposition = 'Created'
        $Manifest.resources.ManagedPrivateEndpoint = @{id=$Endpoint.id;created=$true}
    }
    elseif (-not $Manifest.resources.ContainsKey('ManagedPrivateEndpoint')) {
        $Manifest.resources.ManagedPrivateEndpoint = @{id=$Endpoint.id;created=$false}
    }
    $Deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        $Manifest.managedPrivateEndpoint = $Endpoint
        $Manifest.updatedAt = [datetime]::UtcNow.ToString('o')
        Save-DeploymentManifest $Manifest
        $Approval = if ($Endpoint.approvalState) { $Endpoint.approvalState } else { 'not reported by Fabric' }
        Write-Host "Managed endpoint: $Disposition ($($Endpoint.name)); Activation: $($Endpoint.provisioningState); Azure approval: $Approval"
        if ($Endpoint.provisioningState -in @('Failed','Deleting') -or $Endpoint.approvalState -in @('Rejected','Disconnected')) {
            throw 'Managed private endpoint activation or approval failed. Inspect the recorded connection; it will not be deleted, replaced, or resubmitted.'
        }
        if ($Endpoint.approvalState -eq 'Pending') {
            throw "Azure approval Pending. Stop: open Key Vault $($Manifest.keyVaultName) > Networking > Private endpoint connections. Verify the Fabric request for $($Endpoint.name), target vault, and request message; an authorized administrator must approve it. Then rerun .\deploy.ps1 configure-network. No secret access is ready."
        }
        if ($Endpoint.provisioningState -eq 'Succeeded') {
            if ($Endpoint.approvalState -ne 'Approved') {
                throw 'Managed private endpoint activation succeeded but Azure approval is not reported. Inspect the connection and rerun configure-network; secret access is not ready.'
            }
            return $Endpoint
        }
        if ([datetime]::UtcNow.AddSeconds(15) -gt $Deadline) {
            throw 'Managed private endpoint activation timed out. The recorded endpoint may still be provisioning. Use status and configure-network to inspect/resume; do not submit a duplicate.'
        }
        Start-Sleep -Seconds 15
        $Raw = (Invoke-ServiceRequest -Uri "$Base/$($Endpoint.id)").Data
        $Endpoint = ConvertTo-KeyVaultManagedPrivateEndpoint -Manifest $Manifest -Endpoint $Raw
    }
}

function Set-DeploymentNetwork {
    <#
    .SYNOPSIS
        Resumes only the managed endpoint without republishing Fabric assets or redeploying Azure.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Manifest = Read-DeploymentManifest $Config
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)"
    $Workspace = (Invoke-ServiceRequest -Uri $Base).Data
    if ($Workspace.id -ne $Manifest.workspaceId -or $Workspace.description -ne "fabric-zombie-outbreak:$($Config.deploymentName)" -or
        $Workspace.capacityId -ne $Manifest.capacityId) {
        throw 'Workspace identity, ownership or capacity mismatch. No network changes were submitted.'
    }
    $Roles = @(Get-ServiceCollection "$Base/roleAssignments")
    if (-not @($Roles | Where-Object { $_.principal.id -eq $Manifest.userObjectId -and $_.role -eq 'Admin' }).Count) {
        throw 'Current user must be workspace Admin to configure the managed private endpoint. No privileges will be assigned.'
    }
    $null = Initialize-KeyVaultManagedPrivateEndpoint -Manifest $Manifest
    Write-Host 'Managed private endpoint activation Succeeded and Azure approval Approved. Secret access and notebook execution have not been tested.'
}
#endregion

#region Provisioning
function Get-CompletedAzureDeployment {
    <#
    .SYNOPSIS
        Reads a successful subscription deployment and validates the Azure handoff contract.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string]$DeploymentName)
    $Account = Invoke-AzJson @('account','show')
    if ($Account.user.type -ne 'user') { throw 'The portal handoff requires an interactive user. Run az login.' }
    $User = Invoke-AzJson @('ad','signed-in-user','show')
    $Azure = Invoke-AzJson @('deployment','sub','show','--name',$DeploymentName,'--subscription',$Account.id)
    if ($Azure.properties.provisioningState -ne 'Succeeded') { throw 'Azure deployment has not succeeded. Inspect the subscription deployment in the portal.' }
    $Parameters = $Azure.properties.parameters
    $Outputs = $Azure.properties.outputs
    if ($Parameters -isnot [hashtable] -or $Outputs -isnot [hashtable]) { throw 'Azure handoff parameters or outputs are missing.' }
    if ($Outputs.experienceVersion.value -ne '1.0' -or $Parameters.userObjectId.value -ne $User.id) {
        throw 'Azure deployment is not a supported handoff for the signed-in user.'
    }
    foreach ($Name in @('deploymentName','location','resourceGroupName','keyVaultName','userObjectId','shouldCreateCapacity','capacitySku','capacityAdministrators')) {
        if (-not $Parameters.ContainsKey($Name) -or $null -eq $Parameters[$Name].value) {
            throw "Azure handoff parameter missing: $Name"
        }
    }
    if ($Parameters.shouldCreateCapacity.value -isnot [bool]) { throw 'Azure handoff capacity flag must be a boolean.' }
    $GroupId = "/subscriptions/$($Account.id)/resourceGroups/$($Parameters.resourceGroupName.value)"
    if ($Outputs.keyVaultId.value -ne "$GroupId/providers/Microsoft.KeyVault/vaults/$($Parameters.keyVaultName.value)" -or
        $Outputs.keyVaultUri.value -ne "https://$($Parameters.keyVaultName.value).vault.azure.net/") {
        throw 'Azure handoff vault outputs do not match its parameters and subscription.'
    }
    if ($Parameters.shouldCreateCapacity.value -and
        ($Parameters.capacityName.value -notmatch '^[a-z][a-z0-9]{2,62}$' -or
         $Outputs.capacityResourceId.value -ne "$GroupId/providers/Microsoft.Fabric/capacities/$($Parameters.capacityName.value)")) {
        throw 'Azure handoff capacity output does not match its parameters and subscription.'
    }
    return $Azure
}

function New-PortalCustomerConfig {
    <#
    .SYNOPSIS
        Derives nonsecret configuration from the portal deployment without granting manual confirmations.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$AzureDeploymentName,
        [string]$ExistingCapacityId
    )
    $Azure = Get-CompletedAzureDeployment -DeploymentName $AzureDeploymentName
    $Account = Invoke-AzJson @('account','show')
    $Parameters = $Azure.properties.parameters
    $Config = Get-Content -LiteralPath (Join-Path $script:Root 'deploy\config\customer.sample.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($Name in @('deploymentName','location','resourceGroupName','keyVaultName')) { $Config[$Name] = $Parameters[$Name].value }
    $Config.subscriptionId = $Account.id
    $Config.tenantId = $Account.tenantId
    $Suffix = $Config.deploymentName -replace '-','_'
    $Config.workspaceName = "$($Config.deploymentName) GeoAnalytics"
    $Config.lakehouseName = "Geo_$Suffix"
    $Config.environmentName = "$($Config.deploymentName) Runtime 1-3"
    $Config.notebookName = "$($Config.deploymentName) Demo"
    if ($Parameters.shouldCreateCapacity.value) {
        if ($ExistingCapacityId) { throw 'Do not supply ExistingCapacityId when the portal created a new capacity.' }
        $Config.capacity = @{
            mode='new';id='';name=$Parameters.capacityName.value
            sku=$Parameters.capacitySku.value;administrators=@($Parameters.capacityAdministrators.value)
        }
    } else {
        $Id = [guid]::Empty
        if (-not [guid]::TryParse($ExistingCapacityId, [ref]$Id) -or $Id -eq [guid]::Empty) {
            throw 'Supply ExistingCapacityId as the existing Fabric capacity GUID, not its ARM resource ID.'
        }
        $Config.capacity.id = $ExistingCapacityId
    }
    return $Config
}

function Get-VerifiedAzureDeployment {
    <#
    .SYNOPSIS
        Rejects mismatched configuration before a portal handoff can mutate Fabric.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Config, [Parameter(Mandatory)][string]$DeploymentName)
    $Azure = Get-CompletedAzureDeployment -DeploymentName $DeploymentName
    $Account = Invoke-AzJson @('account','show')
    if ($Config.subscriptionId -ne $Account.id -or $Config.tenantId -ne $Account.tenantId) {
        throw 'Azure handoff account does not match configuration.'
    }
    foreach ($Name in @('deploymentName','location','resourceGroupName','keyVaultName')) {
        if ($Azure.properties.parameters[$Name].value -cne $Config[$Name]) { throw "Azure handoff configuration mismatch: $Name" }
    }
    $Parameters = $Azure.properties.parameters
    if ($Parameters.shouldCreateCapacity.value -ne ($Config.capacity.mode -eq 'new')) { throw 'Azure handoff capacity mode mismatch.' }
    if ($Config.capacity.mode -eq 'new' -and
        ($Parameters.capacityName.value -cne $Config.capacity.name -or $Parameters.capacitySku.value -cne $Config.capacity.sku -or
         (@($Parameters.capacityAdministrators.value | Sort-Object) -join ',') -cne (@($Config.capacity.administrators | Sort-Object) -join ','))) {
        throw 'Azure handoff new capacity configuration mismatch.'
    }
    return $Azure
}

function Get-OrCreateFabricItem {
    <#
    .SYNOPSIS
        Reuses only unambiguous deployment-owned items, or creates one.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$WorkspaceId,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Lakehouse','Environment','Notebook')][string]$Type,
        [Parameter(Mandatory)][string]$Owner,
        [hashtable]$Definition
    )
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items"
    $Matches = @(Get-ServiceCollection $Base | Where-Object displayName -eq $Name)
    if ($Type -eq 'Lakehouse' -and @($Matches | Where-Object type -eq 'Lakehouse').Count -eq 1) {
        $Matches = @($Matches | Where-Object type -ne 'SQLEndpoint')
    }
    if ($Matches.Count -gt 1) { throw "Ambiguous item name: $Name" }
    if ($Matches.Count) {
        $Item = $Matches[0]
        if ($Item.type -ne $Type -or $Item.description -ne $Owner) { throw "Incompatible or unowned item: $Name" }
        return @{id=$Item.id;created=$false}
    }
    $Body = @{displayName=$Name;type=$Type;description=$Owner}
    if ($Definition) { $Body.definition = $Definition }
    $Item = Wait-FabricOperation (Invoke-ServiceRequest -Uri $Base -Method POST -Body $Body)
    if (-not $Item.id) { throw "Create $Type did not return an ID. Inspect the workspace before retrying." }
    return @{id=$Item.id;created=$true}
}

function Wait-WorkspaceCapacity {
    <#
    .SYNOPSIS
        Verifies capacity assignment through workspace reads because assignment need not return Location.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$WorkspaceId,
        [Parameter(Mandatory)][string]$CapacityId,
        [ValidateRange(0,1800)][int]$TimeoutSeconds = 600
    )
    $Deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $Workspace = (Invoke-ServiceRequest -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId").Data
        if (-not $Workspace -or $Workspace.id -ne $WorkspaceId) { throw 'Capacity assignment check returned unexpected workspace metadata.' }
        if ($Workspace.capacityId -eq $CapacityId) { return $Workspace }
        if ($Workspace.capacityId) { throw 'Workspace belongs to a different capacity; refusing reassignment.' }
        if ([datetime]::UtcNow.AddSeconds(10) -gt $Deadline) {
            throw 'Workspace capacity assignment timed out. It may still be running; inspect the workspace before retrying.'
        }
        Write-Host '[Workspace capacity assignment] Pending'
        Start-Sleep -Seconds 10
    } while ($true)
}

function Invoke-Deployment {
    <#
    .SYNOPSIS
        Validates, provisions Azure resources and Fabric items, and never executes the simulation.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config, [switch]$WhatIf, [string]$AzureDeploymentName)
    if ($AzureDeploymentName -and $WhatIf) { throw 'Portal handoff cannot be combined with WhatIf.' }
    $PortalAzure = if ($AzureDeploymentName) { Get-VerifiedAzureDeployment -Config $Config -DeploymentName $AzureDeploymentName } else { $null }
    $Report = Test-Prerequisite -Config $Config
    $Report | Format-Table -AutoSize -Wrap | Out-Host
    if (@($Report | Where-Object Status -eq 'Fail').Count) { throw 'Prerequisite validation failed; no resources were changed.' }
    if (-not $WhatIf -and @($Report | Where-Object Status -eq 'Manual').Count) {
        throw 'Manual prerequisite confirmation required. Obtain administrator/customer confirmation before setting confirmations to true.'
    }
    $ExistingManifest = Join-Path $script:StateDirectory "$($Config.deploymentName).json"
    $PreviousManifest = if (Test-Path -LiteralPath $ExistingManifest) { Read-DeploymentManifest $Config } else { $null }
    $User = Invoke-AzJson @('ad','signed-in-user','show')
    $VaultExisted = @(Invoke-AzJson @('resource','list','--resource-type','Microsoft.KeyVault/vaults','--subscription',$Config.subscriptionId) |
        Where-Object name -eq $Config.keyVaultName).Count -gt 0
    $Parameters = @{
        deploymentName=@{value=$Config.deploymentName};location=@{value=$Config.location}
        resourceGroupName=@{value=$Config.resourceGroupName};keyVaultName=@{value=$Config.keyVaultName}
        userObjectId=@{value=$User.id};shouldCreateCapacity=@{value=($Config.capacity.mode -eq 'new')}
        capacityName=@{value=$(if ($Config.capacity.mode -eq 'new') {$Config.capacity.name} else {$null})}
        capacitySku=@{value=$Config.capacity.sku};capacityAdministrators=@{value=@($Config.capacity.administrators)}
    }
    $null = New-Item -ItemType Directory -Path $script:StateDirectory -Force
    $ParameterFile = Join-Path $script:StateDirectory "$($Config.deploymentName).parameters.json"
    @{parameters=$Parameters} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ParameterFile -Encoding utf8
    $Arguments = @('deployment','sub',$(if ($WhatIf) {'what-if'} else {'create'}),
        '--name',$Config.deploymentName,'--location',$Config.location,'--subscription',$Config.subscriptionId,
        '--template-file',(Join-Path $script:Root 'deploy\main.bicep'),'--parameters',"@$ParameterFile")
    if ($WhatIf) {
        $Arguments += '--no-pretty-print'
        $Preview = Invoke-AzJson $Arguments
        if ($Preview.status -ne 'Succeeded') { throw 'ARM what-if did not complete successfully. Review Azure deployment diagnostics.' }
        $Preview | ConvertTo-Json -Depth 50 | Out-Host
        Write-Host 'Azure what-if only. Fabric API mutations are not included in ARM what-if.'
        return
    }
    $Azure = if ($PortalAzure) { $PortalAzure } else { Invoke-AzJson $Arguments }
    $CapacityId = $Config.capacity.id
    if ($Config.capacity.mode -eq 'new') {
        $Deadline = [datetime]::UtcNow.AddMinutes(10)
        do {
            $Capacities = @(Get-ServiceCollection 'https://api.fabric.microsoft.com/v1/capacities' |
                Where-Object { $_.displayName -eq $Config.capacity.name -and $_.state -eq 'Active' })
            if ($Capacities.Count -gt 1) { throw 'New capacity name resolved to multiple Fabric capacities.' }
            if ($Capacities.Count -eq 1) { $CapacityId = $Capacities[0].id; break }
            if ([datetime]::UtcNow -gt $Deadline) { throw 'New capacity is not yet visible to the user in Fabric. Azure resources remain deployed; inspect capacity access before retrying.' }
            Start-Sleep -Seconds 20
        } while ($true)
    }
    $Manifest = if ($PreviousManifest) { $PreviousManifest } else {
        @{
            deploymentName=$Config.deploymentName;deploymentVersion='0.1.0';subscriptionId=$Config.subscriptionId
            tenantId=$Config.tenantId;resourceGroupName=$Config.resourceGroupName;location=$Config.location
            userObjectId=$User.id;createdAt=[datetime]::UtcNow.ToString('o');resources=@{}
        }
    }
    $Manifest.keyVaultName = $Config.keyVaultName
    $Manifest.keyVaultUri = $Azure.properties.outputs.keyVaultUri.value
    $Manifest.keyVaultSecretName = 'geoanalytics-api-key'
    $Manifest.capacityId = $CapacityId
    $Manifest.capacityMode = $Config.capacity.mode
    if (-not $Manifest.resources.ContainsKey('keyVault')) {
        $Manifest.resources.keyVault = @{id=$Azure.properties.outputs.keyVaultId.value;created=([bool]$PortalAzure -or -not $VaultExisted)}
    }
    $Manifest.updatedAt = [datetime]::UtcNow.ToString('o')
    $Manifest.stage = 'AzureDeployed'
    Save-DeploymentManifest $Manifest
    $Owner = "fabric-zombie-outbreak:$($Config.deploymentName)"
    $Workspaces = @(Get-ServiceCollection 'https://api.fabric.microsoft.com/v1/workspaces' | Where-Object displayName -eq $Config.workspaceName)
    if ($Workspaces.Count -gt 1) { throw 'Multiple matching workspaces. No workspace was modified.' }
    if ($Workspaces.Count) {
        $Workspace = $Workspaces[0]
        if ($Workspace.description -ne $Owner) { throw 'Workspace ownership mismatch.' }
        if (-not $Manifest.resources.ContainsKey('workspace')) { $Manifest.resources.workspace = @{id=$Workspace.id;created=$false} }
    } else {
        $Workspace = Wait-FabricOperation (Invoke-ServiceRequest -Uri 'https://api.fabric.microsoft.com/v1/workspaces' `
            -Method POST -Body @{displayName=$Config.workspaceName;description=$Owner})
        if (-not $Workspace.id) { throw 'Workspace creation returned no ID.' }
        $Manifest.resources.workspace = @{id=$Workspace.id;created=$true}
    }
    $Manifest.workspaceId = $Workspace.id
    Save-DeploymentManifest $Manifest
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Workspace.id)"
    if ($Workspace.capacityId -and $Workspace.capacityId -ne $CapacityId) { throw 'Workspace belongs to a different capacity; refusing reassignment.' }
    if ($Workspace.capacityId -ne $CapacityId) {
        $null = Invoke-ServiceRequest -Uri "$Base/assignToCapacity" -Method POST -Body @{capacityId=$CapacityId}
        $Workspace = Wait-WorkspaceCapacity -WorkspaceId $Workspace.id -CapacityId $CapacityId
    }
    $Roles = @(Get-ServiceCollection "$Base/roleAssignments")
    if (-not @($Roles | Where-Object { $_.principal.id -eq $User.id -and $_.role -eq 'Admin' }).Count) {
        throw 'Current user is not workspace Admin. No additional privileges will be fabricated or silently assigned.'
    }
    $null = Initialize-KeyVaultManagedPrivateEndpoint -Manifest $Manifest
    foreach ($Type in @('Lakehouse','Environment','Notebook')) {
        $Name = $Config["$($Type.ToLowerInvariant())Name"]
        $Options = @{WorkspaceId=$Workspace.id;Name=$Name;Type=$Type;Owner=$Owner}
        if ($Type -eq 'Notebook') {
            $Notebook = New-DeployableNotebook -WorkspaceId $Workspace.id -LakehouseId $Manifest.lakehouseId `
                -EnvironmentId $Manifest.environmentId -LakehouseName $Config.lakehouseName -KeyVaultUri $Manifest.keyVaultUri
            $Json = $Notebook | ConvertTo-Json -Depth 100
            $Json | Set-Content -LiteralPath (Join-Path $script:StateDirectory 'Zombie_Outbreak_Deployable.ipynb') -Encoding utf8
            $Definition = @{
                format='ipynb'
                parts=@(@{path='artifact.content.ipynb';payloadType='InlineBase64';payload=[Convert]::ToBase64String([text.encoding]::UTF8.GetBytes($Json))})
            }
            $Options.Definition = $Definition
        }
        $Item = Get-OrCreateFabricItem @Options
        if (-not $Manifest.resources.ContainsKey($Type)) { $Manifest.resources[$Type] = $Item }
        $Manifest["$($Type.ToLowerInvariant())Id"] = $Item.id
        Save-DeploymentManifest $Manifest
        if ($Type -eq 'Environment') {
            $EnvironmentBase = "$Base/environments/$($Item.id)"
            $Environment = (Invoke-ServiceRequest -Uri $EnvironmentBase).Data
            if ($Environment.properties.publishDetails.state -in @('Running','Waiting','Cancelling')) {
                throw 'An environment publication is already in progress. Wait for it before redeploying.'
            }
            $Settings = Get-Content -LiteralPath (Join-Path $script:Root 'deploy\fabric\environment\spark-compute.json') -Raw | ConvertFrom-Json -AsHashtable
            $null = Invoke-ServiceRequest -Uri "$EnvironmentBase/staging/sparkcompute?beta=false" -Method PATCH -Body $Settings
            $null = Invoke-ServiceRequest -Uri "$EnvironmentBase/staging/publish?beta=false" -Method POST
            $Deadline = [datetime]::UtcNow.AddMinutes(30)
            do {
                $Environment = (Invoke-ServiceRequest -Uri $EnvironmentBase).Data
                $State = $Environment.properties.publishDetails.state
                Write-Host "[Environment publication] $State"
                if ($State -eq 'Success') { break }
                if ($State -notin @('Running','Waiting') -or [datetime]::UtcNow -gt $Deadline) {
                    throw "Environment publication did not succeed: $State. No notebook will be imported."
                }
                Start-Sleep -Seconds 15
            } while ($true)
            $Compute = (Invoke-ServiceRequest -Uri "$EnvironmentBase/sparkcompute?beta=false").Data
            if ($Compute.runtimeVersion -ne '1.3' -or
                -not @($Compute.sparkProperties | Where-Object { $_.key -eq 'spark.native.enabled' -and $_.value -eq 'false' }).Count) {
                throw 'Published environment runtime or Native Execution Engine settings differ from requirements.'
            }
        }
        elseif ($Type -eq 'Notebook' -and -not $Item.created) {
            $null = Wait-FabricOperation -NoResult (Invoke-ServiceRequest -Uri "$Base/items/$($Item.id)/updateDefinition" -Method POST -Body @{definition=$Definition})
        }
    }
    $Manifest.stage = 'Validating'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $Commit = & git -C $script:Root rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Cannot record repository commit identifier.' }
        $Manifest.repositoryCommit = $Commit
    }
    Save-DeploymentManifest $Manifest
    $Status = Get-DeploymentStatus $Config
    if (-not $Status.managedPrivateEndpointReady) {
        throw 'Managed private endpoint is no longer activated and approved. Inspect status and resume configure-network before finishing deployment.'
    }
    $Manifest.stage = 'Configured'
    Save-DeploymentManifest $Manifest
    Write-Host 'Deployment configured. No notebook was executed. Managed endpoint activation and approval verified. Next: .\deploy.ps1 configure-secret'
}
#endregion

#region Secrets and run/status
function Get-GeoAnalyticsSecretMetadata {
    <#
    .SYNOPSIS
        Reads only ARM secret metadata, without requiring a client route into the private vault.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Manifest)
    $VaultId = ([string]$Manifest.resources.keyVault.id).TrimEnd('/')
    $ExpectedId = "/subscriptions/$($Manifest.subscriptionId)/resourceGroups/$($Manifest.resourceGroupName)/providers/Microsoft.KeyVault/vaults/$($Manifest.keyVaultName)"
    if (-not $VaultId -or $VaultId -ne $ExpectedId) { throw 'Secret metadata requires the matching Key Vault ARM ID from deployment state.' }
    $Vault = (Invoke-ServiceRequest -Uri "https://management.azure.com${VaultId}?api-version=2025-05-01" -Audience 'https://management.azure.com/').Data
    if ($Vault.id -ne $VaultId -or $Vault.properties.publicNetworkAccess -ne 'Disabled') {
        throw 'Key Vault identity or networking differs from the private Fast Pass baseline. Public network access must remain Disabled.'
    }
    $Uri = "https://management.azure.com$VaultId/secrets?api-version=2025-05-01"
    $Seen = [System.Collections.Generic.HashSet[string]]::new()
    while ($Uri) {
        $Parsed = [uri]$Uri
        if ($Parsed.Scheme -ne 'https' -or $Parsed.Host -ne 'management.azure.com' -or
            -not $Parsed.IsDefaultPort -or $Parsed.UserInfo -or $Parsed.Fragment -or
            $Parsed.AbsolutePath.TrimEnd('/') -ne "$VaultId/secrets") {
            throw 'Unexpected Key Vault ARM metadata continuation URL. Stopped without following it.'
        }
        if (-not $Seen.Add($Uri)) { throw 'Repeated Key Vault continuation URL.' }
        $Page = (Invoke-ServiceRequest -Uri $Uri -Audience 'https://management.azure.com/').Data
        if ($Page -isnot [hashtable] -or $Page.value -isnot [array]) { throw 'Invalid Key Vault ARM metadata response.' }
        foreach ($Secret in $Page.value) {
            if ($Secret.id -eq "$VaultId/secrets/geoanalytics-api-key") {
                $Attributes = $Secret.properties.attributes
                $Now = [datetimeoffset]::UtcNow.ToUnixTimeSeconds()
                if ($Attributes.enabled -isnot [bool] -or -not $Attributes.enabled -or
                    ($null -ne $Attributes.exp -and $Attributes.exp -le $Now) -or
                    ($null -ne $Attributes.nbf -and $Attributes.nbf -gt $Now)) {
                    throw 'GeoAnalytics secret is disabled, expired, or not yet valid.'
                }
                return @{id=$Secret.id;enabled=$true;expires=$Attributes.exp;notBefore=$Attributes.nbf}
            }
        }
        $Uri = $Page.nextLink
    }
}

function Test-SecretMetadata {
    <#
    .SYNOPSIS
        Requires enabled, currently valid ARM metadata without retrieving a secret value.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Manifest)
    if (-not (Get-GeoAnalyticsSecretMetadata -Manifest $Manifest)) {
        throw 'Missing geoanalytics-api-key. Run configure-secret and complete the secure Azure deployment.'
    }
}

function Set-GeoAnalyticsSecret {
    <#
    .SYNOPSIS
        Shows the secure Azure deployment handoff; never accepts or handles a credential.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Manifest = Read-DeploymentManifest $Config
    if ($Manifest.stage -ne 'Configured') { throw 'Finish deployment before configuring the secret.' }
    if (Get-GeoAnalyticsSecretMetadata -Manifest $Manifest) {
        Write-Host 'Secret metadata verified; runtime access is checked during run. No credential was requested or changed.'
        return
    }
    $TemplatePath = Join-Path $script:Root 'deploy\secret-setup.azuredeploy.json'
    if (-not (Test-Path -LiteralPath $TemplatePath)) { throw 'Secure deployment template is missing. Restore the checkout or run Build-Template.ps1.' }
    Write-Host 'Customer action required: securely provide the Esri key in Azure, not this terminal or Copilot.'
    Write-Host 'Open https://portal.azure.com/#create/Microsoft.Template and choose Build your own template in the editor.'
    Write-Host "Choose Load file, select $TemplatePath, then Save. The file contains no credential."
    Write-Host "Select subscription $($Manifest.subscriptionId), existing resource group $($Manifest.resourceGroupName), Key Vault $($Manifest.keyVaultName)."
    Write-Host 'Enter the key only in the masked Geo Analytics Api Key parameter field, never in the template editor.'
    Write-Host 'Review + create: Incremental deployment of one enabled geoanalytics-api-key secret; no vault, networking, RBAC or Fabric updates.'
    Write-Host 'Do not continue if a credential already exists or the review shows other resources. Do not export parameters or enable debug logging.'
    Write-Host 'After Deployment succeeded, run .\deploy.ps1 verify-secret. Do not rerun Fabric finish.'
}

function Test-GeoAnalyticsSecret {
    <#
    .SYNOPSIS
        Verifies the configured deployment's credential using ARM metadata only.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)
    Test-SecretMetadata -Manifest (Read-DeploymentManifest -Config $Config)
}

function Invoke-NotebookJob {
    <#
    .SYNOPSIS
        Submits once, records the job immediately, and polls terminal status with a bounded timeout.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Parameters,
        [string]$NotebookId = $Manifest.notebookId,
        [ValidateSet('lastJobUri','lastPreviewJobUri')][string]$JobField = 'lastJobUri'
    )
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)"
    $Response = Invoke-ServiceRequest -Uri "$Base/notebooks/$NotebookId/jobs/execute/instances?beta=false" -Method POST -Body @{
        parameters=$Parameters
        executionData=@{compute='Spark';computeConfiguration=@{
            defaultLakehouse=@{referenceType='ById';itemId=$Manifest.lakehouseId;workspaceId=$Manifest.workspaceId}
            attachedEnvironment=@{referenceType='ById';itemId=$Manifest.environmentId;workspaceId=$Manifest.workspaceId}
            sparkProperties=@(@{key='spark.native.enabled';value='false'})
        }}
    }
    $Uri = [string]($Response.Headers['Location'] | Select-Object -First 1)
    if ($Response.StatusCode -ne 202 -or -not $Uri) { throw 'Notebook submission did not return an accepted job with Location.' }
    $Uri = Resolve-FabricOperationUri -Location $Uri
    $Manifest[$JobField] = $Uri
    Save-DeploymentManifest $Manifest
    Write-Host "Submitted notebook job: $Uri"
    $Deadline = [datetime]::UtcNow.AddHours(2)
    do {
        $Delay = 15
        if ($Response.Headers['Retry-After']) { $Delay = [int]($Response.Headers['Retry-After'] | Select-Object -First 1) }
        if ([datetime]::UtcNow.AddSeconds($Delay) -gt $Deadline) { throw "Notebook polling timed out; job may still be running: $Uri" }
        Start-Sleep -Seconds ([Math]::Max(1,$Delay))
        $Response = Invoke-ServiceRequest -Uri $Uri
        $Job = $Response.Data
        Write-Host "[Notebook job $($Job.id)] $($Job.status)"
        if ($Job.status -in @('Failed','Cancelled','Deduped')) { throw "Notebook job $($Job.status). Inspect run $Uri in Fabric for failure details." }
        if ($Job.status -notin @('NotStarted','InProgress','Completed')) { throw "Unexpected notebook job state: $($Job.status)" }
    } while ($Job.status -ne 'Completed')
    # Exit values are currently exposed by a beta notebook-specific endpoint, not the GA scheduler response.
    $Details = (Invoke-ServiceRequest -Uri "$Base/notebooks/$NotebookId/jobs/execute/instances/$($Job.id)?beta=true").Data
    if (-not $Details.properties.exitValue) { throw 'Completed job returned no exit value. Inspect the notebook run; outputs have not been verified.' }
    return ($Details.properties.exitValue | ConvertFrom-Json -AsHashtable -Depth 20)
}

function ConvertTo-SimulationParameter {
    <#
    .SYNOPSIS
        Validates run-time values before submitting any job or touching secrets.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([hashtable]$InputValues = @{})
    $Values = @{RUN_ID=([datetime]::UtcNow.ToString('yyyyMMddTHHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,6))}
    $Allowed = @{
        OUTBREAK_NAME='Text';OUTBREAK_LAT='Number';OUTBREAK_LON='Number';OUTBREAK_START='Text'
        SIM_DAYS='Integer';H3_RESOLUTION='Integer';STUDY_RADIUS_KM='Number';NEIGHBOR_RADIUS_KM='Number'
        INITIAL_ZOMBIES='Number';RANDOM_SEED='Integer';USE_REAL_POPULATION='Boolean';TABLE_PREFIX='Text';OVERWRITE='Boolean';RUN_ID='Text'
    }
    foreach ($Key in $InputValues.Keys) {
        if ($Key -cnotin @($Allowed.Keys)) { throw "Unsupported run parameter or incorrect casing: $Key" }
        $Value = $InputValues[$Key]
        $Type = $Allowed[$Key]
        if (($Type -eq 'Text' -and $Value -isnot [string]) -or
            ($Type -eq 'Boolean' -and $Value -isnot [bool]) -or
            ($Type -eq 'Integer' -and $Value -isnot [long] -and $Value -isnot [int]) -or
            ($Type -eq 'Number' -and $Value -isnot [double] -and $Value -isnot [decimal] -and $Value -isnot [long] -and $Value -isnot [int])) {
            throw "Incorrect JSON type for run parameter $Key ($Type)."
        }
        $Values[$Key] = $Value
    }
    foreach ($Key in @('SIM_DAYS','STUDY_RADIUS_KM','NEIGHBOR_RADIUS_KM','INITIAL_ZOMBIES')) {
        if ($Values.ContainsKey($Key) -and $Values[$Key] -le 0) { throw "$Key must be positive." }
    }
    if ($Values.ContainsKey('H3_RESOLUTION') -and ($Values.H3_RESOLUTION -lt 5 -or $Values.H3_RESOLUTION -gt 10)) { throw 'H3_RESOLUTION must be between 5 and 10 (coarse partition resolution is 4).' }
    if ($Values.ContainsKey('OUTBREAK_LAT') -and [math]::Abs($Values.OUTBREAK_LAT) -gt 90) { throw 'Latitude must be within -90 to 90.' }
    if ($Values.ContainsKey('OUTBREAK_LON') -and [math]::Abs($Values.OUTBREAK_LON) -gt 180) { throw 'Longitude must be within -180 to 180.' }
    if ($Values.RUN_ID -cnotmatch '^[a-zA-Z0-9_]{1,48}$') { throw 'RUN_ID must be 1-48 alphanumeric/underscore characters.' }
    if ($Values.ContainsKey('TABLE_PREFIX') -and $Values.TABLE_PREFIX -cnotmatch '^[a-z][a-z0-9_]{0,23}$') { throw 'Invalid TABLE_PREFIX.' }
    if ($Values.ContainsKey('OUTBREAK_START')) {
        $Timestamp = [datetime]::MinValue
        if (-not [datetime]::TryParse($Values.OUTBREAK_START, [ref]$Timestamp)) { throw 'Invalid OUTBREAK_START timestamp.' }
    }
    return @($Values.Keys | Sort-Object | ForEach-Object { @{name=$_;value=$Values[$_];type=$Allowed[$_]} })
}

function Invoke-Simulation {
    <#
    .SYNOPSIS
        Verifies runtime secret access with a preflight job, then explicitly runs the simulation.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config, [string]$ParametersPath)
    $InputValues = if ($ParametersPath) { Get-Content -LiteralPath $ParametersPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    if ($InputValues -isnot [hashtable]) { throw 'Simulation parameters must be a JSON object.' }
    $Parameters = @(ConvertTo-SimulationParameter $InputValues)
    $RunId = ($Parameters | Where-Object name -eq 'RUN_ID').value
    $Manifest = Read-DeploymentManifest $Config
    if ($Manifest.stage -ne 'Configured') { throw 'Deployment is incomplete. Finish deploy before run.' }
    $null = Get-DeploymentStatus $Config
    Test-SecretMetadata $Manifest
    $Preflight = Invoke-NotebookJob -Manifest $Manifest -Parameters @(@{name='CHECK_ONLY';value=$true;type='Boolean'})
    if ($Preflight.preflight -ne 'passed') { throw 'Runtime preflight did not confirm secret retrieval and GeoAnalytics authorization.' }
    $Result = Invoke-NotebookJob -Manifest $Manifest -Parameters $Parameters
    $Expected = @('cells_daily','arrival','front_daily','grid_population_vulnerability','origin','vulnerability_summary')
    if ($Result.run_id -ne $RunId -or $Result.outputs -isnot [hashtable] -or $Result.outputs.Count -ne $Expected.Count) {
        throw 'Notebook exit value did not match the requested run and output contract.'
    }
    foreach ($Name in $Expected) {
        if (-not $Result.outputs.ContainsKey($Name) -or -not $Result.outputs[$Name].table -or
            -not $Result.outputs[$Name].ContainsKey('rows')) { throw "Notebook did not verify expected output: $Name" }
    }
    $Manifest.lastResult = $Result
    Save-DeploymentManifest $Manifest
    $Result | ConvertTo-Json -Depth 20 | Out-Host
    Write-Host "Workspace: https://app.fabric.microsoft.com/groups/$($Manifest.workspaceId)"
    Write-Host "Notebook: $($Manifest.notebookId); Lakehouse: $($Manifest.lakehouseId); Job: $($Manifest.lastJobUri)"
}

function Publish-ResultsNotebook {
    <#
    .SYNOPSIS
        Publishes only the owned results viewer without submitting a Spark job.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Manifest = Read-DeploymentManifest $Config
    if ($Manifest.stage -ne 'Configured') { throw 'Finish deployment before viewing results.' }
    if ($Manifest.lastPreviewJobUri) {
        $Previous = (Invoke-ServiceRequest -Uri $Manifest.lastPreviewJobUri).Data
        if ($Previous.status -notin @('Completed','Failed','Cancelled','Deduped')) {
            throw "A preview job may still be active. Inspect it before resubmitting: $($Manifest.lastPreviewJobUri)"
        }
    }
    $Status = Get-DeploymentStatus $Config
    $Notebook = New-ResultsNotebook -Manifest $Manifest -LakehouseName $Status.Lakehouse.name
    $Json = $Notebook | ConvertTo-Json -Depth 100
    $Definition = @{
        format='ipynb'
        parts=@(@{path='artifact.content.ipynb';payloadType='InlineBase64';payload=[Convert]::ToBase64String([text.encoding]::UTF8.GetBytes($Json))})
    }
    $Item = Get-OrCreateFabricItem -WorkspaceId $Manifest.workspaceId -Name "$($Manifest.deploymentName) Results" `
        -Type Notebook -Owner "fabric-zombie-outbreak:$($Manifest.deploymentName)" -Definition $Definition
    if ($Manifest.resultsNotebookId -and $Manifest.resultsNotebookId -ne $Item.id) {
        throw 'Results notebook identity differs from recorded state. Inspect the workspace before updating.'
    }
    $Manifest.resultsNotebookId = $Item.id
    if (-not $Manifest.resources.ContainsKey('ResultsNotebook')) { $Manifest.resources.ResultsNotebook = $Item }
    Save-DeploymentManifest $Manifest
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)"
    if (-not $Item.created) {
        $null = Wait-FabricOperation -NoResult (Invoke-ServiceRequest -Uri "$Base/items/$($Item.id)/updateDefinition" -Method POST -Body @{definition=$Definition})
    }
    $Saved = Wait-FabricOperation (Invoke-ServiceRequest -Uri "$Base/notebooks/$($Item.id)/getDefinition?format=ipynb" -Method POST)
    $Parts = @($Saved.definition.parts | Where-Object { $_.path -like '*.ipynb' -and $_.payloadType -eq 'InlineBase64' })
    if ($Parts.Count -ne 1) { throw 'Cannot verify the saved results notebook definition.' }
    $Actual = [text.encoding]::UTF8.GetString([Convert]::FromBase64String($Parts[0].payload)) | ConvertFrom-Json -AsHashtable -Depth 100
    $ActualSource = ($Actual.cells[1].source -join '') -replace "`r`n", "`n"
    $ExpectedSource = $Notebook.cells[1].source -replace "`r`n", "`n"
    if ($Actual.cells.Count -ne 2 -or $ActualSource -cne $ExpectedSource -or
        $Actual.metadata.dependencies.lakehouse.default_lakehouse -ne $Manifest.lakehouseId -or
        $Actual.metadata.dependencies.lakehouse.default_lakehouse_workspace_id -ne $Manifest.workspaceId -or
        $Actual.metadata.dependencies.environment.environmentId -ne $Manifest.environmentId -or
        $Actual.metadata.dependencies.environment.workspaceId -ne $Manifest.workspaceId) {
        throw 'Saved results notebook source or bindings differ. No Spark job was submitted.'
    }
    Write-Host "Results source and bindings verified for run $($Manifest.lastResult.run_id). No Spark job submitted."
    Write-Host "Results notebook: https://app.fabric.microsoft.com/groups/$($Manifest.workspaceId)/synapsenotebooks/$($Item.id)"
    Write-Host 'Open Results, then select Run all in Fabric after paid-compute approval. View the map there; do not rerun the simulation.'
}

function Get-DeploymentStatus {
    <#
    .SYNOPSIS
        Reads deployed item and last job state. Does not execute a notebook.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Manifest = Read-DeploymentManifest $Config
    $Result = @{stage=$Manifest.stage;workspaceId=$Manifest.workspaceId;capacityId=$Manifest.capacityId}
    if (-not $Manifest.workspaceId) { throw 'Manifest has no workspace yet. Rerun deploy to resume.' }
    $Base = "https://api.fabric.microsoft.com/v1/workspaces/$($Manifest.workspaceId)"
    $Workspace = (Invoke-ServiceRequest -Uri $Base).Data
    if ($Workspace.capacityId -ne $Manifest.capacityId) { throw 'Workspace capacity differs from manifest.' }
    $Capacity = Get-ActiveFabricCapacity -Capacities @(Get-ServiceCollection 'https://api.fabric.microsoft.com/v1/capacities') -CapacityId $Manifest.capacityId
    $Result.capacityState = $Capacity.state
    $Endpoint = Get-KeyVaultManagedPrivateEndpoint -Manifest $Manifest
    $Result.managedPrivateEndpoint = $Endpoint
    $Result.managedPrivateEndpointReady = [bool]($Endpoint -and $Endpoint.provisioningState -eq 'Succeeded' -and $Endpoint.approvalState -eq 'Approved')
    if (-not $Endpoint) { $Result.managedPrivateEndpointMessage = 'Expected endpoint not found. Configure-network requires explicit approval before creation.' }
    foreach ($Type in @('Lakehouse','Environment','Notebook')) {
        $Id = $Manifest["$($Type.ToLowerInvariant())Id"]
        if (-not $Id) {
            if (-not $Result.managedPrivateEndpointReady) {
                $Result.fabricItemsVerified = $false
                $Result.nextAction = "Deployment has no $Type yet. Resolve the managed endpoint checkpoint before finishing Fabric."
                return $Result
            }
            throw "Deployment has no $Type yet. Rerun deploy to resume."
        }
        $Item = (Invoke-ServiceRequest -Uri "$Base/items/$Id").Data
        if ($Item.type -ne $Type -or $Item.description -ne "fabric-zombie-outbreak:$($Config.deploymentName)") { throw "$Type ownership/type mismatch." }
        $Result[$Type] = @{id=$Item.id;name=$Item.displayName}
    }
    $Compute = (Invoke-ServiceRequest -Uri "$Base/environments/$($Manifest.environmentId)/sparkcompute?beta=false").Data
    if ($Compute.runtimeVersion -ne '1.3' -or
        -not @($Compute.sparkProperties | Where-Object { $_.key -eq 'spark.native.enabled' -and $_.value -eq 'false' }).Count) {
        throw 'Published environment does not match Runtime 1.3 / Native Execution Engine disabled.'
    }
    $Result.runtimeVersion = $Compute.runtimeVersion
    $Definition = Wait-FabricOperation (Invoke-ServiceRequest -Uri "$Base/notebooks/$($Manifest.notebookId)/getDefinition?format=ipynb" -Method POST)
    $Parts = @($Definition.definition.parts | Where-Object { $_.path -like '*.ipynb' -and $_.payloadType -eq 'InlineBase64' })
    if ($Parts.Count -ne 1) { throw 'Deployed notebook definition did not contain one ipynb payload.' }
    $Notebook = [text.encoding]::UTF8.GetString([Convert]::FromBase64String($Parts[0].payload)) | ConvertFrom-Json -AsHashtable -Depth 100
    if ($Notebook.metadata.dependencies.lakehouse.default_lakehouse -ne $Manifest.lakehouseId -or
        $Notebook.metadata.dependencies.lakehouse.default_lakehouse_workspace_id -ne $Manifest.workspaceId -or
        $Notebook.metadata.dependencies.environment.environmentId -ne $Manifest.environmentId -or
        @($Notebook.cells | Where-Object { 'parameters' -in $_.metadata.tags }).Count -ne 1) {
        throw 'Deployed notebook bindings or parameter metadata do not match the manifest.'
    }
    $Result.notebookBindingsVerified = $true
    if ($Manifest.lastJobUri) { $Result.lastJob = (Invoke-ServiceRequest -Uri $Manifest.lastJobUri).Data }
    if ($Manifest.lastResult) { $Result.lastVerifiedOutputs = $Manifest.lastResult }
    if ($Manifest.resultsNotebookId) {
        $Item = (Invoke-ServiceRequest -Uri "$Base/items/$($Manifest.resultsNotebookId)").Data
        if ($Item.type -ne 'Notebook' -or $Item.description -ne "fabric-zombie-outbreak:$($Config.deploymentName)") {
            throw 'Results notebook ownership/type mismatch.'
        }
        $Result.ResultsNotebook = @{id=$Item.id;name=$Item.displayName}
    }
    if ($Manifest.lastPreviewJobUri) { $Result.lastPreviewJob = (Invoke-ServiceRequest -Uri $Manifest.lastPreviewJobUri).Data }
    if ($Manifest.lastPreviewResult) { $Result.lastSpatialPreview = $Manifest.lastPreviewResult }
    return $Result
}
#endregion
