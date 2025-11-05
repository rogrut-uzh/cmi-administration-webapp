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

function Start-StopCMIService {
    <#
    .SYNOPSIS
        Start or stop CMI service for a database
    .DESCRIPTION
        Finds the corresponding CMI service for a database and starts/stops it
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DbName,
        
        [Parameter(Mandatory)]
        [ValidateSet("start", "stop")]
        [string]$Action
    )
    
    try {
        Write-Output "DEBUG: Searching for CMI service for database: $DbName"
        
        # Try to find the service by database name
        # First, get all CMI/AIS configurations
        $allData = @()
        $allData += Get-CMIConfigData -App "cmi" -Environment "test"
        $allData += Get-CMIConfigData -App "cmi" -Environment "prod"
        $allData += Get-CMIConfigData -App "ais" -Environment "test"
        $allData += Get-CMIConfigData -App "ais" -Environment "prod"
        
        if ($allData -isnot [System.Collections.IEnumerable]) {
            $allData = @($allData)
        }
        
        Write-Output "DEBUG: Found $($allData.Count) total configurations"
        
        # Find matching database
        $matchedConfig = $null
        foreach ($config in $allData) {
            $configDbName = $config.database.name._text
            Write-Output "DEBUG: Checking config with DB: $configDbName"
            
            if ($configDbName -eq $DbName) {
                $matchedConfig = $config
                Write-Output "DEBUG: MATCH FOUND!"
                break
            }
        }
        
        if (-not $matchedConfig) {
            Write-Output "ERROR: No configuration found for database: $DbName"
            Write-Output "ERROR: Available databases:"
            foreach ($config in $allData) {
                Write-Output "  - $($config.database.name._text)"
            }
            return 1
        }
        
        # Extract service information
        $serviceName = $matchedConfig.app.servicename._text
        $hostname = $matchedConfig.app.host._text
        
        if ([string]::IsNullOrEmpty($serviceName)) {
            Write-Output "ERROR: Service name is empty for database: $DbName"
            return 1
        }
        
        if ([string]::IsNullOrEmpty($hostname)) {
            Write-Output "ERROR: Hostname is empty for database: $DbName"
            return 1
        }
        
        Write-Output "DEBUG: Found service '$serviceName' on host '$hostname'"
        Write-Output "DEBUG: Calling cmi-control-single-service.ps1"
        
        # Call service control script
        & "$PSScriptRoot\cmi-control-single-service.ps1" `
            -Service $serviceName `
            -Action $Action `
            -Hostname $hostname
        
        $exitCode = $LASTEXITCODE
        Write-Output "DEBUG: cmi-control-single-service.ps1 returned exit code: $exitCode"
        
        return $exitCode
    }
    catch {
        Write-Output "ERROR: Exception in Start-StopCMIService: $_"
        Write-Output "ERROR: Stack trace: $($_.ScriptStackTrace)"
        return 1
    }
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
        
        Write-Output "INFO: Starting backup for ${Database} on ${DbHost}"
        
        # Stop CMI service
        Write-Output "INFO: Stopping CMI service..."
        $stopResult = Start-StopCMIService -DbName $Database -Action "stop"
        if ($stopResult -ne 0) {
            Write-Output "ERROR: Failed to stop CMI service (exit code: $stopResult)"
            exit 1
        }
        Write-Output "INFO: CMI service stopped successfully"
        
        # Create backup
        Write-Output "INFO: Creating backup..."
        $backupResult = Invoke-DatabaseBackup -DbName $Database -DatabaseHost $DbHost
        
        # Start CMI service (always try to start, even if backup failed)
        Write-Output "INFO: Starting CMI service..."
        $startResult = Start-StopCMIService -DbName $Database -Action "start"
        if ($startResult -ne 0) {
            Write-Output "WARNING: Failed to start CMI service (exit code: $startResult)"
        }
        else {
            Write-Output "INFO: CMI service started successfully"
        }
        
        # Return backup result
        if ($backupResult -eq 0) {
            Write-Output "SUCCESS: Backup completed"
        }
        exit $backupResult
    }
    
    default {
        Write-Output (@{ error = "Invalid job type: $Job" } | ConvertTo-Json -Compress)
        exit 1
    }
}
