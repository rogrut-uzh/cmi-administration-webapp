<#
.SYNOPSIS
    Download CMI log files for a specific date and environment
.PARAMETER Date
    Date in format yyyymmdd
.PARAMETER Env
    Environment (test or prod)
#>

param (
    [Parameter(Mandatory)]
    [string]$Date,
    
    [Parameter(Mandatory)]
    [ValidateSet("test", "prod")]
    [string]$Env
)

# Import common module
Import-Module "$PSScriptRoot\Common.psm1" -Force

# Initialize environment
Initialize-CMIEnvironment

# Fetch configuration data
try {
    $mandanten = @()
    $mandanten += Get-CMIConfigData -App "cmi" -Environment $Env
    $mandanten += Get-CMIConfigData -App "ais" -Environment $Env
}
catch {
    Write-Error "Failed to fetch configuration data: $_"
    exit 1
}

# Script block to execute on remote host
$remoteCommand = {
    param ($logPath, $date, $shortName)
    
    # Use the Get-FileBytes function from Common module
    # We need to define it here because the remote session doesn't have access to the module
    function Get-FileBytes {
        param([string]$Path)
        $fs = $null
        try {
            $fs = [System.IO.File]::Open(
                $Path, 
                [System.IO.FileMode]::Open, 
                [System.IO.FileAccess]::Read, 
                [System.IO.FileShare]::ReadWrite
            )
            
            $bytes = New-Object byte[] $fs.Length
            [void]$fs.Read($bytes, 0, $bytes.Length)
            
            return $bytes
        }
        catch {
            Write-Error "Failed to read file bytes from $Path: $_"
            throw
        }
        finally {
            if ($fs) { $fs.Close() }
        }
    }
    
    if (Test-Path -Path $logPath) {
        $files = Get-ChildItem -Path $logPath -Filter "*$date*.log" -ErrorAction SilentlyContinue
        
        if ($files) {
            $files | ForEach-Object {
                try {
                    $fileBytes = Get-FileBytes -Path $_.FullName
                    [PSCustomObject]@{
                        FullName = $_.FullName
                        NewName  = "{0}_{1}{2}" -f $_.BaseName, $shortName, $_.Extension
                        Content  = [Convert]::ToBase64String($fileBytes)
                    }
                }
                catch {
                    return $null
                }
            } | Where-Object { $_ -ne $null }
        }
    }
}

# Collect log files from all mandants
$allLogFiles = @()

foreach ($mandant in $mandanten) {
    $logPath = Join-Path $mandant.app.installpath._text "Trace"
    $shortName = $mandant.mand._text
    $apphost = $mandant.app.host._text
    
    try {
        $files = Invoke-Command `
            -ComputerName $apphost `
            -ScriptBlock $remoteCommand `
            -ArgumentList $logPath, $Date, $shortName `
            -ErrorAction Stop
        
        if ($files) {
            $allLogFiles += $files
        }
    }
    catch {
        Write-Warning "Failed to fetch logs from ${apphost}: $_"
        continue
    }
}

# Output results
if ($allLogFiles.Count -eq 0) {
    Write-Error "No files found"
    exit 2
}

try {
    $compressed = $allLogFiles | ConvertTo-Base64Gzip
    Write-Output $compressed
    exit 0
}
catch {
    Write-Error "Failed to compress output: $_"
    exit 1
}
