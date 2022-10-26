param(
    [switch]$Script = $false,
    [switch]$Params = $false
)

if (!$Script) {
    # Passes-through existing environment variables. To override a variable add '=<value>' to it
    docker run `
        --env ACRSYNC_TARGET_ACR_NAME `
        --env ACRSYNC_TARGET_ACR_RESOURCEGROUP_NAME `
        --env ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID `
        --env ACRSYNC_TARGET_CLOUDENV_NAME `
        --env ACRSYNC_TARGET_TENANT_ID `
        --env ACRSYNC_TARGET_KEYVAULT_NAME `
        --env ACRSYNC_TARGET_SP_CLIENT_ID `
        --env ACRSYNC_TARGET_SP_CLIENT_SECRET `
        --env ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTID_SECRET_NAME `
        --env ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTSECRET_SECRET_NAME `
        --env ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID `
        --env ACRSYNC_SOURCE_CLOUDENV_NAME `
        --env ACRSYNC_SOURCE_TENANT_ID `
        --env ACRSYNC_SOURCE_ACR_SUBSCRIPTION_ID `
        --env ACRSYNC_SOURCE_ACR_NAME `
        --env ACRSYNC_SCHEDULED_JOB_INTERVAL_MINUTES `
        acr-sync
}
elseif ($Params) {
    . $PSScriptRoot/Sync-AzContainerRegistry.ps1 `
        -TargetAcrName myTargetACR `
        -TargetAcrResourceGroup myTargetRG `
        -TargetAcrSubscriptionId 3ce178fb-379c-498c-a5ea-b1bb9332aac5 `
        -TargetAcrTenantId 40fda28f-aa5c-48a4-803b-3912bb0443d0 `
        -TargetAcrCloudEnv AzureChinaCloud `
        -TargetAcrKeyVaultName myTargetKV `
        -TargetAcrSpClientId 744d6c11-9422-4604-b300-5920bec77879 `
        -TargetAcrSpClientSecret $env:ACRSYNC_TARGET_SP_CLIENT_SECRET `
        -TargetAcrKeyVaultSourceAcrSpClientIdSecretName acr-sync-target-sp-id `
        -TargetAcrKeyVaultSourceAcrSpClientSecretSecretName acr-sync-target-sp-secret `
        -TargetAcrKeyVaultSubscriptionId 312090e2-d49b-422a-8ab5-af892d75bcbc `
        -SourceAcrCloudEnv AzureCloud `
        -SourceAcrTenantId f6dfa1dc-50b9-4107-bb8b-d8037af167fd `
        -SourceAcrSubscriptionId 1f48c25d-2d23-4ab8-b5b0-58d76be87616 `
        -SourceAcrName mySourceACR `
        ScheduledJobIntervalMinutes 60
}
else {
    . $PSScriptRoot/Set-EnvVars.ps1
    . $PSScriptRoot/Sync-AzContainerRegistry.ps1
    . $PSScriptRoot/Set-EnvVars.ps1 -Clean
}
