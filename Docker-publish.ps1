param (
    [string]$CloudEnv,
    [string]$AcrName,
    [string]$ServicePrincipalClientId,
    [string]$ServicePrincipalClientSecret,
    [string]$ImageNameTag
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($CloudEnv)) { 
    $CloudEnv = $env:ACRSYNC_TARGET_CLOUDENV_NAME
    if ([string]::IsNullOrEmpty($CloudEnv)) { Write-Error "CloudEnv was not specified"; return }
}
if ([string]::IsNullOrEmpty($AcrName)) { 
    $AcrName = $env:ACRSYNC_TARGET_ACR_NAME
    if ([string]::IsNullOrEmpty($AcrName)) { Write-Error "AcrName was not specified"; return }
}
if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) { 
    $ServicePrincipalClientId = $env:ACRSYNC_TARGET_SP_CLIENT_ID
    if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) { Write-Error "ServicePrincipalClientId was not specified"; return }
}
if ([string]::IsNullOrEmpty($ServicePrincipalClientSecret)) { 
    $ServicePrincipalClientSecret = $env:ACRSYNC_TARGET_SP_CLIENT_SECRET
    if ([string]::IsNullOrEmpty($ServicePrincipalClientSecret)) { Write-Error "ServicePrincipalClientSecret was not specified"; return }
}
if ([string]::IsNullOrEmpty($ImageNameTag)) { 
    $ImageNameTag = $env:ACRSYNC_CONTAINER_IMAGE_NAME_TAG
    if ([string]::IsNullOrEmpty($ImageNameTag)) { Write-Error "ImageNameTag was not specified"; return }
}

$targetAcrUri = "$AcrName.$((Get-AzEnvironment -Name $CloudEnv).ContainerRegistryEndpointSuffix)"

$env:ACRSYNC_TARGET_SP_CLIENT_SECRET | docker login $targetAcrUri --username $env:ACRSYNC_TARGET_SP_CLIENT_ID --password-stdin
docker tag $ImageNameTag "$targetAcrUri/$ImageNameTag"
docker push "$targetAcrUri/$ImageNameTag"
