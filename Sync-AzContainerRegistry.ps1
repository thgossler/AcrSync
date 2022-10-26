<#
.SYNOPSIS
This script synchronized repositories and tags from a source to a target 
Azure Container Registry. It also removes items from the target registry 
if they are not existing anymore in the source registry.

.DESCRIPTION
This script synchronized repositories and tags from a source to a target 
Azure Container Registry. It also removes items from the target registry 
if they are not existing anymore in the source registry.

The script always runs once immediately. If a scheduled job interval is
specified, then it runs repeatedly in that frequency.

Environment variables (only used when no parameters are specified):

ACRSYNC_CONTAINER_IMAGE_NAME_TAG (used to avoid deleting its own image)
ACRSYNC_TARGET_ACR_NAME
ACRSYNC_TARGET_ACR_RESOURCEGROUP_NAME
ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID
ACRSYNC_TARGET_CLOUDENV_NAME (default: AzureCloud)
ACRSYNC_TARGET_TENANT_ID
ACRSYNC_TARGET_KEYVAULT_NAME
ACRSYNC_TARGET_SP_CLIENT_ID
ACRSYNC_TARGET_SP_CLIENT_SECRET
ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTID_SECRET_NAME (default: ACRSYNC_TARGET_SP_CLIENT_ID)
ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTSECRET_SECRET_NAME (default: ACRSYNC_TARGET_SP_CLIENT_SECRET)
ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID (default: ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID)
ACRSYNC_SOURCE_CLOUDENV_NAME (default: ACRSYNC_TARGET_CLOUDENV_NAME)
ACRSYNC_SOURCE_TENANT_ID (default: ACRSYNC_TARGET_TENANT_ID)
ACRSYNC_SOURCE_ACR_SUBSCRIPTION_ID (default: ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID)
ACRSYNC_SOURCE_ACR_NAME
ACRSYNC_SCHEDULED_JOB_INTERVAL_MINUTES (default: `0`, i.e. no repetitions)
#>

#Requires -Version 7
#Requires -Modules Az.Accounts
#Requires -Modules Az.KeyVault
#Requires -Modules Az.ContainerRegistry

param(
    [string]$TargetAcrName,
    [string]$TargetAcrResourceGroup,
    [string]$TargetAcrSubscriptionId,
    [string]$TargetAcrTenantId,
    [string]$TargetAcrCloudEnv = 'AzureCloud',
    [string]$TargetAcrKeyVaultName,
    [string]$TargetAcrSpClientId,
    [string]$TargetAcrSpClientSecret,
    [string]$TargetAcrKeyVaultSourceAcrSpClientIdSecretName = 'same',
    [string]$TargetAcrKeyVaultSourceAcrSpClientSecretSecretName = 'same',
    [string]$TargetAcrKeyVaultSubscriptionId = $TargetAcrSubscriptionId,
    [string]$SourceAcrCloudEnv = $TargetAcrCloudEnv,
    [string]$SourceAcrTenantId = $TargetAcrTenantId,
    [string]$SourceAcrSubscriptionId = $TargetAcrSubscriptionId,
    [string]$SourceAcrName,
    [int]$ScheduledJobIntervalMinutes = 0
)

Import-Module -Name Az.Accounts
Import-Module -Name Az.KeyVault
Import-Module -Name Az.ContainerRegistry

$Error.Clear()
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

# Ensure docker executable is found (required for Connect-AzContainerRegistry)
$IsDockerAvailable = @((Get-Command docker))
If (!$IsDockerAvailable) {
    Write-Error "This script cannot run in this environment because docker is not available!"
    return
}

function EnsureAndGetEnvironmentVariable([string]$Name, $DefaultValue = $null) {
    if ([string]::IsNullOrEmpty($Name)) { Write-Error "Name argument is required" }
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { 
        if ([string]::IsNullOrEmpty($DefaultValue)) {
            Write-Error "'$Name' environment variable is not defined"
            return $null
        }
        Write-Output "Using default value for environment variable: $($Name)=$($Name -ilike '*SECRET' ? '***' : $DefaultValue)" | Out-Default
        $value = $DefaultValue
    }
    return $value
}

function EnsureParameterValue([string]$ParameterName) {
    if ([string]::IsNullOrEmpty((Get-Variable -Name $ParameterName -ValueOnly))) { 
        Write-Error "Parameter '$ParameterName' is required" 
    }
}

