<#
.SYNOPSIS
    Stop or start all CMI/AIS services for an environment
.PARAMETER App
    Application type: cmi or ais
.PARAMETER Env
    Environment: test or prod
.PARAMETER Action
    Action: start or stop
#>

param (
    [Parameter(Mandatory)]
    [ValidateSet("cmi", "ais")]
    [string]$App,
    
    [Parameter(Mandatory)]
    [ValidateSet("test", "prod")]
    [string]$Env,
    
    [Parameter(Mandatory)]
    [ValidateSet("start", "stop")]
    [string]$Action
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# Check admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Run as admin"
    exit 1
}

# Constants
$Delay = 2

# Determine remote host
if ($Env -eq "test") {
    $RemoteHost = "ziaxiomatap02"
}
else {
    if ($App -eq "cmi") {
        $RemoteHost = "ziaxiomapap03"
    }
    elseif ($App -eq "ais") {
        $RemoteHost = "ziaxiomapap04"
    }
}

# ============================================
# Helper Functions
# ============================================

function Stop-ServicesRemote {
    param (
        [string[]]$Services,
        [string]$RemoteHost,
        [int]$Delay = 2
    )
    
    $scriptBlock = {
        param ([string[]]$Services, [int]$Delay)
        
        foreach ($service in $Services) {
            Write-Output ""
            Write-Output "Trying to stop the service ${service}..."
            $output = net stop "$service" 2>&1
            
            if ($output -match "service was stopped successfully") {
                Write-Output "${service} stopped."
            }
            else {
                Write-Output "Stopping service ${service} failed. Error: $output"
            }
            Start-Sleep -Seconds $Delay
        }
    }
    
    Invoke-Command -ComputerName $RemoteHost -ScriptBlock $scriptBlock -ArgumentList $Services, $Delay
}

function Start-ServicesRemote {
    param (
        [string[]]$Services,
        [string]$RemoteHost,
        [int]$Delay = 2
    )
    
    $scriptBlock = {
        param ([string[]]$Services, [int]$Delay)
        
        foreach ($service in $Services) {
            Write-Output ""
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            
            if ($serviceObj -and $serviceObj.Status -ne 'Running') {
                Write-Output "Trying to start the service ${service}..."
                $output = net start "$service" 2>&1
                
                if ($output -match "service was started successfully") {
                    Write-Output "Waiting..."
                    $isRunning = $false
                    while (-not $isRunning) {
                        Start-Sleep -Seconds 1
                        $serviceStatus = Get-Service -Name "$service" -ErrorAction SilentlyContinue
                        
                        if ($serviceStatus.Status -eq 'Running') {
                            $isRunning = $true
                            Write-Output "${service} started."
                        }
                        else {
                            Write-Output "${service} still starting up..."
                        }
                    }
                }
                else {
                    Write-Output "Starting service ${service} failed. Error: $output"
                }
            }
            else {
                Write-Output "Service ${service} already running."
            }
            Start-Sleep -Seconds $Delay
        }
    }
    
    Invoke-Command -ComputerName $RemoteHost -ScriptBlock $scriptBlock -ArgumentList $Services, $Delay
}

# ============================================
# Main Execution
# ============================================

# Fetch configuration
try {
    Write-Output "Calling API for ${App}/${Env}..."
    $elements = Get-CMIConfigData -App $App -Environment $Env
}
catch {
    Write-Output "Failed to fetch configuration data: $_"
    exit 1
}

if (($elements | Measure-Object).Count -lt 1) {
    Write-Output "Nothing found."
    exit 1
}

Write-Output "Answer received. Getting the names of the corresponding services..."

# Extract service names
$WindowsServicesList = @()
foreach ($ele in $elements) {
    $WindowsServicesList += $ele.app.servicename._text
}

Write-Output ""
Write-Output "Found Services:"

# Sort services based on action
if ($Action -eq "stop") {
    # Lizenzserver must shut down last
    $WindowsServicesListSorted = $WindowsServicesList | Sort-Object {
        if ($_ -like "*Lizenz*") { 1 } else { 0 }
    }
    
    if ($WindowsServicesListSorted.Length -gt 0) {
        foreach ($e in $WindowsServicesListSorted) {
            Write-Output $e
        }
        Stop-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $RemoteHost -Delay $Delay
    }
    else {
        Write-Output "No services found."
        exit 1
    }
}
elseif ($Action -eq "start") {
    # Lizenzserver must start first
    $WindowsServicesListSorted = $WindowsServicesList | Sort-Object {
        if ($_ -like "*Lizenz*") { 0 } else { 1 }
    }
    
    if ($WindowsServicesListSorted.Length -gt 0) {
        foreach ($e in $WindowsServicesListSorted) {
            Write-Output $e
        }
        Start-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $RemoteHost -Delay $Delay
    }
    else {
        Write-Output "No services found."
        exit 1
    }
}

exit 0