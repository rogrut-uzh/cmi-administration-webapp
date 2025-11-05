<#
.SYNOPSIS
    CMI Database operations (list databases or create backups with service stop)
.DESCRIPTION
    List databases or create CopyOnly backups.
    For backup operations, the corresponding CMI/AIS service is stopped before backup
    and restarted afterwards to ensure application consistency.
.PARAMETER Job
    Job type: "list" or "backup"
.PARAMETER Env
    Environment: "test" or "prod" (required for list job)
.PARAMETER Database
    Database name (required for backup job)
.PARAMETER DbHost
    Database host (required for backup job)
.EXAMPLE
    .\cmi-databases.ps1 -Job list -Env test
.EXAMPLE
    .\cmi-databases.ps1 -Job backup -Database axioma_zzm_TEST -DbHost ziaxiomatsql02
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
        [string]$DbHost
    )
    
    try {
        $result = Invoke-Command -ComputerName $DbHost -ScriptBlock {
            param($DbHost, $Db, $currentDate)
            
            $backupPath = "S:\manual-backups-from-webapp\"
            $backupFilename = "DB-Backup-${Db}_${currentDate}.bak"
            
            try {
                Backup-SqlDatabase `
                    -ServerInstance $DbHost `
                    -Database $Db `
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
        } -ArgumentList $DbHost, $DbName, (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") -ErrorAction Stop
        
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
    .DESCRIPTION
        Queries the CMI Config API to find the service name and app server hostname
        for a given database, then starts or stops that service.
        Note: The service runs on the APP server (e.g. ziaxiomatap02), 
              NOT the DB server (e.g. ziaxiomatsql02)!
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DbName,
        
        [Parameter(Mandatory)]
        [ValidateSet("start", "stop")]
        [string]$Action
    )
    
    try {
        # Build API filter for this specific database
        $filter = "database%2Fname=${DbName}&exactmatch=true"
        
        # Get configuration from API
        $jsonData = Get-CMIConfigData -Filter $filter
        $jsonData
        
        if (-not $jsonData -or ($jsonData | Measure-Object).Count -lt 1) {
            Write-Output "ERROR: No configuration found for database: $DbName"
            return 1
        }
        
        # Extract service name and hostname (APP server!)
        $serviceName = $jsonData.app.servicename._text
        $hostname = $jsonData.app.host._text
        
        if ([string]::IsNullOrEmpty($serviceName) -or [string]::IsNullOrEmpty($hostname)) {
            Write-Output "ERROR: Missing service name or hostname for database: $DbName"
            return 1
        }
        
        # Call service control script
        & "$PSScriptRoot\cmi-control-single-service.ps1" `
            -Service $serviceName `
            -Action $Action `
            -Hostname $hostname
        
        return $LASTEXITCODE
    }
    catch {
        Write-Output "ERROR: Failed to control CMI service: $_"
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
        
        # Stop CMI service (runs on APP server, not DB server!)
        $stopResult = Start-StopCMIService -DbName $Database -Action "stop"
        if ($stopResult -ne 0) {
            Write-Output "ERROR: Failed to stop CMI service"
            exit 1
        }
        
        # Create backup (on DB server)
        $backupResult = Invoke-DatabaseBackup -DbName $Database -DbHost $DbHost
        
        # Start CMI service (always try, even if backup failed)
        $startResult = Start-StopCMIService -DbName $Database -Action "start"
        
        # Return backup result
        exit $backupResult
    }
    
    default {
        Write-Output (@{ error = "Invalid job type: $Job" } | ConvertTo-Json -Compress)
        exit 1
    }
}
