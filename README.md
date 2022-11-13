<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

</div>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <h1 align="center">AcrSync</h1>

  <p align="center">
    Synchronize repositories and tags from a source to a target Azure Container Registry.
    <br />
    <a href="https://github.com/thgossler/AcrSync/issues">Report Bug</a>
    ·
    <a href="https://github.com/thgossler/AcrSync/issues">Request Feature</a>
    ·
    <a href="https://github.com/thgossler/AcrSync#contributing">Contribute</a>
    ·
    <a href="https://github.com/sponsors/thgossler">Sponsor project</a>
  </p>
</div>


## General Introduction

This script synchronized repositories and tags from a source to a target 
Azure Container Registry. It also removes items from the target registry 
if they are not existing anymore in the source registry.

The source and target ACR instances can be in different Azure clouds
(including sovereign Azure clouds like the AzureChinaCloud), in different
Azure subscriptions and be associated with different AAD tenants.

The script always runs once immediately. If a scheduled job interval is
specified, then it runs repeatedly in that frequency.

When no parameters are specified, then the environment variables as
mentioned under [Input Parameters](#input-parameters) are evaluated.

The sync can also be built and run as a Docker container.


## Scripts

All scripts take parameters and can be called like cmdlets.

`Set-EnvVars.ps1` creates environment settings commonly used by all scripts.

`Run.ps1` starts the sync process (different variants, run on local machine).

`Docker-build.ps1` wraps the sync script in a Docker container image (local).

`Docker-publish.ps1` pushes the previously built Docker image to a remote registry.

`Docker-deploy-aci.ps1` runs a container based on the published image on Azure Container Instances (ACI).


## Prerequisites

- PowerShell 7+
- Az.Accounts module
- Az.KeyVault module
- Az.ContainerRegistry module
- Docker service running


## Input Parameters

Input parameters are read from the following environment variables:

`ACRSYNC_CONTAINER_IMAGE_NAME_TAG`, e.g. 'my-acr-sync:latest' (used to avoid deleting its own image)

`ACRSYNC_TARGET_ACR_NAME`, e.g. 'myTargetACR'

`ACRSYNC_TARGET_ACR_RESOURCEGROUP_NAME`

`ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID`

`ACRSYNC_TARGET_CLOUDENV_NAME` (default: `AzureCloud`, see `(Get-AzEnvironment).Name`)

`ACRSYNC_TARGET_TENANT_ID`

`ACRSYNC_TARGET_KEYVAULT_NAME`, e.g. 'myTargetKV'

`ACRSYNC_TARGET_SP_CLIENT_ID`

`ACRSYNC_TARGET_SP_CLIENT_SECRET`

`ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTID_SECRET_NAME` (default: `ACRSYNC_TARGET_SP_CLIENT_ID`)

`ACRSYNC_TARGET_KEYVAULT_SOURCE_ACR_SP_CLIENTSECRET_SECRET_NAME` (default: `ACRSYNC_TARGET_SP_CLIENT_SECRET`)

`ACRSYNC_TARGET_KEYVAULT_SUBSCRIPTION_ID` (default: `ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID`)

`ACRSYNC_SOURCE_CLOUDENV_NAME` (default: `ACRSYNC_TARGET_CLOUDENV_NAME`)

`ACRSYNC_SOURCE_TENANT_ID` (default: `ACRSYNC_TARGET_TENANT_ID`)

`ACRSYNC_SOURCE_SUBSCRIPTION_ID` (default: `ACRSYNC_TARGET_ACR_SUBSCRIPTION_ID`)

`ACRSYNC_SOURCE_ACR_NAME`, e.g. 'mySourceACR'

`ACRSYNC_SCHEDULED_JOB_INTERVAL_MINUTES` (default: `0`, i.e. only run once)

`ACRSYNC_TARGET_ACI_SUBSCRIPTION_ID`

`ACRSYNC_TARGET_ACI_LOCATION`, e.g. 'chinaeast2' (see: `(Get-AzLocation).Location`)

`ACRSYNC_TARGET_ACI_RESOURCEGROUP_NAME`

`ACRSYNC_TARGET_ACI_NAME`, e.g. 'myContainerGroup'


## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star :wink: Thanks!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License

Distributed under the MIT License. See [`LICENSE`](https://github.com/thgossler/AcrSync/blob/main/LICENSE) for more information.


## Contact

Thomas Gossler - [@thgossler](https://twitter.com/thgossler)<br/>
Project Link: [https://github.com/thgossler/AcrSync](https://github.com/thgossler/AcrSync)


<!-- MARKDOWN LINKS & IMAGES (https://www.markdownguide.org/basic-syntax/#reference-style-links) -->
[contributors-shield]: https://img.shields.io/github/contributors/thgossler/AcrSync.svg
[contributors-url]: https://github.com/thgossler/AcrSync/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/thgossler/AcrSync.svg
[forks-url]: https://github.com/thgossler/AcrSync/network/members
[stars-shield]: https://img.shields.io/github/stars/thgossler/AcrSync.svg
[stars-url]: https://github.com/thgossler/AcrSync/stargazers
[issues-shield]: https://img.shields.io/github/issues/thgossler/AcrSync.svg
[issues-url]: https://github.com/thgossler/AcrSync/issues
[license-shield]: https://img.shields.io/github/license/thgossler/AcrSync.svg
[license-url]: https://github.com/thgossler/AcrSync/blob/main/LICENSE
