<#
.SYNOPSIS
    List all CMI/AIS services with their current status
.PARAMETER Env
    Environment: test or prod
#>

param (
    [Parameter(Mandatory)]
    [ValidateSet("test", "prod")]
    [string]$Env
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# Define endpoints based on environment
if ($Env -eq "prod") {
    $endpoints = @(
        @{ Label = "CMI GEVER (Prod)"; App = "cmi"; Env = "prod" },
        @{ Label = "CMI AIS (Prod)"; App = "ais"; Env = "prod" }
    )
}
elseif ($Env -eq "test") {
    $endpoints = @(
        @{ Label = "CMI GEVER (Test)"; App = "cmi"; Env = "test" },
        @{ Label = "CMI AIS (Test)"; App = "ais"; Env = "test" }
    )
}
else {
    throw "No environment set"
}

# Array for endpoint data
$endpointsData = @()

# Global dictionary for Host -> Set of Service names
$hostServices = @{}

# Fetch data for each endpoint
foreach ($ep in $endpoints) {
    $label = $ep.Label
    $entries = @()
    
    try {
        # Fetch API data
        $jsonData = Get-CMIConfigData -App $ep.App -Environment $ep.Env
        
        if ($jsonData -isnot [System.Collections.IEnumerable]) {
            $jsonData = @($jsonData)
        }
        
        foreach ($item in $jsonData) {
            $namefull = if ($item.namefull._text) { $item.namefull._text } else { "" }
            $appInfo = $item.app
            $hostname = if ($appInfo.host._text) { $appInfo.host._text.Trim() } else { "" }
            $servicename = if ($appInfo.servicename._text) { $appInfo.servicename._text.Trim() } else { "" }
            
            $entry = @{
                namefull       = $namefull
                hostname       = $hostname
                servicename    = $servicename
                status_service = ""
            }
            $entries += $entry
            
            # Collect service names globally per host
            if (-not [string]::IsNullOrEmpty($hostname)) {
                if (-not $hostServices.ContainsKey($hostname)) {
                    $hostServices[$hostname] = New-Object System.Collections.Generic.HashSet[string]
                }
                if (-not [string]::IsNullOrEmpty($servicename)) {
                    [void]$hostServices[$hostname].Add($servicename)
                }
            }
        }
    }
    catch {
        $entries += @{
            namefull       = ""
            hostname       = "Error: $($_.Exception.Message)"
            servicename    = ""
            status_service = "Error"
        }
    }
    
    $endpointsData += @{
        label    = $label
        endpoint = "${ep.App}/${ep.Env}"
        entries  = $entries
    }
}

# Query service status per host (one remote call per host)
$hostStatusMapping = @{}
foreach ($hostname in $hostServices.Keys) {
    $servicesArray = $hostServices[$hostname] | Sort-Object
    $serviceStatus = @{}
    
    foreach ($service in $servicesArray) {
        try {
            $svc = Invoke-Command -ComputerName $hostname -ScriptBlock {
                param($s)
                Get-Service -Name $s -ErrorAction Stop
            } -ArgumentList $service -ErrorAction Stop
            
            if ($svc.Status -eq 'Running') {
                $serviceStatus[$service] = "running"
            }
            else {
                $serviceStatus[$service] = "stopped"
            }
        }
        catch {
            $serviceStatus[$service] = "error"
        }
    }
    $hostStatusMapping[$hostname] = $serviceStatus
}

# Update entries with queried status values
foreach ($epData in $endpointsData) {
    foreach ($entry in $epData.entries) {
        $hostname = $entry.hostname
        if ($hostStatusMapping.ContainsKey($hostname)) {
            $mapping = $hostStatusMapping[$hostname]
            $entry.status_service = if ($mapping.ContainsKey($entry.servicename)) { 
                $mapping[$entry.servicename] 
            } 
            else { 
                "unknown" 
            }
        }
        else {
            $entry.status_service = "Error"
        }
    }
}

# Output result as JSON
Write-Output ($endpointsData | ConvertTo-Json -Depth 5 -Compress)
exit 0