$numOfBoundParameters = $PSBoundParameters.Count
if ($numOfBoundParameters -eq 0) {
    # Get input parameters from environment variables
    $TargetAcrName = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_ACR_NAME'
    $TargetAcrResourceGroup = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_ACR_RESOURCEGROUP_NAME'
    $TargetAcrSubscriptionId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID'
    $TargetAcrTenantId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_TENANT_ID'
    $TargetAcrCloudEnv = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_CLOUDENV_NAME' -DefaultValue 'AzureCloud'
    $TargetAcrKeyVaultName = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_KEYVAULT_NAME'
    $TargetAcrSpClientId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_SP_CLIENT_ID'
    $TargetAcrSpClientSecret = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_SP_CLIENT_SECRET'
    $TargetAcrKeyVaultSourceAcrSpClientIdSecretName = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTID_SECRET_NAME' -DefaultValue 'same'
    $TargetAcrKeyVaultSourceAcrSpClientSecretSecretName = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTSECRET_SECRET_NAME' -DefaultValue 'same'
    $TargetAcrKeyVaultSubscriptionId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID' -DefaultValue $TargetAcrSubscriptionId

    $SourceAcrCloudEnv = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_SOURCE_CLOUDENV_NAME' -DefaultValue $TargetAcrCloudEnv
    $SourceAcrTenantId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_SOURCE_TENANT_ID' -DefaultValue $TargetAcrTenantId
    $SourceAcrSubscriptionId = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_SOURCE_ACR_SUBSCRIPTION_ID' -DefaultValue $TargetAcrSubscriptionId
    $SourceAcrName = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_SOURCE_ACR_NAME'

    $ScheduledJobIntervalMinutes = EnsureAndGetEnvironmentVariable -Name 'ACRSYNC_SCHEDULED_JOB_INTERVAL_MINUTES' -DefaultValue 0
}
else {
    # Ensure all parameters are specified
    EnsureParameterValue -ParameterName TargetAcrName
    EnsureParameterValue -ParameterName TargetAcrSubscriptionId
    EnsureParameterValue -ParameterName TargetAcrTenantId
    EnsureParameterValue -ParameterName TargetAcrCloudEnv
    EnsureParameterValue -ParameterName TargetAcrKeyVaultName
    EnsureParameterValue -ParameterName TargetAcrSpClientId
    EnsureParameterValue -ParameterName TargetAcrSpClientSecret
    EnsureParameterValue -ParameterName TargetAcrKeyVaultSourceAcrSpClientIdSecretName
    EnsureParameterValue -ParameterName TargetAcrKeyVaultSourceAcrSpClientSecretSecretName
    EnsureParameterValue -ParameterName TargetAcrKeyVaultSubscriptionId

    EnsureParameterValue -ParameterName SourceAcrCloudEnv
    EnsureParameterValue -ParameterName SourceAcrTenantId
    EnsureParameterValue -ParameterName SourceAcrSubscriptionId
    EnsureParameterValue -ParameterName SourceAcrName
}

$SourceAcrUri = "$SourceAcrName.$((Get-AzEnvironment -Name $SourceAcrCloudEnv).ContainerRegistryEndpointSuffix)"

if ($ScheduledJobIntervalMinutes -lt 0 -or $ScheduledJobIntervalMinutes -gt (365*24*60)) {
    Write-Error "Invalid ScheduledJobIntervalMinutes specified (0 .. 1 year)"
    return
}

function Connect-AzAccount-Ext([string]$CloudEnv, [string]$TenantId, [PSCredential]$ServicePrinipalCredentials = $null, [string]$SubscriptionId = $null) {
    if ([string]::IsNullOrEmpty($CloudEnv)) { throw [System.ApplicationException]::new("CloudEnv argument is required")}
    if ([string]::IsNullOrEmpty($TenantId)) { throw [System.ApplicationException]::new("TenantId argument is required")}
    $loginSccessful = $false
    if ($null -eq $ServicePrinipalCredentials) {
        Write-Output "Signing-in with managed identity ($CloudEnv, TenantId=$TenantId)..."
        if (Connect-AzAccount -Environment $CloudEnv -TenantId $TenantId -Identity -Subscription $SubscriptionId -ErrorAction SilentlyContinue) {
            $loginSccessful = $true
        }
        else {
            Write-Output "Sign-in with managed identity failed ($CloudEnv, TenantId=$TenantId)"
            Write-Output "Trying to get service principal credentials from environment variables..."
            $ServicePrinipalCredentials = (New-Object System.Management.Automation.PSCredential $TargetAcrSpClientId, (ConvertTo-SecureString -String $TargetAcrSpClientSecret -AsPlainText))
        }
    }
    if ($loginSccessful -ne $true -and $null -ne $ServicePrinipalCredentials) {
        Write-Output "Signing-in with service principal ($CloudEnv, TenantId=$TenantId)..."
        if (Connect-AzAccount -Environment $CloudEnv -TenantId $TenantId -ServicePrincipal -Credential $ServicePrinipalCredentials -Subscription $SubscriptionId) {
            $loginSccessful = $true
        }
        else {
            Write-Error "Sign-in with service principal failed ($CloudEnv, TenantId=$TenantId)"
        }
    }
    return $loginSccessful
}

