
<#PSScriptInfo

.VERSION 1.0.1

.GUID 031b94ea-9b95-4886-afcc-fc59299c7747

.AUTHOR Tyler Richardson

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://github.com/wethreetrees/RegisterAzureRepo

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    2022-03-10 - initial release

.PRIVATEDATA

#>

<#
.SYNOPSIS
    Azure Artifact PowerShell Repository Helper
.DESCRIPTION
    A PowerShell script to help register Azure Artifact PowerShell Repositories properly

    If you have the url previously registered, this script will unregister and re-register
    to attempt to configure it to work properly.

    You can provide your PAT token either as a parameter or when prompted.
.EXAMPLE
    Register-AzureArtifactRepo -Url 'https://pkgs.dev.azure.com/MyOrg/_packaging/MyArtifactRepo/nuget/v2'

    Prompts for your PAT token and registers the Azure Artifact repo as a PSRepository
.EXAMPLE
    Register-AzureArtifactRepo -Url 'https://pkgs.dev.azure.com/MyOrg/_packaging/MyArtifactRepo/nuget/v2'

    Prompts for your PAT token and registers the Azure Artifact repo as a PSRepository
#>

Param(
    # Azure Artifact Repository NuGet Feed URL
    # e.g. 'https://pkgs.dev.azure.com/{{ org }}/_packaging/{{ artifactRepoName }}/nuget/v2'
    [Parameter(Mandatory)]
    [ValidateScript(
        {
            if (-not $_.StartsWith('https://pkgs.dev.azure.com/')) {
                throw "Url must be an Azure artifact repo url, starting with 'https://pkgs.dev.azure.com/'"
            }

            return $true
        }
    )]
    [string]$Url,

    # Azure PAT token (must have package read permissions)
    [Parameter()]
    [string]$PatToken
)

$credential = $Host.UI.PromptForCredential(
    "A PAT token is required to register the Azure Artifact Repository",
    "Enter your Azure PAT token",
    "AzurePatToken",
    $null
)

$repoName = (Get-PSRepository -Verbose:$false | Where-Object { $_.SourceLocation -eq $Url }).Name

if ($repoName) {
    if ($sourcesMatchingName = Get-PackageSource -Name $repoName) {
        $sourcesMatchingName | Unregister-PackageSource
    }

    if ($sourcesMatchingUrl = Get-PackageSource -Location $Url | Where-Object { $_.IsRegistered }) {
        $sourcesMatchingUrl | Unregister-PackageSource
    }
} else {
    $repoName = [regex]::Matches($Url, '(?<=.*?_packaging/).*?(?=/nuget/v2)').Value -join '_'
}

$psRepositoryParams = @{
    Name                 = $repoName
    SourceLocation       = $Url
    ScriptSourceLocation = $Url
    PublishLocation      = $Url
    InstallationPolicy   = 'Trusted'
    Credential           = $Credential
}

Register-PSRepository @psRepositoryParams

$pkgSourceParams = @{
    Name         = $repoName
    Location     = $Url
    Trusted      = $true
    ProviderName = 'NuGet'
    Credential   = $Credential
}

$null = Register-PackageSource @pkgSourceParams
