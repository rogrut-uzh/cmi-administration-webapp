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
$targetDirectory = "D:\cmi-log-files"
$filesFound = $false  # Initialize flag to check if files are found

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
        $filesFound = $true  # Mark as true if files are found
        $sess = New-PSSession -ComputerName $apphost
        if ($sess) {
            foreach ($file in $files) {
                $destination = Join-Path -Path $targetDirectory -ChildPath $file.NewName
                Write-Host "Copying $($file.FullName) from $apphost to $destination" *> $null
                Copy-Item -FromSession $sess -Path $file.FullName -Destination $destination
            }
            Remove-PSSession -Session $sess
        } else {
            Write-Error "Failed to establish a session with $apphost"
        }
    } else {
        Write-Host "No files found for date '$Date' on host $apphost" # using write-host because it's something to display in the console but not in python.
    }
}

# Check if files were found
if ($filesFound) {
    Write-Output "Log files downloaded successfully." # using write-output because that's a message delivered to python
    Start-Process explorer.exe -ArgumentList $targetDirectory
    exit 0
} else {
    Write-Error "No files found for the specified date '$Date' in any mandant."
    exit 2
}