do {
    $stopWatch = [System.Diagnostics.Stopwatch]::new()
    $stopWatch.Start()

    # Get all required credentials
    if (!(Connect-AzAccount-Ext -CloudEnv $TargetAcrCloudEnv -TenantId $TargetAcrTenantId -SubscriptionId $TargetAcrKeyVaultSubscriptionId)) {
        return
    }
    Write-Output "Getting required secrets..."
    $sourceAcrSpClientId = $TargetAcrSpClientId
    if ($TargetAcrKeyVaultSourceAcrSpClientIdSecretName -ine 'same') {
        $sourceAcrSpClientId = Get-AzKeyVaultSecret -VaultName $TargetAcrKeyVaultName -Name $TargetAcrKeyVaultSourceAcrSpClientIdSecretName -AsPlainText
    }
    if ([string]::IsNullOrEmpty($sourceAcrSpClientId)) {
        Write-Error "Source registry service principal client ID could not be retrieved from target key vault"
        return
    }
    $sourceAcrSpClientSecret = ConvertTo-SecureString -String $TargetAcrSpClientSecret -AsPlainText
    if ($TargetAcrKeyVaultSourceAcrSpClientSecretSecretName -ne 'same') {
        $sourceAcrSpClientSecret = Get-AzKeyVaultSecret -VaultName $TargetAcrKeyVaultName -Name $TargetAcrKeyVaultSourceAcrSpClientSecretSecretName
    }
    if (!$sourceAcrSpClientSecret) {
        Write-Error "Source registry service principal client secret could not be retrieved from target key vault"
        return
    }
    $sourceAcrSpCredentials = (New-Object System.Management.Automation.PSCredential $sourceAcrSpClientId, $sourceAcrSpClientSecret.SecretValue)

    # Get list of container repos and tags from source registry
    if (!(Connect-AzAccount-Ext -CloudEnv $SourceAcrCloudEnv -TenantId $SourceAcrTenantId -ServicePrinipalCredentials $sourceAcrSpCredentials -SubscriptionId $SourceAcrSubscriptionId)) {
        return
    }
    Write-Output "Get list of container repos and tags from source registry..."
    if (!(Connect-AzContainerRegistry -Name $SourceAcrName -UserName $sourceAcrSpClientId -Password (ConvertFrom-SecureString -SecureString $sourceAcrSpClientSecret.SecretValue -AsPlainText) -ErrorAction SilentlyContinue)) {
        Write-Error "Connection to source registry failed"
        return
    }

    $stopWatch2 = [System.Diagnostics.Stopwatch]::new()
    $stopWatch2.Start()

    $sourceRepos = Get-AzContainerRegistryRepository -RegistryName $SourceAcrName
    $sourceRepoTagMap = [System.Collections.Hashtable]@{}
    foreach ($repo in $sourceRepos) {
        $tagList = Get-AzContainerRegistryTag -RegistryName $SourceAcrName -RepositoryName $repo
        $sourceRepoTagMap.Add($repo, $tagList.Tags)
    }

    $stopWatch2.Stop()
    $duration = $stopWatch2.Elapsed
    Write-Output "--> duration: $($duration.ToString('mm\:ss'))"
    $stopWatch2 = $null

    # Get list of container repos and tags from target registry
    if (!(Connect-AzAccount-Ext -CloudEnv $TargetAcrCloudEnv -TenantId $TargetAcrTenantId -SubscriptionId $TargetAcrSubscriptionId)) {
        return
    }
    Write-Output "Get list of container repos and tags from target registry..."

    $stopWatch2 = [System.Diagnostics.Stopwatch]::new()
    $stopWatch2.Start()

    $targetRepos = Get-AzContainerRegistryRepository -RegistryName $TargetAcrName
    $targetRepoTagMap = [System.Collections.Hashtable]@{}
    foreach ($repo in $targetRepos) {
        $tagList = Get-AzContainerRegistryTag -RegistryName $TargetAcrName -RepositoryName $repo
        $targetRepoTagMap.Add($repo, $tagList.Tags)
    }

    $stopWatch2.Stop()
    $duration = $stopWatch2.Elapsed
    Write-Output "--> duration: $($duration.ToString('mm\:ss'))"
    $stopWatch2 = $null

    # Import all container images and tags from source ACR into target ACR
    Write-Output "Import all repos and tags into target registry..."

    $stopWatch2 = [System.Diagnostics.Stopwatch]::new()
    $stopWatch2.Start()

    foreach ($repoName in ($sourceRepoTagMap.Keys | Sort-Object)) {
        $tags = $sourceRepoTagMap[$repoName]
        Write-Output "    Processing source repo '$repoName'..."
        foreach ($tag in $tags) {
            Write-Output "        Processing source tag '$($tag.Name)'..."

            # only import if tag doesn't exist
            if (@($targetRepoTagMap.Keys) -inotcontains $repoName -or @($targetRepoTagMap[$repoName].Name) -inotcontains $tag.Name) {
                $stopWatch3 = [System.Diagnostics.Stopwatch]::new()
                $stopWatch3.Start()
                
                if (!(Import-AzContainerRegistryImage -ResourceGroupName $TargetAcrResourceGroup -RegistryName $TargetAcrName `
                    -SourceRegistryUri $SourceAcrUri -Mode Force -Username $TargetAcrKeyVaultSourceAcrSpClientIdSecretName -Password (ConvertFrom-SecureString -SecureString $sourceAcrSpClientSecret) `
                    -SourceImage "$($repoName):$($tag.Name)" -ErrorAction Continue))
                {
                    Write-Output "            --> failed!"
                }

                $stopWatch3.Stop()
                $duration = $stopWatch3.Elapsed
                Write-Output "            duration: $($duration.ToString('mm\:ss'))"
                $stopWatch3 = $null
            }
            else {
                Write-Output "            --> already exists in target registry"
            }
        }
    }

    $stopWatch2.Stop()
    $duration = $stopWatch2.Elapsed
    Write-Output "--> duration: $($duration.ToString('mm\:ss'))"
    $stopWatch2 = $null

    # Remove all tags and repos from target registry which are not existing anymore in source registry
    Write-Output "Remove tags and repos from target registry not existing in source registry..."
    $stopWatch2 = [System.Diagnostics.Stopwatch]::new()
    $stopWatch2.Start()

    $acrSyncRepoName = $env:ACRSYNC_CONTAINER_IMAGE_NAME_TAG
    if ($acrSyncRepoName) { $acrSyncRepoName.Split(':')[0] }

    foreach ($repoName in ($targetRepoTagMap.Keys | Sort-Object)) {
        # Don't remove our own image if it should be in the target registry but not the source registry
        if ($repoName -ieq $acrSyncRepoName) { continue }

        $tags = $targetRepoTagMap[$repoName]
        Write-Output "    Processing target repo '$repoName'..."
        # remove repo from target registry if doesn't exist in source registry
        if (@($sourceRepoTagMap.Keys) -inotcontains $repoName) {
            Write-Output "        Removing not existing source repo from target registry..."
            if (!(Remove-AzContainerRegistryRepository -RegistryName $TargetAcrName -Name $repoName -ErrorAction Continue)) {
                Write-Output "            --> failed!"
            }
        }
        else {
            foreach ($tag in $tags) {
                Write-Output "        Processing target tag '$($tag.Name)'..."
                # remove image with tag from target registry if doesn't exist in source registry
                if (@($sourceRepoTagMap[$repoName].Name) -inotcontains $tag.Name) {
                    Write-Output "            Removing not existing source tag from target registry..."
                    if (!(Remove-AzContainerRegistryTag -RegistryName $TargetAcrName -RepositoryName $repoName -Name $tag.Name -ErrorAction Continue)) {
                        Write-Output "            --> failed!"
                    }
                }
            }
        }
    }
    $stopWatch2.Stop()
    $duration = $stopWatch2.Elapsed
    Write-Output "    Duration for synching removed source tags and repos: $($duration.ToString('mm\:ss'))"
    $stopWatch2 = $null

    $stopWatch.Stop()
    $overallDuration = $stopWatch.Elapsed
    Write-Output "Overall duration: $($overallDuration.ToString('hh\:mm\:ss'))"
    $stopWatch = $null

    # Clean-up memory
    $targetRepos = $null
    $targetRepoTagMap = $null
    $sourceRepos = $null
    $sourceRepoTagMap = $null
    $tags = $null
    $tagList = $null

    Write-Output "Finished."

    # Wait until the specified time interval has elapsed
    if ($ScheduledJobIntervalMinutes -gt 0) {
        $timespan = [TimeSpan]::FromMinutes($ScheduledJobIntervalMinutes)
        Write-Output "$([Environment]::NewLine)$((Get-Date)) - Next execution in $($timespan.ToString('dd\.hh\:mm\:ss')). Sleeping..."
        Start-Sleep -Seconds $timespan.TotalSeconds
        Write-Output "$([Environment]::NewLine)$((Get-Date)) - Next execution is due now"
    }

} while ($ScheduledJobIntervalMinutes -gt 0)
