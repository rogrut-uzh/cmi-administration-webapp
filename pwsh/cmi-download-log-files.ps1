###################
# cmi-download-log-files.ps1 #
###################
param (
    [string]$Date,
    [string]$Env
)

$ErrorActionPreference = "Stop"  # Stop on errors
$VerbosePreference = "SilentlyContinue"  # Suppress verbose logs

$ApiUrl = "http://localhost:5001/api/data"
$allFiles = @()  # Initialize an array to store file metadata and content

function Get-CMI-Config-Data {
    param (
        [string]$Env,
        [string]$App
    )
    $Url = "${ApiUrl}/${App}/${Env}"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get -ErrorAction Stop).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

# Validate parameters
if (-not $Date -or -not $Env) {
    Write-Error "Both -Date and -Env parameters are required."
    exit 1
}

# Fetch configuration data
$elements = Get-CMI-Config-Data -Env $Env -App "cmi"
$elements += Get-CMI-Config-Data -Env $Env -App "ais"


foreach ($ele in $elements) {
    $logPath = $ele.app.installpath
    $logPath = "${logPath}\Trace"
    $shortName = $ele.nameshort
    $apphost = $ele.app.host
    Write-Host "Processing logs on host: $apphost, path: $logPath"


# Define the remote script block
    $remoteCommand = {
        param ($logPath, $date, $shortName)
        Write-Host "Checking path: $logPath"
        if (Test-Path -Path $logPath) {
            $files = Get-ChildItem -Path "$logPath" -Filter "*$date*.log" -ErrorAction SilentlyContinue
            if ($files) {
                $files | ForEach-Object {
                    [PSCustomObject]@{
                        FullName = $_.FullName
                        NewName  = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
                        Content  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($_.FullName))
                    }
                }
            } else {
                Write-Warning "No files found in path $logPath for date $date"
                return @()
            }
        } else {
            Write-Warning "Path does not exist: $logPath"
            return @()
        }
    }
	
	
	
	
	
# Invoke the remote command
    try {
        $files = Invoke-Command -ComputerName $apphost -ScriptBlock $remoteCommand -ArgumentList $logPath, $Date, $shortName
		$files
		exit 0
    } catch {
        Write-Error "Failed to execute remote command on ${apphost}: $_"
        continue
    }

    # Process the returned files
    if ($files -and $files.Count -gt 0) {
		$allFiles += $files
    } else {
        Write-Warning "No files found for date '$Date' on host $apphost"
    }
}

# Output the results as JSON
try {
    $jsonOutput = $allFiles | ConvertTo-Json -Depth 10
    Write-Output $jsonOutput
    exit 0
} catch {
    Write-Error "JSON conversion failed: $_"
    exit 1
}