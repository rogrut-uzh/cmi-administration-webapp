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
        [string]$Env
    )
    $Url = "${ApiUrl}/cmi/${Env}"
    Write-Host "Calling $Url"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

# Fetch configuration data
$elements = Get-CMI-Config-Data -Env $Env

# Ensure the target directory exists, and create if nescessary
if (-not (Test-Path -Path $targetDirectory)) {
    New-Item -ItemType Directory -Path $targetDirectory
}

foreach ($ele in $elements) {
	$logPath = $ele.app.installpath
    $logPath = "${logPath}\Trace"
    $shortName = $ele.nameshort
    $apphost = $ele.app.host

	Write-Host "Processing logs on host: $apphost, path: $logPath"

    # Use PowerShell Remoting to fetch log files from the remote host
    $remoteCommand = {
        param ($logPath, $date, $shortName)
		
        # Get log files matching the date
        $files = Get-ChildItem -Path $logPath -Filter "*$date*.log" -ErrorAction SilentlyContinue
        if (!$files) {
            return $null  # Return null if no files are found
        }

        # Return file metadata for transfer
        $files | ForEach-Object {
            [PSCustomObject]@{
                FullName = $_.FullName
                NewName  = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
            }
        }
    }

    try {
        # Invoke the remote command and retrieve file details
        $files = Invoke-Command -ComputerName $apphost -ScriptBlock $remoteCommand -ArgumentList $logPath, $Date, $shortName

        if ($files) {
            $filesFound = $true  # Mark as true if files are found
			
			foreach ($file in $files) {
				# Define the local destination
				$destination = Join-Path -Path $targetDirectory -ChildPath $file.NewName
				
				Write-Host "Copying $($file.FullName) from $apphost to $destination"

				# Copy file from the remote host to the local machine
				Copy-Item -FromSession (New-PSSession -ComputerName $apphost) -Path $file.FullName -Destination $destination
			}
			
        } else {
            Write-Host "No files found for date '$Date'"
        }
    } catch {
        Write-Error "Failed to process logs for $apphost. Error: $_"
    }
}
# Check if no files were found
if ($filesFound) {
	Write-Host "Log files downloaded successfully."

	# open windows explorer
	Start-Process explorer.exe -ArgumentList $targetDirectory

	exit 0
} else {
    Write-Host "No files found for the specified date '$Date' in any mandant."
    exit 1
}