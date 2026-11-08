# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Accelerator.psm1
# Purpose: Shared read-only checks and lifecycle operations for interactive users.
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:StateDirectory = Join-Path $script:Root 'deploy\state'

#region Configuration and HTTP
function Invoke-AzJson {
    <#
    .SYNOPSIS
        Runs Azure CLI without emitting tokens or passing secret values.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param([Parameter(Mandatory)][string[]]$Arguments)
    $Text = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI failed ($($Arguments[0])). Check authentication and permissions." }
    if ($Text) { return ($Text -join "`n" | ConvertFrom-Json -AsHashtable -Depth 100) }
}

function Read-CustomerConfig {
    <#
    .SYNOPSIS
        Loads and rejects incomplete or unexpected nonsecret configuration.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string]$Path)
    $Config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    $Fields = @('deploymentName','subscriptionId','tenantId','resourceGroupName','location','keyVaultName',
        'workspaceName','lakehouseName','environmentName','notebookName','capacity','confirmations')
    foreach ($Key in $Config.Keys) { if ($Key -notin $Fields) { throw "Unknown configuration field: $Key. Secrets are not accepted." } }
    foreach ($Key in $Fields) {
        if (-not $Config.ContainsKey($Key) -or $null -eq $Config[$Key] -or $Config[$Key] -ceq '') {
            throw "Required configuration field: $Key"
        }
    }
    foreach ($Key in @('subscriptionId','tenantId')) {
        if (-not [guid]::TryParse($Config[$Key], [ref]([guid]::Empty)) -or $Config[$Key] -eq [guid]::Empty.ToString()) {
            throw "Set $Key to a nonempty GUID."
        }
    }
    if ($Config.deploymentName -notmatch '^[a-z][a-z0-9-]{2,40}$') { throw 'Invalid deploymentName.' }
    if ($Config.resourceGroupName -notmatch '^[a-zA-Z0-9_-]{1,90}$') { throw 'Invalid resourceGroupName.' }
    if ($Config.location -notmatch '^[a-z0-9]+$') { throw 'Use an Azure region name such as centralus.' }
    if ($Config.keyVaultName -notmatch '^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$' -or $Config.keyVaultName -match '--') {
        throw 'Invalid keyVaultName: use 3-24 alphanumeric/hyphen characters without consecutive hyphens.'
    }
    foreach ($Key in @('workspaceName','environmentName','notebookName')) {
        if ($Config[$Key] -isnot [string] -or $Config[$Key] -notmatch '^[a-zA-Z0-9 _-]{1,100}$') { throw "Invalid $Key." }
    }
    if ($Config.lakehouseName -notmatch '^[a-zA-Z][a-zA-Z0-9_]{0,99}$') { throw 'Invalid lakehouseName.' }
    if ($Config.capacity -isnot [hashtable] -or $Config.capacity.mode -notin @('existing','new')) {
        throw 'capacity.mode must be existing or new.'
    }
    foreach ($Key in $Config.capacity.Keys) {
        if ($Key -notin @('mode','id','name','sku','administrators')) { throw "Unknown capacity field: $Key" }
    }
    if ($Config.capacity.mode -eq 'existing') {
        $Id = [guid]::Empty
        if (-not [guid]::TryParse($Config.capacity.id, [ref]$Id) -or $Id -eq [guid]::Empty) { throw 'Existing capacity requires a Fabric capacity GUID.' }
    }
    elseif ($Config.capacity.name -notmatch '^[a-z][a-z0-9]{2,62}$' -or
        $Config.capacity.sku -notmatch '^F(2|4|8|16|32|64|128|256|512|1024|2048)$' -or
        @($Config.capacity.administrators).Count -eq 0) {
        throw 'New capacity requires a lowercase alphanumeric name, valid F SKU, and administrator UPNs.'
    }
    $Confirmations = @('geoAnalyticsEnabled','esriEntitlement','workspaceCreationAllowed','capacityAssignmentAllowed','azureDeploymentAllowed')
    if ($Config.confirmations -isnot [hashtable]) { throw 'confirmations must be a JSON object.' }
    foreach ($Key in $Config.confirmations.Keys) {
        if ($Key -notin $Confirmations) { throw "Unknown confirmation: $Key" }
    }
    foreach ($Key in $Confirmations) {
        if ($Config.confirmations[$Key] -isnot [bool]) { throw "Confirmation $Key must be a JSON boolean." }
    }
    return $Config
}

