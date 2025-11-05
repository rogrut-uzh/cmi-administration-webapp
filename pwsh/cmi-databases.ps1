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
        Write-Verbose "Starting Invoke-Command to $DbHost"
        Write-Verbose "Database: $DbName"
        Write-Verbose "Server: $DbHost"
        
        $result = Invoke-Command -ComputerName $DbHost -ScriptBlock {
            param($DbHost, $Db, $currentDate)
            
            $backupPath = "S:\manual-backups-from-webapp\"
            $backupFilename = "DB-Backup-${Db}_${currentDate}.bak"
            
            Write-Verbose "Remote: Backup path: $backupPath"
            Write-Verbose "Remote: Backup filename: $backupFilename"
            Write-Verbose "Remote: Checking if path exists..."
            
            if (-not (Test-Path $backupPath)) {
                return "ERROR: Backup path does not exist: $backupPath"
            }
            
            Write-Verbose "Remote: Path exists. Starting backup..."
            
            try {
                Backup-SqlDatabase `
                    -ServerInstance $DbHost `
                    -Database $Db `
                    -BackupFile "${backupPath}${backupFilename}" `
                    -CopyOnly `
                    -Initialize `
                    -Checksum `
                    -ErrorAction Stop
                
                Write-Verbose "Remote: Backup completed successfully"
                return "SUCCESS"
            }
            catch {
                Write-Host "Remote: Backup failed with error: $_"
                return "ERROR: $_"
            }
        } -ArgumentList $DbHost, $DbName, (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") -ErrorAction Stop
        
        Write-Verbose "Invoke-Command completed"
        Write-Verbose "Result: $result"
        
        if ($result -match '^SUCCESS') {
            Write-Verbose "Backup successful, returning 0"
            return 0
        }
        else {
            Write-Host "ERROR: Backup failed - $result" -ForegroundColor Red
            return 1
        }
    }
    catch {
        Write-Host "ERROR: Invoke-Command failed: $_" -ForegroundColor Red
        Write-Verbose "Exception type: $($_.Exception.GetType().Name)"
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
        # Build complete API URL with filter
        $apiUrl = "http://localhost:5001/api/data?database%2Fname=${DbName}&exactmatch=true"
        
        Write-Verbose "API URL: $apiUrl"
        
        # Get configuration from API using complete URL
        $jsonData = Get-CMIConfigData -Url $apiUrl
        
        Write-Verbose "API returned: $($jsonData -ne $null)"
        Write-Verbose "Type: $($jsonData.GetType().Name)"
        
        if (-not $jsonData) {
            Write-Host "ERROR: No configuration found for database: $DbName" -ForegroundColor Red
            return 1
        }
        
        # API returns an array - get first element
        $config = $null
        if ($jsonData -is [array]) {
            Write-Verbose "Result is array with $($jsonData.Count) elements"
            if ($jsonData.Count -gt 0) {
                $config = $jsonData[0]
            }
        }
        else {
            Write-Verbose "Result is single object"
            $config = $jsonData
        }
        
        if (-not $config) {
            Write-Host "ERROR: Empty configuration returned for database: $DbName" -ForegroundColor Red
            return 1
        }
        
        # Extract service name and hostname (APP server!)
        $serviceName = $config.app.servicename._text
        $hostname = $config.app.host._text
        
        Write-Verbose "Service: '$serviceName'"
        Write-Verbose "Hostname: '$hostname'"
        
        if ([string]::IsNullOrEmpty($serviceName) -or [string]::IsNullOrEmpty($hostname)) {
            Write-Host "ERROR: Missing service name or hostname for database: $DbName" -ForegroundColor Red
            return 1
        }
        
        # Call service control script
        Write-Host "INFO: Calling service control for '$serviceName' on '$hostname' (Action: $Action)" -ForegroundColor Green
        & "$PSScriptRoot\cmi-control-single-service.ps1" `
            -Service $serviceName `
            -Action $Action `
            -Hostname $hostname
        
        $exitCode = $LASTEXITCODE
        Write-Verbose "Service control exit code: $exitCode"
        
        return $exitCode
    }
    catch {
        Write-Host "ERROR: Failed to control CMI service: $_" -ForegroundColor Red
        Write-Verbose "Exception type: $($_.Exception.GetType().Name)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return 1
    }
}

