<#
.SYNOPSIS
    Fetch all CMI/AIS configuration data for cockpit display
.DESCRIPTION
    Simple wrapper to get all data from the CMI Config API
#>

param()

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

try {
    # Fetch all data
    $elements = Get-CMIConfigData
    
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