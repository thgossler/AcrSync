param (
    [string]$ImageNameTag
)

if ([string]::IsNullOrEmpty($ImageNameTag)) { 
    $ImageNameTag = $env:ACRSYNC_CONTAINER_IMAGE_NAME_TAG
    if ([string]::IsNullOrEmpty($ImageNameTag)) { Write-Error "ImageNameTag was not specified"; return }
}

$env:DOCKER_BUILDKIT=1
docker build --tag $ImageNameTag .
