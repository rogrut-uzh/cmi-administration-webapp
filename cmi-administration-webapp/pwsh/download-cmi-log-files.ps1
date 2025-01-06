###################
# download-cmi-log-files.ps1 #
###################
# 
# Für Aufruf in der Webapp gedacht. Download der Log-Dateien von CMI in einen vordefinierten Ordner.
#
# Autor: rogrut / Januar 2025
#
###################
param (
    [string]$Date,
    [string]$Env
)
$ApiUrl = "http://localhost:5001/api/data"
$targetDirectory = "D:\cmi-log-files"

function Get-CMI-Config-Data {
    param (
        [string]$Env
    )
    $Url = "${ApiUrl}/cmi/${Env}"
    Write-Host "Calling $Url"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

$elements = Get-CMI-Config-Data -Env $Env

if (-not (Test-Path -Path $targetDirectory)) {
    New-Item -ItemType Directory -Path $targetDirectory
}

foreach ($ele in $elements) {
    $logPath = "${ele.app.installpath}\Trace"
    $shortName = $ele.nameshort
    $host = $ele.app.host

    Get-ChildItem -Path $logPath -Filter "*$Date*.log" | ForEach-Object {
        $newName = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
        $destination = Join-Path -Path $targetDirectory -ChildPath $newName
        Copy-Item -Path $_.FullName -Destination $destination
    }
}

foreach ($ele in $elements) {
    $logPath = "${ele.app.installpath}\Trace"
    $shortName = $ele.nameshort
    $host = $ele.app.host

    Write-Host "Processing logs on host: $host, path: $logPath"

    # Use PowerShell Remoting to fetch log files from the remote host
    $remoteCommand = {
        param ($logPath, $date, $shortName, $targetDirectory)
        
        # Create the destination directory if it doesn't exist
        if (-not (Test-Path -Path $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory
        }

        # Get log files matching the date and copy them locally
        Get-ChildItem -Path $logPath -Filter "*$date*.log" | ForEach-Object {
            $newName = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
            $destination = Join-Path -Path $targetDirectory -ChildPath $newName
            Copy-Item -Path $_.FullName -Destination $destination
        }
    }

    # Invoke the command on the remote host
    try {
        Invoke-Command -ComputerName $host -ScriptBlock $remoteCommand -ArgumentList $logPath, $Date, $shortName, $targetDirectory
    } catch {
        Write-Error "Failed to process logs for $host. Error: $_"
    }
}