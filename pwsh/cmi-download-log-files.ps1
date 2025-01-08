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


# Fetch configuration data
$elements = Get-CMI-Config-Data -Env $Env -App "cmi"
$elements += Get-CMI-Config-Data -Env $Env -App "ais"




#$filepath = "C:\Program Files\CMI AG\CMI Test\BM 22.0.10\Trace\Server-20241229.log"
#$destination = "d:\test\file.txt"
#$apphost = "ziaxiomatap02"
#
#$sess = New-PSSession -ComputerName $apphost
#if ($sess) {
#    Copy-Item -FromSession $sess -Path $filepath -Destination $destination
#    Remove-PSSession -Session $sess
#    # Read the file content locally
#    $result = Get-Content -Path $destination -AsByteStream
#    Write-Host "File content length: $($result.Length)"
#} else {
#    Write-Error "Failed to establish a session with $apphost"
#}
#exit 0





foreach ($ele in $elements) {
    $logPath = $ele.app.installpath
    $logPath = "${logPath}\Trace"
    $shortName = $ele.nameshort
    $apphost = $ele.app.host
    Write-Host "Processing logs on host: $apphost, path: $logPath"

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
        try {
            foreach ($file in $files) {
                Write-Host "Processing file: $($file.FullName) on host $apphost"

                # Use Get-Content -AsByteStream to read the file content
#$fileBytes = Invoke-Command -ComputerName $apphost -ScriptBlock {
#    param ($filePath)
#    if (Test-Path -Path $filePath) {
#        & 'pwsh.exe' -Command {
#            [System.IO.File]::ReadAllBytes($filePath)
#        }
#    } else {
#        throw "File not found: $filePath"
#    }
#} -ArgumentList $file.FullName


$fileBytes = Invoke-Command -ComputerName $apphost -ScriptBlock {
    param ($filePath)
    if (Test-Path -Path $filePath) {
        Write-Host "File exists: $filePath"

        # Use PowerShell Core with explicit argument for the file path
        & 'pwsh.exe' -Command "& { Get-Content -Path '$filePath' -AsByteStream }"
        
    } else {
        throw "File not found: $filePath"
    }
} -ArgumentList $file.FullName
				
				
				

                if ($fileBytes) {
                    # Convert the binary content to Base64
                    $encodedContent = [Convert]::ToBase64String($fileBytes)
                    $allFiles += [PSCustomObject]@{
                        FileName = $file.NewName
                        Content  = $encodedContent
                    }
                } else {
                    Write-Error "Failed to read file content for: $($file.FullName)"
                }
            }
        } catch {
            Write-Output "files foreach failed: $_"
            exit 1
        }
    } else {
        Write-Output "No files found for date '$Date' on host $apphost"
        exit 2
    }
}

# Output the results as JSON to the Python app
Write-Output ($allFiles | ConvertTo-Json -Depth 10)

exit 0


