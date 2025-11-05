<#
.SYNOPSIS
    Common PowerShell module for CMI Administration scripts
.DESCRIPTION
    Provides shared functions for proxy configuration, API calls, encoding, etc.
#>

# ============================================
# Configuration
# ============================================

$script:CMI_API_URL = "http://localhost:5001/api/data"
$script:PROXY_URL = "http://zoneproxy.zi.uzh.ch:8080"

# ============================================
# Environment Initialization
# ============================================

function Initialize-CMIEnvironment {
    <#
    .SYNOPSIS
        Initialize common environment settings for CMI scripts
    .DESCRIPTION
        Sets UTF-8 encoding, proxy configuration, and error preferences
    #>
    [CmdletBinding()]
    param()
    
    # Set UTF-8 encoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Configure proxy
    $env:NO_PROXY = "127.0.0.1,localhost,::1"
    $env:HTTP_PROXY = $script:PROXY_URL
    $env:HTTPS_PROXY = $script:PROXY_URL
    
    # Set error preferences
    $script:ErrorActionPreference = "Stop"
    $script:VerbosePreference = "SilentlyContinue"
    
    Write-Verbose "CMI Environment initialized"
}

# ============================================
# API Functions
# ============================================

function Get-CMIConfigData {
    <#
    .SYNOPSIS
        Fetch CMI configuration data from REST API
    .PARAMETER Url
        Optional custom URL (defaults to base API URL)
    .PARAMETER App
        Application type (cmi or ais)
    .PARAMETER Environment
        Environment (prod or test)
    .PARAMETER Filter
        Additional filter parameters
    .EXAMPLE
        Get-CMIConfigData -App "cmi" -Environment "prod"
    .EXAMPLE
        Get-CMIConfigData -Url "http://localhost:5001/api/data/cmi/prod"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Url,
        
        [Parameter()]
        [ValidateSet("cmi", "ais")]
        [string]$App,
        
        [Parameter()]
        [ValidateSet("prod", "test")]
        [string]$Environment,
        
        [Parameter()]
        [string]$Filter
    )
    
    # Build URL
    if (-not $Url) {
        $Url = $script:CMI_API_URL
        if ($App) {
            $Url += "/$App"
        }
        if ($Environment) {
            $Url += "/$Environment"
        }
        if ($Filter) {
            $Url += "?$Filter"
        }
    }
    
    Write-Verbose "Fetching data from: $Url"
    
    try {
        # Use HttpClient to bypass proxy for localhost
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.UseProxy = $false
        $handler.UseDefaultCredentials = $true
        
        $client = [System.Net.Http.HttpClient]::new($handler)
        $response = $client.GetAsync($Url).Result
        
        if (-not $response.IsSuccessStatusCode) {
            throw "API request failed with status: $($response.StatusCode)"
        }
        
        $rawJson = $response.Content.ReadAsStringAsync().Result
        $parsedJson = $rawJson | ConvertFrom-Json
        
        return $parsedJson
    }
    catch {
        Write-Error "Failed to fetch CMI config data: $_"
        throw
    }
    finally {
        if ($client) { $client.Dispose() }
        if ($handler) { $handler.Dispose() }
    }
}

# ============================================
# Encoding/Compression Functions
# ============================================

function ConvertTo-Base64Gzip {
    <#
    .SYNOPSIS
        Compress and encode data as Base64 Gzip
    .PARAMETER InputObject
        Object to compress (will be converted to JSON)
    .PARAMETER JsonDepth
        JSON serialization depth (default: 10)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,
        
        [Parameter()]
        [int]$JsonDepth = 10
    )
    
    process {
        try {
            # Convert to JSON
            $jsonOutput = $InputObject | ConvertTo-Json -Depth $JsonDepth -Compress
            
            # Convert to bytes
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonOutput)
            
            # Compress with GZip
            $memoryStream = [System.IO.MemoryStream]::new()
            $gzipStream = [System.IO.Compression.GZipStream]::new(
                $memoryStream, 
                [System.IO.Compression.CompressionMode]::Compress
            )
            $gzipStream.Write($bytes, 0, $bytes.Length)
            $gzipStream.Close()
            
            # Convert to Base64
            $compressedData = $memoryStream.ToArray()
            $base64Output = [Convert]::ToBase64String($compressedData)
            
            # Ensure proper padding
            $paddedOutput = $base64Output.PadRight(
                (([math]::Ceiling($base64Output.Length / 4)) * 4), 
                '='
            )
            
            return $paddedOutput
        }
        catch {
            Write-Error "Failed to compress and encode data: $_"
            throw
        }
        finally {
            if ($gzipStream) { $gzipStream.Dispose() }
            if ($memoryStream) { $memoryStream.Dispose() }
        }
    }
}

function ConvertTo-Base64 {
    <#
    .SYNOPSIS
        Encode data as Base64
    .PARAMETER Data
        Byte array to encode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )
    
    return [Convert]::ToBase64String($Data)
}

# ============================================
# File Operations
# ============================================

function Get-FileBytes {
    <#
    .SYNOPSIS
        Read file bytes with shared read access
    .PARAMETER Path
        Path to the file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
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
        Write-Error "Failed to read file bytes from $Path`: $_"
        throw
    }
    finally {
        if ($fs) { $fs.Close() }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-CMIEnvironment',
    'Get-CMIConfigData',
    'ConvertTo-Base64Gzip',
    'ConvertTo-Base64',
    'Get-FileBytes'
)