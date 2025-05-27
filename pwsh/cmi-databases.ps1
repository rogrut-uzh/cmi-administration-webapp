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
<#
invoke-webrequest geht nicht bei localhost urls.

PS D:\gitlab\cmi-administration-webapp\pwsh> Invoke-WebRequest -Uri http://localhost:5001/api/data?database/name=star_uaz -Method Get -ErrorAction Stop -UseDefaultCredentials -AllowUnencryptedAuthentication -Proxy $null
Invoke-WebRequest:



ERROR: The requested URL could not be retrieved



ERROR
The requested URL could not be retrieved




The following error was encountered while trying to retrieve the URL: http://localhost:5001/api/data?


Access Denied.


Access control configuration prevents your request from being allowed at this time. Please contact your service provider if you feel this is incorrect.

Your cache administrator is root.



Generated Tue, 27 May 2025 20:43:07 GMT by zoneproxy.zi.uzh.ch (squid/4.15)



PowerShells -Proxy $null wird leider nicht immer vom zugrundeliegenden .NET-HTTP-Stack respektiert – deine Anfrage landet also weiterhin im Squid. Deshalb kommt weiter der 403 “Access Denied” von zoneproxy. Wir müssen den Proxy wirklich komplett umgehen und gleichzeitig den Slash im Query-Parameter escapen. Probiere es so:



daher folgende alternative:
#>
		# HttpClient-Handler mit deaktiviertem Proxy und Default-Credentials:
		$handler = [System.Net.Http.HttpClientHandler]::new()
		$handler.UseProxy              = $false
		$handler.UseDefaultCredentials = $true

		$client = [System.Net.Http.HttpClient]::new($handler)

		# Request absenden
		$response = $client.GetAsync($u).Result
		
        $RawJson = $response.Content.ReadAsStringAsync().Result

		
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
    
    try {
        $Result = Invoke-Command -ComputerName $DbHost -ScriptBlock {
            param($DbHost, $Db, $currentDate)
            $backupPath = "S:\manual-backups-from-webapp\"
            $backupFilename = "DB-Backup-${Db}_${currentDate}.bak"

            try {
                Backup-SqlDatabase -ServerInstance "$DbHost" -Database $Db -BackupFile "${backupPath}${backupFilename}" -CopyOnly -Initialize -Checksum
                $msg = "SUCCESS"
            }
            catch {
                $msg =  "ERROR: $_"
            }
            
            return $msg
            
        } -ArgumentList $DbHost, $Db, (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") -ErrorAction stop

        write-host $Result # <--- für databases.py Prüfung auf "SUCCESS"
        
        if ($Result -match '^SUCCESS') {
            return 0
        } else {
            return 1
        }
    }
    catch {
        Write-Output "ERROR: Invoke-Command fehlgeschlagen: $_" 
        return 3
    }
}


function CmiAppService {
    param (
        [string]$Db,
        [string]$Action,
        [string]$ApiRoot
    )
    
    # get the CMI service name and the hostname where the CMI service is running
	$ApiUrl = $ApiRoot + '?database%2Fname=' + $Db + '&exactmatch=true'
	
    try {
        $jsonData = Get-CMI-Config-Data -u $ApiUrl
        
        if (($jsonData | Measure-Object).count -lt 1) {
            Write-Output (@{
                error = "Keine Daten gefunden."
            } | ConvertTo-Json -Compress)
            $ReturnCode = 1
        }
        
        $Service = $jsonData.app.servicename._text
        $Hostname = $jsonData.app.host._text
    }

    catch {
        $Hostname = ""
        $Service = "Error: $($_.Exception.Message)"
    }

    # start or stop the service
    & "$PSScriptRoot\cmi-control-single-service.ps1" -Service $Service -Action $Action -Hostname $Hostname
    $ReturnCode = $LASTEXITCODE
    return $ReturnCode
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
    #write-host "stopping..."
    #write-host $CmiAppServiceStatus
    if ($CmiAppServiceStatus -eq 0) {
        $CreateDbBackupStatus = CreateDbBackup -Db $Db -DbHost $DbHost
        #write-host "creating db backup..."
        #write-host $CreateDbBackupStatus
        if ($CreateDbBackupStatus -eq 0) {
            $CmiAppServiceStatus = CmiAppService -Db $Db -Action "start" -ApiRoot $ApiRoot
            #write-host "starting..."
            #write-host $CmiAppServiceStatus
        }
    }
    
} else {
    Write-Output (@{ error = "No valid job defined" } | ConvertTo-Json -Compress)
    exit 1
}

exit 0