function Invoke-ServiceRequest {
    <#
    .SYNOPSIS
        Calls an allow-listed service and reports failures without response bodies.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet('GET','POST','PATCH','PUT')][string]$Method = 'GET',
        [object]$Body,
        [string]$Audience = 'https://api.fabric.microsoft.com'
    )
    $Parsed = [uri]$Uri
    if ($Parsed.Scheme -ne 'https' -or $Parsed.UserInfo -or
        ($Audience -eq 'https://api.fabric.microsoft.com' -and $Parsed.Host -ne 'api.fabric.microsoft.com') -or
        ($Audience -eq 'https://vault.azure.net' -and $Parsed.Host -notmatch '^[a-zA-Z0-9-]+\.vault\.azure\.net$') -or
        ($Audience -eq 'https://management.azure.com/' -and $Parsed.Host -ne 'management.azure.com')) {
        throw "Refusing to send credentials to an unexpected service URL (method=$Method, scheme=$($Parsed.Scheme), host=$($Parsed.Host)). URL credentials, path, and query are not logged."
    }
    for ($Attempt = 0; $Attempt -lt 5; $Attempt++) {
        $Token = Invoke-AzJson @('account','get-access-token','--resource',$Audience)
        $Request = @{
            Uri = $Uri; Method = $Method; Headers = @{Authorization = "Bearer $($Token.accessToken)"}
            SkipHttpErrorCheck = $true; TimeoutSec = 120
        }
        if ($null -ne $Body) { $Request.Body = $Body | ConvertTo-Json -Depth 100 -Compress; $Request.ContentType = 'application/json' }
        try { $Response = Invoke-WebRequest @Request }
        finally { $Request.Headers.Clear(); $Request.Remove('Body'); $Token = $null }
        if ([int]$Response.StatusCode -eq 429 -and $Attempt -lt 4) {
            $Delay = 30
            if ($Response.Headers['Retry-After']) { $Delay = [int]($Response.Headers['Retry-After'] | Select-Object -First 1) }
            Start-Sleep -Seconds ([Math]::Max(1, $Delay))
            continue
        }
        if ([int]$Response.StatusCode -ge 400) {
            throw "HTTP $([int]$Response.StatusCode) for $Method $($Parsed.AbsolutePath). Check service permissions, configuration, and Fabric activity diagnostics."
        }
        $Data = if ($Response.Content) { $Response.Content | ConvertFrom-Json -AsHashtable -Depth 100 } else { $null }
        return @{ StatusCode = [int]$Response.StatusCode; Headers = $Response.Headers; Data = $Data }
    }
}

function Get-ServiceCollection {
    <#
    .SYNOPSIS
        Follows Fabric continuation pages with loop protection.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][string]$Uri)
    $Seen = [System.Collections.Generic.HashSet[string]]::new()
    while ($Uri) {
        if (-not $Seen.Add($Uri)) { throw 'Service returned a repeated continuation URI.' }
        $Page = (Invoke-ServiceRequest -Uri $Uri).Data
        if (-not $Page.ContainsKey('value')) { throw 'Expected a service collection with a value array.' }
        $Page.value | Write-Output
        $Uri = $Page.continuationUri
    }
}

