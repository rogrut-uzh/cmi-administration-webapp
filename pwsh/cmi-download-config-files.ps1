<#
.SYNOPSIS
    Download all CMI MetaTool.ini config files from all mandants
.DESCRIPTION
    Downloads MetaTool.ini, install_service.bat, and uninstall_service.bat
    from all CMI and AIS mandants (prod and test) and returns as ZIP file
#>

param()

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# Temporary path for file collection
$tempPath = "C:\temp\MandantenFiles"
if (-Not (Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
}

# Fetch all configuration data
try {
    $mandanten = Get-CMIConfigData
}
catch {
    Write-Error "Failed to fetch configuration data: $_"
    exit 1
}

# Process each mandant
foreach ($mandant in $mandanten) {
    $computer = $mandant.app.host._text
    $installPath = $mandant.app.installpath._text
    $leafName = Split-Path -Path $installPath -Leaf
    
    # Determine environment (test or prod)
    if ($installPath -match " Test") {
        $envFolder = "test"
    }
    else {
        $envFolder = "prod"
    }
    
    # Files to download
    $filesToDownload = @(
        "$installPath\Client\MetaTool.ini",
        "$installPath\Server\MetaTool.ini",
        "$installPath\Server\install_service.bat",
        "$installPath\Server\uninstall_service.bat"
    )
    
    # Create PSSession
    try {
        $session = New-PSSession -ComputerName $computer -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to create session to ${computer}: $_"
        continue
    }
    
    # Download each file
    foreach ($file in $filesToDownload) {
        # Determine subfolder (Client, Server, or Misc)
        if ($file -match "\\Client\\") {
            $subfolder = "Client"
        }
        elseif ($file -match "\\Server\\") {
            $subfolder = "Server"
        }
        else {
            $subfolder = "Misc"
        }
        
        # Create destination folder
        $destinationFolder = Join-Path -Path $tempPath -ChildPath "${envFolder}\${leafName}\${subfolder}"
        if (-Not (Test-Path $destinationFolder)) {
            New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        }
        
        # Copy file from remote host
        $fileName = Split-Path -Path $file -Leaf
        $destinationPath = Join-Path -Path $destinationFolder -ChildPath $fileName
        
        try {
            Copy-Item `
                -FromSession $session `
                -Path $file `
                -Destination $destinationPath `
                -ErrorAction Stop
        }
        catch {
            # Silently skip missing files
            continue
        }
    }
    
    # Close session
    Remove-PSSession $session
}

# Create ZIP archive
$zipPath = "C:\temp\MandantenFiles.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

try {
    Compress-Archive -Path "$tempPath\*" -DestinationPath $zipPath -ErrorAction Stop
}
catch {
    Write-Error "Failed to create ZIP archive: $_"
    exit 1
}

# Read ZIP and convert to Base64
try {
    $bytes = [System.IO.File]::ReadAllBytes($zipPath)
    $base64Output = [Convert]::ToBase64String($bytes)
    Write-Output $base64Output
    exit 0
}
catch {
    Write-Error "Failed to read ZIP file: $_"
    exit 1
}
finally {
    # Cleanup
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
}