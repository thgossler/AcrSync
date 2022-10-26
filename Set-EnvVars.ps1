param(
    [switch]$Persistent = $false,
    [switch]$Clean = $false
)

$EmptyValue = ''

. $PSScriptRoot/EnvVars.ps1

$AcrSyncEnvVars = [hashtable]@{}
function InitEnvVar([string]$Name, $Value) {
    if ($AcrSyncEnvVarNames -notcontains $Name) { Write-Error "Unknown environment variable cannot be initialized"; return }
    $AcrSyncEnvVars.$Name = $Value
}

# For the sync script
InitEnvVar -Name "ACRSYNC_CONTAINER_IMAGE_NAME_TAG" -Value "acr-sync:latest"
InitEnvVar -Name "ACRSYNC_TARGET_ACR_NAME" -Value "myTargetACR"
InitEnvVar -Name "ACRSYNC_TARGET_ACR_RESOURCEGROUP_NAME" -Value "myTargetRG"
InitEnvVar -Name "ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID" -Value "3ce178fb-379c-498c-a5ea-b1bb9332aac5"
InitEnvVar -Name "ACRSYNC_TARGET_CLOUDENV_NAME" -Value "AzureChinaCloud"
InitEnvVar -Name "ACRSYNC_TARGET_TENANT_ID" -Value "40fda28f-aa5c-48a4-803b-3912bb0443d0"
InitEnvVar -Name "ACRSYNC_TARGET_KEYVAULT_NAME" -Value "myTargetKV"
InitEnvVar -Name "ACRSYNC_TARGET_SP_CLIENT_ID" -Value "744d6c11-9422-4604-b300-5920bec77879"
#                "ACRSYNC_TARGET_SP_CLIENT_SECRET" --> to be set manually for current user
InitEnvVar -Name "ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTID_SECRET_NAME" -Value "acr-sync-target-sp-id"
InitEnvVar -Name "ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTSECRET_SECRET_NAME" -Value "acr-sync-target-sp-secret"
InitEnvVar -Name "ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID" -Value "312090e2-d49b-422a-8ab5-af892d75bcbc"
InitEnvVar -Name "ACRSYNC_SOURCE_CLOUDENV_NAME" -Value "AzureCloud"
InitEnvVar -Name "ACRSYNC_SOURCE_TENANT_ID" -Value "f6dfa1dc-50b9-4107-bb8b-d8037af167fd"
InitEnvVar -Name "ACRSYNC_SOURCE_ACR_SUBSCRIPTION_ID" -Value "1f48c25d-2d23-4ab8-b5b0-58d76be87616"
InitEnvVar -Name "ACRSYNC_SOURCE_ACR_NAME" -Value "mySourceACR"
InitEnvVar -Name "ACRSYNC_SCHEDULED_JOB_INTERVAL_MINUTES" -Value 60

# For the deploy script only
InitEnvVar -Name "ACRSYNC_TARGET_ACI_SUBSCRIPTION_ID" -Value $AcrSyncEnvVars.ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID
InitEnvVar -Name "ACRSYNC_TARGET_ACI_LOCATION" -Value "chinaeast2"
InitEnvVar -Name "ACRSYNC_TARGET_ACI_RESOURCEGROUP_NAME" -Value "my-acr-sync"
InitEnvVar -Name "ACRSYNC_TARGET_ACI_NAME" -Value "my-acr-sync"

if (!$Persistent) {
    foreach ($var in $AcrSyncEnvVars.Keys) {
        [Environment]::SetEnvironmentVariable($var, $Clean ? $EmptyValue : $AcrSyncEnvVars.$var)
    }
}
else {
    $Scope = [System.EnvironmentVariableTarget]::User
    foreach ($var in $AcrSyncEnvVars.Keys) {
        [System.Environment]::SetEnvironmentVariable($var, $Clean ? $EmptyValue : $AcrSyncEnvVars.$var, $Scope)
    }
}