function Get-ActiveFabricCapacity {
    <#
    .SYNOPSIS
        Verifies the selected capacity without changing its lifecycle.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Capacities, [Parameter(Mandatory)][string]$CapacityId)
    $Matches = @($Capacities | Where-Object id -eq $CapacityId)
    if ($Matches.Count -ne 1) { throw "Selected Fabric capacity $CapacityId is not uniquely visible to this user." }
    $Capacity = $Matches[0]
    if ($Capacity.state -ne 'Active') {
        throw "Fabric capacity '$($Capacity.displayName)' ($CapacityId) is not active (state=$($Capacity.state)). Ask its owner to resume it in Azure, then retry status. Resuming incurs charges; do not recreate Fabric assets."
    }
    if ($Capacity.sku -notmatch '^F\d+$') { throw 'Selected Fabric capacity must use a supported F SKU.' }
    return $Capacity
}

function Resolve-FabricOperationUri {
    <#
    .SYNOPSIS
        Resolves operation locations against the Fabric API without accepting another origin.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Location)
    $Resolved = $null
    if ([string]::IsNullOrWhiteSpace($Location) -or
        -not [uri]::TryCreate([uri]'https://api.fabric.microsoft.com/', $Location, [ref]$Resolved)) {
        throw 'Fabric operation returned an invalid Location. Inspect the operation before retrying.'
    }
    if ($Resolved.Scheme -ne 'https' -or $Resolved.Host -ne 'api.fabric.microsoft.com' -or
        $Resolved.UserInfo -or $Resolved.Port -ne 443 -or $Resolved.Fragment) {
        throw "Refusing an unexpected Fabric operation URL (scheme=$($Resolved.Scheme), host=$($Resolved.Host), port=$($Resolved.Port)). URL credentials, path, and query are not logged."
    }
    return $Resolved.AbsoluteUri
}

function Wait-FabricOperation {
    <#
    .SYNOPSIS
        Waits for Fabric long-running operations, including create result retrieval.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param([Parameter(Mandatory)][hashtable]$Response, [int]$TimeoutSeconds = 1800, [switch]$NoResult)
    if ($Response.StatusCode -ne 202) { return $Response.Data }
    $OperationId = [string]($Response.Headers['x-ms-operation-id'] | Select-Object -First 1)
    if ($OperationId) {
        $Id = [guid]::Empty
        if (-not [guid]::TryParse($OperationId, [ref]$Id) -or $Id -eq [guid]::Empty) {
            throw 'Fabric operation returned an invalid x-ms-operation-id. Inspect the submitted operation before retrying.'
        }
        $Uri = "https://api.fabric.microsoft.com/v1/operations/$Id"
    } else {
        $Location = [string]($Response.Headers['Location'] | Select-Object -First 1)
        if (-not $Location) { throw 'Asynchronous operation did not return Location or x-ms-operation-id. Inspect the submitted operation before retrying.' }
        $Uri = Resolve-FabricOperationUri -Location $Location
    }
    $Deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $Delay = 10
        if ($Response.Headers['Retry-After']) { $Delay = [int]($Response.Headers['Retry-After'] | Select-Object -First 1) }
        if ([datetime]::UtcNow.AddSeconds($Delay) -gt $Deadline) { throw "Fabric operation timed out: $Uri. It may still be running." }
        Start-Sleep -Seconds ([Math]::Max(1, $Delay))
        $Response = Invoke-ServiceRequest -Uri $Uri
        $State = $Response.Data.status
        Write-Host "[Fabric operation] $State"
        if ($State -in @('Failed','Cancelled')) { throw "Fabric operation $State. Inspect operation $Uri." }
        if ($State -notin @('NotStarted','Running','Succeeded')) { throw "Unexpected Fabric operation state: $State" }
    } while ($State -ne 'Succeeded')
    if ($NoResult) { return }
    return (Invoke-ServiceRequest -Uri "$($Uri.TrimEnd('/'))/result").Data
}
#endregion

