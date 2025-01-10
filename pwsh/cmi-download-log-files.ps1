###################
# cmi-download-log-files.ps1 #
###################
param (
    [string]$Date,
    [string]$Env
)


# make sure only the json is being outputted otherwise the python flask app will not recognize the response as json and will fail


[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"
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

    $remoteCommand = {
        param ($logPath, $date, $shortName)
        #Write-Host "Checking path: $logPath"
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
                # No files found in path $logPath for date $date
                return @()
            }
        } else {
            # Path does not exist: $logPath
            return @()
        }
    }
    
    # Invoke the remote command
    try {
        $files = Invoke-Command -ComputerName $apphost -ScriptBlock $remoteCommand -ArgumentList $logPath, $Date, $shortName
    } catch {
        Write-Error "Failed to execute remote command on ${apphost}: $_"
        continue
    }

    # Process the returned files
    if ($files -and $files.Count -gt 0) {
        $allFiles += $files
    } 
}


if (-not ($allFiles.Count -eq 0)) {
	try {
		$jsonOutput = $allFiles | ConvertTo-Json -Depth 10 -Compress
		# Convert JSON to bytes
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonOutput)

		# Create a memory stream for compressed data
		$memoryStream = [System.IO.MemoryStream]::new()

		# Use GZipStream for compression
		$gzipStream = [System.IO.Compression.GZipStream]::new($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
		$gzipStream.Write($bytes, 0, $bytes.Length)
		$gzipStream.Close()

		# Get the compressed data
		$compressedData = $memoryStream.ToArray()

		# Convert compressed data to Base64
		$base64Output = [Convert]::ToBase64String($compressedData)

		# Ensure proper Base64 padding
		$paddedBase64Output = $base64Output.PadRight((([math]::Ceiling($base64Output.Length / 4)) * 4), '=')

		Write-Output $paddedBase64Output
		exit 0
	} catch {
		Write-Output "Failed to compress or encode JSON: $_"
		exit 1
	}
} else {
	Write-Error "No file found"
	exit 2
}