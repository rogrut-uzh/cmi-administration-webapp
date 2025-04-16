param (
    [string]$Job,             # "list" or "backup"
    [string]$Env = $Null,     # "test" or "prod"
    [string]$Db = $Null,
    [string]$DbHost = $Null
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:NO_PROXY = "localhost,127.0.0.1,::1"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"

$ApiRoot = "http://localhost:5001/api/data"

function Get-CMI-Config-Data {
    param (
        [string]$u
    )
	
	try {
		$response = Invoke-WebRequest -Uri $u -Method Get -ErrorAction Stop
	} catch {
		Write-Host "FEHLER:"
		Write-Host $_.Exception.Message

		# Versuche zusätzliche Infos aus dem Fehler zu holen
		if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
			Write-Host "ErrorDetails:"
			Write-Host $_.ErrorDetails.Message
		} elseif ($_.Exception.Response -and $_.Exception.Response.Content) {
			Write-Host "Response Content:"
			Write-Host $_.Exception.Response.Content
		} else {
			Write-Host "Kein weiterer Body verfügbar."
		}
		exit 1
	}
	
	$RawJson = $response.Content
	$ParsedJson = $RawJson | ConvertFrom-Json
	return $ParsedJson
}

function CreateDbList {
    param (
        [string]$Env,
        [string]$ApiRoot
    )
    $dbs = @()
    $jsonData = @()
    
    try {
        $jsonData += Get-CMI-Config-Data -u "${ApiRoot}/cmi/${Env}"
        $jsonData += Get-CMI-Config-Data -u "${ApiRoot}/ais/${Env}"
        if (($jsonData | Measure-Object).count -lt 1) {
            Write-Output (@{
                error = "Keine Daten gefunden."
            } | ConvertTo-Json -Compress)
            exit 1
        }
        if ($jsonData -isnot [System.Collections.IEnumerable]) {
            $jsonData = @($jsonData)
        }
        
        foreach ($item in $jsonData) {
            $namefull = $item.namefull._text
            $dbhost = $item.database.host._text
            $dbname = $item.database.name._text

            $dbs += @{
                namefull = $namefull
                dbhost = $dbhost
                dbname = $dbname
            }
        }

    }
    catch {
        $dbs = @(
            @{
                namefull = ""
                dbhost = "Error: $($_.Exception.Message)"
                dbname = ""
            }
        )
    }
    
    return ($dbs | ConvertTo-Json -Depth 5 -Compress)
}


function CreateDbBackup {
    param (
        [string]$Db,
        [string]$DbHost
    )
        
    Invoke-Command -ComputerName $DbHost -ScriptBlock {
        param($DbHost, $Db, $currentDate)
        $backupPath = "S:\manual-backups-from-webapp\"
        $backupFilename = "DB-Backup-${Db}_${currentDate}.bak"

        try {
            #Write-Output "STARTE BACKUP"
            Backup-SqlDatabase -ServerInstance "$DbHost" -Database $Db -BackupFile "${backupPath}${backupFilename}" -CopyOnly -Initialize -Checksum
            #Backup-SqlDatabase -ServerInstance "$DbHost" -Database $Db -BackupFile "${backupPath}${backupFilename}" -CopyOnly -Initialize -Checksum -PercentCompleteNotification 10
            
            Write-Output "SUCCESS"
            exit 0
        }
        catch {
            Write-Output "ERROR: $_"
            exit 1
        }
    } -ArgumentList $DbHost, $Db, (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
}


function CmiAppService {
    param (
        [string]$Db,
        [string]$Action,
        [string]$ApiRoot
    )
    
    # get the CMI service name and the hostname where the CMI service is running
    try {
        $jsonData = Get-CMI-Config-Data -u "${ApiRoot}?database/name=${Db}"
        
        if (($jsonData | Measure-Object).count -lt 1) {
            Write-Output (@{
                error = "Keine Daten gefunden."
            } | ConvertTo-Json -Compress)
            exit 1
        }
        $jsonData = @($jsonData)
        
        $Service = $jsonData.app.servicename._text
        $Hostname = $jsonData.app.host._text
    }
    catch {
        $Hostname = ""
        $Service = "Error: $($_.Exception.Message)"
    }
    
    # start or stop the service
    & "$PSScriptRoot\cmi-control-single-service.ps1" -Service $Service -Action $Action -Hostname $Hostname
    return $LASTEXITCODE
    
}


# run
if ($Job -eq "list") {
    if ($Env -eq $Null) {
        Write-Output (@{ error = "No environment defined" } | ConvertTo-Json -Compress)
        exit 1
    }
    Write-Output (CreateDbList -Env $Env -ApiRoot $ApiRoot)
    
} elseif ($Job -eq "backup") {
    if ($Db -eq $Null) {
        Write-Output (@{ error = "No database defined" } | ConvertTo-Json -Compress)
        exit 1
    }
    if ($DbHost -eq $Null) {
        Write-Output (@{ error = "No database host defined" } | ConvertTo-Json -Compress)
        exit 1
    }
    
    $CmiAppServiceStatus = CmiAppService -Db $Db -Action "stop" -ApiRoot $ApiRoot
    if ($CmiAppServiceStatus -eq 0) {
        CreateDbBackup -Db $Db -DbHost $DbHost
        if ($LASTEXITCODE -eq 0) {
            $CmiAppServiceStatus = CmiAppService -Db $Db -Action "start" -ApiRoot $ApiRoot
        }
    }
    
} else {
    Write-Output (@{ error = "No valid job defined" } | ConvertTo-Json -Compress)
    exit 1
}

exit 0
