FROM mcr.microsoft.com/azure-powershell:latest

LABEL Name=acr-sync Version=1.0.0

WORKDIR /scripts

# Include sync PowerShell script
COPY Sync-AzContainerRegistry.ps1 Sync-AzContainerRegistry.ps1

# Install docker for Connect-AzContainerRegistry to work
RUN apt-get update && \
    apt-get -qy full-upgrade && \
    apt-get install -qy curl && \
    curl -sSL https://get.docker.com/ | sh

# Start script
CMD [ "pwsh", "-File", "./Sync-AzContainerRegistry.ps1"]
