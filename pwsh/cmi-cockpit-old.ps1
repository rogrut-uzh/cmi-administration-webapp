<#
.SYNOPSIS
    Fetch CMI/AIS configuration data for cockpit display (filtered)
.DESCRIPTION
    Retrieves configuration data from the CMI Config API with filtering options
.PARAMETER App
    Application type: cmi, ais, or all
.PARAMETER Env
    Environment: test, prod, or all
#>

param (
    [Parameter(Mandatory)]
    [ValidateSet("cmi", "ais", "all")]
    [string]$App,
    
    [Parameter(Mandatory)]
    [ValidateSet("test", "prod", "all")]
    [string]$Env
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

try {
    # Build filter based on parameters
    if ($App -eq "all" -and $Env -eq "all") {
        # Get all data
        $elements = Get-CMIConfigData
    }
    elseif ($App -eq "all") {
        # Get all apps for specific environment
        $elements = @()
        $elements += Get-CMIConfigData -App "cmi" -Environment $Env
        $elements += Get-CMIConfigData -App "ais" -Environment $Env
    }
    elseif ($Env -eq "all") {
        # Get specific app for all environments
        $elements = @()
        $elements += Get-CMIConfigData -App $App -Environment "test"
        $elements += Get-CMIConfigData -App $App -Environment "prod"
    }
    else {
        # Get specific app and environment
        $elements = Get-CMIConfigData -App $App -Environment $Env
    }
    
    if (-not $elements -or ($elements | Measure-Object).Count -lt 1) {
        Write-Error "Nothing found."
        exit 1
    }
    
    # Output as JSON
    $elements | ConvertTo-Json -Depth 10
    exit 0
}
catch {
    Write-Error "Failed to fetch configuration data: $_"
    exit 1
}