function Check-CMIServiceStatus {
    <#
    .SYNOPSIS
        Check if CMI service is running for a database
    .DESCRIPTION
        Queries the CMI Config API to find the service, then checks its status
    .OUTPUTS
        0 = Service is running
        1 = Service is stopped
        2 = Error checking status
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DbName
    )
    
    try {
        # Build complete API URL with filter
        $apiUrl = "http://localhost:5001/api/data?database%2Fname=${DbName}&exactmatch=true"
        
        # Get configuration from API
        $jsonData = Get-CMIConfigData -Url $apiUrl
        
        if (-not $jsonData) {
            Write-Host "ERROR: No configuration found for database: $DbName" -ForegroundColor Red
            return 2
        }
        
        # Get config object
        $config = $null
        if ($jsonData -is [array]) {
            if ($jsonData.Count -gt 0) {
                $config = $jsonData[0]
            }
        }
        else {
            $config = $jsonData
        }
        
        if (-not $config) {
            Write-Host "ERROR: Empty configuration returned" -ForegroundColor Red
            return 2
        }
        
        # Extract service name and hostname
        $serviceName = $config.app.servicename._text
        $hostname = $config.app.host._text
        
        if ([string]::IsNullOrEmpty($serviceName) -or [string]::IsNullOrEmpty($hostname)) {
            Write-Host "ERROR: Missing service name or hostname" -ForegroundColor Red
            return 2
        }
        
        Write-Verbose "Checking status of '$serviceName' on '$hostname'"
        
        # Check service status on remote host
        $status = Invoke-Command -ComputerName $hostname -ScriptBlock {
            param($ServiceName)
            $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($svc) {
                return $svc.Status.ToString()
            }
            else {
                return "NotFound"
            }
        } -ArgumentList $serviceName -ErrorAction Stop
        
        Write-Verbose "Service status: $status"
        
        if ($status -eq "Running") {
            return 0
        }
        elseif ($status -eq "Stopped") {
            return 1
        }
        else {
            Write-Host "WARNING: Service status is '$status'" -ForegroundColor Yellow
            return 1  # Treat as stopped
        }
    }
    catch {
        Write-Host "ERROR: Failed to check service status: $_" -ForegroundColor Red
        return 2
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
        
        Write-Host "INFO: Starting backup process for $Database on $DbHost" -ForegroundColor Green
        
        # Check if service is running and stop it if needed
        $serviceWasRunning = $false
        $checkResult = Check-CMIServiceStatus -DbName $Database
        
        if ($checkResult -eq 0) {
            # Service is running - need to stop it
            Write-Host "INFO: Service is running. Stopping service..." -ForegroundColor Yellow
            $serviceWasRunning = $true
            
            $stopResult = Start-StopCMIService -DbName $Database -Action "stop"
            if ($stopResult -ne 0) {
                Write-Output "ERROR: Failed to stop CMI service"
                exit 1
            }
            Write-Host "INFO: Service stopped successfully" -ForegroundColor Green
        }
        elseif ($checkResult -eq 1) {
            # Service is not running
            Write-Host "INFO: Service is already stopped. Proceeding with backup..." -ForegroundColor Yellow
        }
        else {
            # Error checking service status
            Write-Output "ERROR: Failed to check service status"
            exit 1
        }
        
        # Create backup (on DB server)
        Write-Host "INFO: Creating database backup..." -ForegroundColor Green
        $backupResult = Invoke-DatabaseBackup -DbName $Database -DbHost $DbHost
        
        if ($backupResult -ne 0) {
            Write-Host "ERROR: Backup failed!" -ForegroundColor Red
            
            # If we stopped the service, try to start it again even if backup failed
            if ($serviceWasRunning) {
                Write-Host "WARNING: Attempting to restart service after backup failure..." -ForegroundColor Yellow
                Start-StopCMIService -DbName $Database -Action "start" | Out-Null
            }
            exit $backupResult
        }
        
        Write-Host "INFO: Backup completed successfully" -ForegroundColor Green
        
        # Start service only if we stopped it
        if ($serviceWasRunning) {
            Write-Host "INFO: Restarting service..." -ForegroundColor Yellow
            $startResult = Start-StopCMIService -DbName $Database -Action "start"
            
            if ($startResult -ne 0) {
                Write-Output "ERROR: Failed to restart CMI service after backup!"
                exit 1
            }
            Write-Host "INFO: Service restarted successfully" -ForegroundColor Green
        }
        else {
            Write-Host "INFO: Service was not running before backup. Leaving it stopped." -ForegroundColor Yellow
        }
        
        Write-Host "SUCCESS: Backup process completed" -ForegroundColor Green
        Write-Output "SUCCESS"  # For Python/JavaScript parsing
        exit 0
    }
    
    default {
        Write-Output (@{ error = "Invalid job type: $Job" } | ConvertTo-Json -Compress)
        exit 1
    }
}
