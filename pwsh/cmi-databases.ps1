<#
.SYNOPSIS
    CMI Database operations (list databases or create backups)
.PARAMETER Job
    Job type: "list" or "backup"
.PARAMETER Env
    Environment: "test" or "prod" (required for list job)
.PARAMETER Database
    Database name (required for backup job)
.PARAMETER DbHost
    Database host (required for backup job)
#>

param (
    [Parameter(Mandatory)]
    [ValidateSet("list", "backup")]
    [string]$Job,
    
    [Parameter()]
    [ValidateSet("test", "prod")]
    [string]$Env,
    
    [Parameter()]
    [string]$Database,
    
    [Parameter()]
    [string]$DbHost
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# ============================================
# Helper Functions
# ============================================

function Get-DatabaseList {
    <#
    .SYNOPSIS
        Get list of all databases for an environment
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Environment
    )
    
    $databases = @()
    
    try {
        # Fetch configuration for CMI and AIS
        $jsonData = @()
        $jsonData += Get-CMIConfigData -App "cmi" -Environment $Environment
        $jsonData += Get-CMIConfigData -App "ais" -Environment $Environment
        
        if (($jsonData | Measure-Object).Count -lt 1) {
            return (@{ error = "No data found" } | ConvertTo-Json -Compress)
        }
        
        # Ensure array
        if ($jsonData -isnot [System.Collections.IEnumerable]) {
            $jsonData = @($jsonData)
        }
        
        # Extract database info
        foreach ($item in $jsonData) {
            $databases += @{
                namefull = $item.namefull._text
                dbhost   = $item.database.host._text
                dbname   = $item.database.name._text
            }
        }
    }
    catch {
        $databases = @(
            @{
                namefull = ""
                dbhost   = "Error: $($_.Exception.Message)"
                dbname   = ""
            }
        )
    }
    
    return ($databases | ConvertTo-Json -Depth 5 -Compress)
}

function Invoke-DatabaseBackup {
    <#
    .SYNOPSIS
        Create database backup
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DbName,
        
        [Parameter(Mandatory)]
        [string]$DatabaseHost
    )
    
    try {
        $result = Invoke-Command -ComputerName $DatabaseHost -ScriptBlock {
            param($DbHost, $DbName, $currentDate)
            
            $backupPath = "S:\manual-backups-from-webapp\"
            $backupFilename = "DB-Backup-${DbName}_${currentDate}.bak"
            
            try {
                Backup-SqlDatabase `
                    -ServerInstance $DbHost `
                    -Database $DbName `
                    -BackupFile "${backupPath}${backupFilename}" `
                    -CopyOnly `
                    -Initialize `
                    -Checksum `
                    -ErrorAction Stop
                
                return "SUCCESS"
            }
            catch {
                return "ERROR: $_"
            }
        } -ArgumentList $DatabaseHost, $DbName, (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") -ErrorAction Stop
        
        Write-Output $result
        
        if ($result -match '^SUCCESS') {
            return 0
        }
        else {
            return 1
        }
    }
    catch {
        Write-Output "ERROR: Invoke-Command failed: $_"
        return 3
    }
}

function Start-StopCMIService {
    <#
    .SYNOPSIS
        Start or stop CMI service for a database
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DbName,
        
        [Parameter(Mandatory)]
        [ValidateSet("start", "stop")]
        [string]$Action
    )
    
    try {
        # Get service info from API
        $filter = "database%2Fname=${DbName}&exactmatch=true"
        $jsonData = Get-CMIConfigData -Filter $filter
        
        if (($jsonData | Measure-Object).Count -lt 1) {
            Write-Error "No data found for database: $DbName"
            return 1
        }
        
        $serviceName = $jsonData.app.servicename._text
        $hostname = $jsonData.app.host._text
        
        # Call service control script
        & "$PSScriptRoot\cmi-control-single-service.ps1" `
            -Service $serviceName `
            -Action $Action `
            -Hostname $hostname
        
        return $LASTEXITCODE
    }
    catch {
        Write-Error "Failed to control CMI service: $_"
        return 1
    }
}

# ============================================
# Main Execution
# ============================================

switch ($Job) {
    "list" {
        if (-not $Env) {
            Write-Output (@{ error = "Environment parameter required for list job" } | ConvertTo-Json -Compress)
            exit 1
        }
        
        Write-Output (Get-DatabaseList -Environment $Env)
        exit 0
    }
    
    "backup" {
        # Validate parameters
        if (-not $Database) {
            Write-Output (@{ error = "Database parameter required for backup job" } | ConvertTo-Json -Compress)
            exit 1
        }
        if (-not $DbHost) {
            Write-Output (@{ error = "Database host parameter required for backup job" } | ConvertTo-Json -Compress)
            exit 1
        }
        
        # Stop CMI service
        $stopResult = Start-StopCMIService -DbName $Database -Action "stop"
        if ($stopResult -ne 0) {
            Write-Output "ERROR: Failed to stop CMI service"
            exit 1
        }
        
        # Create backup
        $backupResult = Invoke-DatabaseBackup -DbName $Database -DatabaseHost $DbHost
        
        # Start CMI service (always try to start, even if backup failed)
        $startResult = Start-StopCMIService -DbName $Database -Action "start"
        
        # Return backup result
        exit $backupResult
    }
    
    default {
        Write-Output (@{ error = "Invalid job type: $Job" } | ConvertTo-Json -Compress)
        exit 1
    }
}
