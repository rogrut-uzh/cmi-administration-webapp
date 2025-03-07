###################
# cmi-cockpit.ps1 #
###################
# 
# Für Aufruf in der Webapp gedacht. Sammelt Informationen zu den CMI-Installationen.
#
# Autor: rogrut / Dezember 2024
#
###################
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("cmi", "ais", "all")]
    [string]$App,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "prod", "all")]
    [string]$Env
)

$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"

# Variablen
$ApiUrl = "http://localhost:5001/api/data"


#Functions
function Get-CMI-Config-Data {
    param (
        [string]$App,
        [string]$Env
    )
    $Url = "${ApiUrl}/${App}/${Env}"
	#write-host $Url
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content # this must be returned to the app!
    #$ParsedJson = ($RawJson | ConvertFrom-Json) | ConvertTo-Json -Depth 10 -Compress:$false # nur zu testzwecken für die schöne ausgabe am terminal
    #$ParsedJson = $RawJson | ConvertFrom-Json
    return $RawJson
}


$elements = Get-CMI-Config-Data -App $App -Env $Env
if (($elements | Measure-Object).count -lt 1) {
    write-host "nothing found."
    exit 1
}
$elements

