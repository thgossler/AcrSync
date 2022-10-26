param (
    [string]$CloudEnv,
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$Location,
    [string]$ResourceGroup,
    [string]$AcrName,
    [string]$ServicePrincipalClientId,
    [securestring]$ServicePrincipalClientSecret,
    [string]$ContainerGroupName,
    [string]$ImageNameTag
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($CloudEnv)) { 
    $CloudEnv = $env:ACRSYNC_TARGET_CLOUDENV_NAME
    if ([string]::IsNullOrEmpty($CloudEnv)) { Write-Error "CloudEnv parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($TenantId)) { 
    $TenantId = $env:ACRSYNC_TARGET_TENANT_ID
    if ([string]::IsNullOrEmpty($TenantId)) { Write-Error "TenantId parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($SubscriptionId)) { 
    $SubscriptionId = $env:ACRSYNC_TARGET_ACI_SUBSCRIPTION_ID
    if ([string]::IsNullOrEmpty($SubscriptionId)) { Write-Error "SubscriptionId parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($Location)) { 
    $Location = $env:ACRSYNC_TARGET_ACI_LOCATION
    if ([string]::IsNullOrEmpty($Location)) { Write-Error "Location parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($ResourceGroup)) { 
    $ResourceGroup = $env:ACRSYNC_TARGET_ACI_RESOURCEGROUP_NAME
    if ([string]::IsNullOrEmpty($ResourceGroup)) { Write-Error "ResourceGroup parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($AcrName)) { 
    $AcrName = $env:ACRSYNC_TARGET_ACR_NAME
    if ([string]::IsNullOrEmpty($AcrName)) { Write-Error "AcrName parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) { 
    $ServicePrincipalClientId = $env:ACRSYNC_TARGET_SP_CLIENT_ID
    if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) { Write-Error "ServicePrincipalClientId parameter is not specified"; return }
}
if ($null -eq $ServicePrincipalClientSecret) { 
    $val = $env:ACRSYNC_TARGET_SP_CLIENT_SECRET
    $ServicePrincipalClientSecret = $val ? (ConvertTo-SecureString -String $val -AsPlainText -Force) : $null
    if ($null -eq $ServicePrincipalClientSecret) { Write-Error "ServicePrincipalClientSecret parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($ContainerGroupName)) { 
    $ContainerGroupName = $env:ACRSYNC_TARGET_ACI_NAME
    if ([string]::IsNullOrEmpty($ContainerGroupName)) { Write-Error "ContainerGroupName parameter is not specified"; return }
}
if ([string]::IsNullOrEmpty($ImageNameTag)) { 
    $ImageNameTag = $env:ACRSYNC_CONTAINER_IMAGE_NAME_TAG
    if ([string]::IsNullOrEmpty($ImageNameTag)) { Write-Error "ImageNameTag parameter is not specified"; return }
}

$targetAcrUri = "$AcrName.$((Get-AzEnvironment -Name $CloudEnv).ContainerRegistryEndpointSuffix)"

. $PSScriptRoot/EnvVars.ps1
$envVarObjects = [System.Collections.ArrayList]@()
foreach ($var in $AcrSyncEnvVarNames) {
    $value = [Environment]::GetEnvironmentVariable($var)
    $envVarObject = $null
    if (!$var.EndsWith('SECRET')) {
        $envVarObject = New-AzContainerInstanceEnvironmentVariableObject -Name $var -Value $value
    }
    else {
        $envVarObject = New-AzContainerInstanceEnvironmentVariableObject -Name $var -SecureValue (ConvertTo-SecureString -String $value -AsPlainText -Force)
    }
    $envVarObjects.Add($envVarObject) | Out-Null
}

Connect-AzAccount -Environment $CloudEnv -Tenant $TenantId -Subscription $SubscriptionId -UseDeviceAuthentication
if (!(Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroup -Location $Location -Force
}

$containerGroup = Get-AzContainerGroup -ResourceGroupName $ResourceGroup -Name $ContainerGroupName -ErrorAction SilentlyContinue
if ($containerGroup) {
    Stop-AzContainerGroup -ResourceGroupName $ResourceGroup -Name $ContainerGroupName
    Remove-AzContainerGroup -ResourceGroupName $ResourceGroup -Name $ContainerGroupName
    Start-Sleep -Seconds 5
}

$containerName = $ImageNameTag.Split(':')[0]
$index = $containerName.LastIndexOfAny("/.".ToCharArray())
if ($index -ge 0) {
    $containerName = $containerName.Substring($index+1)
}
$container = New-AzContainerInstanceObject -Name $containerName -Image "$targetAcrUri/$ImageNameTag" -EnvironmentVariable $envVarObjects -RequestCpu 2 -RequestMemoryInGb 4
$imageRegistryCredential = New-AzContainerGroupImageRegistryCredentialObject -Server $targetAcrUri -Username $ServicePrincipalClientId -Password $ServicePrincipalClientSecret
$containerGroup = New-AzContainerGroup -ResourceGroupName $ResourceGroup -Name $ContainerGroupName -Location $Location -Container $container -ImageRegistryCredential $imageRegistryCredential -OSType 'Linux' -Sku 'Standard' -RestartPolicy 'Always'

# Repeat showing latest logs until user presses any key
$showLogsRepeatedly = $false
if ($showLogsRepeatedly) {
    $waitSeconds = 7
    $counter = $waitSeconds
    do {
        if ($counter -eq $waitSeconds) {
            Write-Host "$([Environment]::NewLine)vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv$([Environment]::NewLine)Latest Logs:$([Environment]::NewLine)============"
            Get-AzContainerInstanceLog -ResourceGroupName $ResourceGroup -ContainerGroupName $ContainerGroupName -ContainerName $containerName
        }
        Start-Sleep -Seconds 1
        $counter--
        if ($counter -eq 0) { $counter = $waitSeconds }
    } until ([System.Console]::KeyAvailable)

    Write-Output "User cancelled, stopping to show logs."
}