#region Read-only validation
function Test-Prerequisite {
    <#
    .SYNOPSIS
        Returns structured read-only prerequisite results without provisioning.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][hashtable]$Config)
    $Checks = [System.Collections.Generic.List[object]]::new()
    $Add = { param($Name,$Status,$Detail) $Checks.Add([pscustomobject]@{Check=$Name;Status=$Status;Detail=$Detail}) }
    & $Add 'PowerShell' $(if ($PSVersionTable.PSVersion.Major -ge 7) {'Pass'} else {'Fail'}) "$($PSVersionTable.PSVersion)"
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        & $Add 'Azure CLI' 'Fail' 'Install Azure CLI.'
        return $Checks.ToArray()
    }
    & $Add 'Azure CLI' 'Pass' 'Command is available.'
    try {
        $Version = & az bicep version --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw 'Bicep unavailable. Run az bicep install.' }
        & $Add 'Bicep' 'Pass' 'Azure CLI managed Bicep is available.'
    } catch { & $Add 'Bicep' 'Fail' $_.Exception.Message }
    foreach ($File in @('deploy\main.bicep','deploy\fabric\environment\spark-compute.json',
        'deploy\fabric\notebook\bootstrap.txt','deploy\fabric\notebook\delta-output.txt','Zombie_Outbreak_Spread.ipynb')) {
        & $Add "Definition: $File" $(if (Test-Path -LiteralPath (Join-Path $script:Root $File)) {'Pass'} else {'Fail'}) 'Required local definition.'
    }
    try {
        $null = New-DeployableNotebook -WorkspaceId '11111111-1111-1111-1111-111111111111' `
            -LakehouseId '22222222-2222-2222-2222-222222222222' -EnvironmentId '33333333-3333-3333-3333-333333333333' `
            -LakehouseName $Config.lakehouseName -KeyVaultUri "https://$($Config.keyVaultName).vault.azure.net/"
        & $Add 'Notebook structure' 'Pass' 'Separate notebook generated; parameter metadata and secret/publishing boundaries checked.'
    } catch { & $Add 'Notebook structure' 'Fail' $_.Exception.Message }
    try {
        $Account = Invoke-AzJson @('account','show')
        if ($Account.id -ne $Config.subscriptionId -or $Account.tenantId -ne $Config.tenantId) { throw 'Active subscription/tenant differs from configuration. Select it with az account set before continuing.' }
        if ($Account.user.type -ne 'user') { throw 'This POC supports an interactive user only. Sign in with az login.' }
        & $Add 'Azure authentication' 'Pass' "Interactive user on subscription $($Account.id)."
    } catch {
        & $Add 'Azure authentication' 'Fail' $_.Exception.Message
        return $Checks.ToArray()
    }
    $Providers = @('Microsoft.KeyVault', 'Microsoft.Network')
    if ($Config.capacity.mode -eq 'new') { $Providers += 'Microsoft.Fabric' }
    foreach ($Provider in $Providers) {
        try {
            $Registration = Invoke-AzJson @('provider','show','--namespace',$Provider,'--subscription',$Config.subscriptionId)
            if ($Registration.registrationState -ne 'Registered') { throw "Register $Provider manually; validate will not change provider registration." }
            if ($Provider -in @('Microsoft.KeyVault','Microsoft.Fabric')) {
                $ResourceType = if ($Provider -eq 'Microsoft.KeyVault') {'vaults'} else {'capacities'}
                $Type = $Registration.resourceTypes | Where-Object resourceType -eq $ResourceType
                $Location = $Config.location -replace '\s',''
                if ($Location -notin @($Type.locations | ForEach-Object { ($_ -replace '\s','').ToLowerInvariant() })) {
                    throw "Region $($Config.location) is not advertised for $Provider/$ResourceType."
                }
            }
            & $Add $Provider 'Pass' 'Provider registered; applicable Azure region checks passed.'
        } catch { & $Add $Provider 'Fail' $_.Exception.Message }
    }
    try {
        $GroupExists = Invoke-AzJson @('group','exists','--name',$Config.resourceGroupName,'--subscription',$Config.subscriptionId)
        if ($GroupExists) {
            $Group = Invoke-AzJson @('group','show','--name',$Config.resourceGroupName,'--subscription',$Config.subscriptionId)
            if ($Group.tags.accelerator -ne 'fabric-zombie-outbreak' -or $Group.tags.deployment -ne $Config.deploymentName -or
                $Group.location -ne $Config.location) { throw 'Existing resource group is unowned or has an incompatible location. Choose a new dedicated group.' }
            $Resources = @(Invoke-AzJson @('resource','list','--subscription',$Config.subscriptionId,'--resource-group',$Config.resourceGroupName))
            foreach ($Resource in $Resources) {
                if ($Resource.tags.accelerator -ne 'fabric-zombie-outbreak' -or $Resource.tags.deployment -ne $Config.deploymentName) {
                    throw "Resource group contains a resource not owned by this deployment: $($Resource.name). Use a dedicated group."
                }
            }
        }
        & $Add 'Azure resource conflicts' 'Pass' $(if ($GroupExists) {'Deployment-owned group; no unowned resources.'} else {'Dedicated group does not yet exist.'})
    } catch { & $Add 'Azure resource conflicts' 'Fail' $_.Exception.Message }
    try {
        $Vaults = @(Invoke-AzJson @('resource','list','--resource-type','Microsoft.KeyVault/vaults','--subscription',$Config.subscriptionId))
        $Vault = @($Vaults | Where-Object name -eq $Config.keyVaultName)
        if ($Vault.Count) {
            if ($Vault.Count -ne 1 -or $Vault[0].resourceGroup -ne $Config.resourceGroupName -or
                $Vault[0].tags.deployment -ne $Config.deploymentName -or $Vault[0].tags.accelerator -ne 'fabric-zombie-outbreak') {
                throw 'Existing Key Vault name is not owned by this deployment.'
            }
            $Details = Invoke-AzJson @('keyvault','show','--name',$Config.keyVaultName,'--subscription',$Config.subscriptionId)
            if (-not $Details.properties.enableRbacAuthorization -or $Details.properties.tenantId -ne $Config.tenantId -or
                $Details.location -ne $Config.location) { throw 'Existing vault has incompatible RBAC, tenant, or location.' }
            & $Add 'Key Vault name' 'Pass' 'Compatible deployment-owned vault.'
        } else {
            $Available = Invoke-AzJson @('keyvault','check-name','--name',$Config.keyVaultName,'--subscription',$Config.subscriptionId)
            if (-not $Available.nameAvailable) { throw "Key Vault name unavailable: $($Available.reason)" }
            & $Add 'Key Vault name' 'Pass' 'Name available; no vault created.'
        }
    } catch { & $Add 'Key Vault name' 'Fail' $_.Exception.Message }
    try {
        $Capacities = @(Get-ServiceCollection 'https://api.fabric.microsoft.com/v1/capacities')
        if ($Config.capacity.mode -eq 'existing') {
            $Capacity = Get-ActiveFabricCapacity -Capacities $Capacities -CapacityId $Config.capacity.id
            if (($Capacity.region -replace '\s','').ToLowerInvariant() -ne $Config.location) { throw 'Selected capacity region differs from configuration.' }
            & $Add 'Fabric capacity' 'Pass' "$($Capacity.displayName), $($Capacity.sku), Active. Headroom is not proven."
        } else {
            $Existing = @($Capacities | Where-Object displayName -eq $Config.capacity.name)
            if ($Existing.Count -gt 1) { throw 'Ambiguous new capacity name.' }
            $ArmCapacities = @(Invoke-AzJson @('resource','list','--resource-type','Microsoft.Fabric/capacities','--subscription',$Config.subscriptionId))
            foreach ($Capacity in @($ArmCapacities | Where-Object name -eq $Config.capacity.name)) {
                if ($Capacity.resourceGroup -ne $Config.resourceGroupName -or $Capacity.tags.deployment -ne $Config.deploymentName -or
                    $Capacity.tags.accelerator -ne 'fabric-zombie-outbreak' -or $Capacity.sku.name -ne $Config.capacity.sku) {
                    throw 'New capacity name conflicts with a customer capacity or incompatible SKU. It will not be modified.'
                }
            }
            if ($Existing.Count -and -not @($ArmCapacities | Where-Object name -eq $Config.capacity.name).Count) {
                throw 'Fabric capacity name is already in use outside the deployment resource scope.'
            }
            & $Add 'Fabric capacity' 'Pass' 'Explicit new-capacity mode; cost, quota, and regional SKU availability require what-if/deployment review.'
        }
        $Workspaces = @(Get-ServiceCollection 'https://api.fabric.microsoft.com/v1/workspaces')
        $Matches = @($Workspaces | Where-Object displayName -eq $Config.workspaceName)
        if ($Matches.Count -gt 1) { throw 'Duplicate workspace names found; choose a unique name.' }
        if ($Matches.Count) {
            if ($Matches[0].description -ne "fabric-zombie-outbreak:$($Config.deploymentName)") { throw 'Workspace exists but was not created by this deployment. It will not be changed.' }
            $User = Invoke-AzJson @('ad','signed-in-user','show')
            $Roles = @(Get-ServiceCollection "https://api.fabric.microsoft.com/v1/workspaces/$($Matches[0].id)/roleAssignments")
            if (-not @($Roles | Where-Object { $_.principal.id -eq $User.id -and $_.role -eq 'Admin' }).Count) {
                throw 'The interactive user must be workspace Admin.'
            }
            if ($Matches[0].capacityId -and $Config.capacity.mode -eq 'existing' -and $Matches[0].capacityId -ne $Config.capacity.id) {
                throw 'Workspace is already assigned to a different capacity.'
            }
            & $Add 'Fabric workspace' 'Pass' 'Deployment-owned workspace and current-user Admin role verified.'
        } else {
            & $Add 'Fabric workspace' 'Pass' 'No visible name conflict. Workspace creation permission still requires administrator confirmation.'
        }
        & $Add 'Fabric authentication' 'Pass' 'Capacity and workspace read APIs succeeded.'
    } catch { & $Add 'Fabric access' 'Fail' $_.Exception.Message }
    $Manual = @{
        geoAnalyticsEnabled = 'Administrator confirmed GeoAnalytics enabled for the selected tenant/capacity.'
        esriEntitlement = 'Customer confirmed an active Esri entitlement and available API key; never put the key in configuration.'
        workspaceCreationAllowed = 'Administrator confirmed permission to create a separate Fabric workspace.'
        capacityAssignmentAllowed = 'Administrator confirmed permission to assign workspaces to the selected capacity.'
        azureDeploymentAllowed = 'Customer confirmed resource deployment and roleAssignments/write at the target scope. ARM what-if is a separate check.'
    }
    foreach ($Key in $Manual.Keys | Sort-Object) {
        & $Add $Key $(if ($Config.confirmations[$Key]) {'Confirmed'} else {'Manual'}) `
            $(if ($Config.confirmations[$Key]) {$Manual[$Key]} else {"Manual prerequisite confirmation required: $($Manual[$Key])"})
    }
    return $Checks.ToArray()
}
#endregion

. (Join-Path $PSScriptRoot 'Notebook.ps1')
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
Export-ModuleMember -Function Read-CustomerConfig, Test-Prerequisite, Invoke-Deployment, Set-DeploymentNetwork, Set-GeoAnalyticsSecret, Test-GeoAnalyticsSecret, Invoke-Simulation, Publish-ResultsNotebook, Get-DeploymentStatus, New-DeployableNotebook, New-ResultsNotebook, New-PortalCustomerConfig
