<#
.SYNOPSIS
    Control Windows services on remote hosts
.PARAMETER Service
    Service name
.PARAMETER Action
    Action to perform (start or stop)
.PARAMETER Hostname
    Target hostname
#>

param (
    [Parameter(Mandatory)]
    [string]$Service,
    
    [Parameter(Mandatory)]
    [ValidateSet("start", "stop")]
    [string]$Action,
    
    [Parameter(Mandatory)]
    [string]$Hostname
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# Main script block to execute on remote host
$scriptBlock = {
    param($Service, $Action)
    
    $WarningPreference = 'SilentlyContinue'
    
    try {
        # Determine target status and perform action
        if ($Action -eq "start") {
            Start-Service -Name $Service -ErrorAction Stop
            $targetStatus = "Running"
        }
        elseif ($Action -eq "stop") {
            Stop-Service -Name $Service -ErrorAction Stop
            $targetStatus = "Stopped"
        }
        else {
            throw "Invalid action: $Action"
        }
        
        # Wait for target status (max 30 seconds)
        $timeout = 30
        $elapsed = 0
        while ($true) {
            $status = (Get-Service -Name $Service).Status
            if ($status -eq $targetStatus) {
                break
            }
            Start-Sleep -Seconds 1
            $elapsed++
            if ($elapsed -ge $timeout) {
                return "timeout"
            }
        }
        
        # Return final status
        return (Get-Service -Name $Service).Status.ToString().ToLower()
    }
    catch {
        return "Error: $_"
    }
}

# Execute remote command
try {
    $result = Invoke-Command `
        -ComputerName $Hostname `
        -ScriptBlock $scriptBlock `
        -ArgumentList $Service, $Action `
        -ErrorAction Stop
    
    Write-Output $result
    
    # Determine exit code
    if ($result -match '^(stopped|running)$') {
        exit 0
    }
    elseif ($result -eq "timeout") {
        exit 2
    }
    else {
        exit 1
    }
}
catch {
    Write-Error "Invoke-Command failed: $_"
    exit 3
}