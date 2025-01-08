###################
# cmi-download-log-files.ps1 #
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
$allFiles = @()  # Initialize an array to store file metadata and content

function Get-CMI-Config-Data {
    param (
        [string]$Env,
        [string]$App
    )
    $Url = "${ApiUrl}/${App}/${Env}"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

# Validate parameters
if (-not $Date -or -not $Env) {
    Write-Error "Both -Date and -Env parameters are required."
    exit 1
}

# Ensure the target directory exists, and create if nescessary
if (-not (Test-Path -Path $targetDirectory)) {
    New-Item -ItemType Directory -Path $targetDirectory
}

# Fetch configuration data
$elements = Get-CMI-Config-Data -Env $Env -App "cmi"
$elements += Get-CMI-Config-Data -Env $Env -App "ais"

foreach ($ele in $elements) {
    $logPath = $ele.app.installpath
	$logPath = "${logPath}\Trace"
    $shortName = $ele.nameshort
    $apphost = $ele.app.host
    Write-Host "Processing logs on host: $apphost, path: $logPath" *> $null

    # Use PowerShell Remoting to fetch log files from the remote host
    $remoteCommand = {
        param ($logPath, $date, $shortName)
        $f = Get-ChildItem -Path $logPath -Filter "*$date*.log" -ErrorAction SilentlyContinue

        if ($f) {
            $f | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    NewName  = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
                }
            }
        } else {
            return @()  # Return empty array if no files are found
        }
    }

    # Invoke the remote command and retrieve file details
    $files = Invoke-Command -ComputerName $apphost -ScriptBlock $remoteCommand -ArgumentList $logPath, $Date, $shortName
	
    if ($files -and $files.Count -gt 0) {
        foreach ($file in $files) {
            $fileBytes = Invoke-Command -ComputerName $apphost -ScriptBlock {
                param ($filePath)
                Get-Content -Path $filePath -Encoding Byte
            } -ArgumentList $file.FullName

            $encodedContent = [Convert]::ToBase64String($fileBytes)
            $allFiles += [PSCustomObject]@{
                FileName = $file.NewName
                Content  = $encodedContent
            }
        }
    } else {
        Write-Host "No files found for date '$Date' on host $apphost" *> $null
    }
}

# Output the results as JSON to the Python app
Write-Output ($allFiles | ConvertTo-Json -Depth 10)
exit 0