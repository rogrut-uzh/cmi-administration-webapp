###################
# cmi-cockpit.ps1 #
###################
# 
# Für Aufruf in der Webapp gedacht. Sammelt Informationen zu den CMI-Installationen.
# 
# Aufruf: 
# ./cmi-cockpit.ps1 
#
# Argumente:
# -App:             "all" für Alle, "cmi" für CMI oder "ais" für die Archivinformationssysteme (inkl. Benutzungsverwaltung"
# -Env:             "all für alle Umgebungen, "prod" für Produktiv-Umgebung, "test" für Testumgebung
# -Query:           
#
# Autor: rogrut / Dezember 2024
#
######################################
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("cmi", "ais", "all")]
    [string]$App,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "prod", "all")]
    [string]$Env,
    
    [Parameter(Mandatory = $false)]
    [string]$Env,
)

# Exit, wenn nicht als admin ausgeführt
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    write-host "run as admin"
    exit 1
}


# Variablen
$ApiUrl = "http://localhost:5001/api/data"
$WindowsServicesList = @()

#Functions
function Get-CMI-Config-Data {
    param (
        # Mandatory parameter
        [Parameter(Mandatory = $true)]
        [string]$Environment
    )
    $Url = "${ApiUrl}/${Environment}"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content
    #ParsedJson = ($RawJson | ConvertFrom-Json) | ConvertTo-Json -Depth 10 -Compress:$false # nur zu testzwecken für die schöne ausgabe am terminal
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}






$elements = Get-CMI-Config-Data -Environment $Env





if (($elements | Measure-Object).count -lt 1) {
    write-host "nothing found."
    exit 1
}

foreach ($ele in $elements) {
    $eleName = $ele.PSObject.Properties.Name
    if ($eleName -notlike "unknown") {
        if ($IncludeRelay -and $ele.$eleName.app.servicenamerelay -like "*${App}*") {
            $WindowsServicesList += $ele.$eleName.app.servicenamerelay
        }
        if ($ele.$eleName.app.servicename -like "*${App}*") {
            $WindowsServicesList += $ele.$eleName.app.servicename
        }
    }
}

$WindowsServicesListSorted = $WindowsServicesList | Sort-Object {
    if ($_ -like "*Lizenz*") {
        0 # "Lizenz" has the highest priority
    } elseif ($_ -like "*Relay*") {
        1 # "Relay" has the second priority
    } else {
        2 # All others come last
    }
}
foreach ($e in $WindowsServicesListSorted) {
    write-host $e
}
if ($WindowsServicesListSorted.length -gt 0) {
    if ($Action -like "stop") {
        Stop-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $RemoteHost -Delay $Delay
    }
    if ($Action -like "start") {
        Start-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $RemoteHost -Delay $Delay
    }
} else {
    write-host "no services found."
    exit 1
}

exit 0
