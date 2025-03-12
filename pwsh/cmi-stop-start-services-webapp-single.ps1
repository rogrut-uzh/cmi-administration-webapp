#############################################
# cmi-stop-start-services-webapp-single.ps1 #
#############################################
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
function Get-CMI-Config-Data {
    param (
        [string]$u
    )
	#write-host $Url
    $RawJson = (Invoke-WebRequest -Uri $u -Method Get).Content 
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

# API-Endpunkte definieren
$endpoints = @(
    @{ Label = "CMI Prod"; Url = "http://localhost:5001/api/data/cmi/prod" },
    @{ Label = "AIS Prod"; Url = "http://localhost:5001/api/data/ais/prod" },
    @{ Label = "CMI Test"; Url = "http://localhost:5001/api/data/cmi/test" },
    @{ Label = "AIS Test"; Url = "http://localhost:5001/api/data/ais/test" }
)

# Array für die Endpunkt-Daten
$endpointsData = @()

# Globales Dictionary für Host -> Set von Service-Namen
$hostServices = @{}

foreach ($ep in $endpoints) {
    $label = $ep.Label
    $url = $ep.Url
    $entries = @()

    try {
        # API-Daten abrufen
        $jsonData = Get-CMI-Config-Data -u $url

        if ($jsonData -isnot [System.Collections.IEnumerable]) {
            $jsonData = @($jsonData)
        }
		#$jsonData
        foreach ($item in $jsonData) {
			$namefull = if ($item.namefull) { $item.namefull } else { "" }
            $appInfo = $item.app
            $hostname = if ($appInfo.host) { $appInfo.host.Trim() } else { "" }
			$servicename = if ($appInfo.servicename) { $appInfo.servicename.Trim() } else { "" }
            $servicenamerelay = if ($appInfo.servicenamerelay) { $appInfo.servicenamerelay.Trim() } else { "" }
            
            $entry = @{
                namefull = $namefull
                hostname = $hostname
                servicename = $servicename
                servicenamerelay = $servicenamerelay
                status_service = ""
                status_relay = ""
            }
            $entries += $entry

            # Service-Namen global pro Host sammeln
            if (-not [string]::IsNullOrEmpty($hostname)) {
                if (-not $hostServices.ContainsKey($hostname)) {
                    $hostServices[$hostname] = New-Object System.Collections.Generic.HashSet[string]
                }
                if (-not [string]::IsNullOrEmpty($servicename)) {
                    $hostServices[$hostname].Add($servicename) | Out-Null
                }
                if (-not [string]::IsNullOrEmpty($servicenamerelay)) {
                    $hostServices[$hostname].Add($servicenamerelay) | Out-Null
                }
            }
        }
    }
    catch {
        $entries += @{
			namefull = ""
            hostname = "Error: $($_.Exception.Message)"
            servicename = ""
            servicenamerelay = ""
            status_service = "Error"
            status_relay = "Error"
        }
    }

    $endpointsData += @{
        label = $label
        endpoint = $url
        entries = $entries
    }
}

# Pro Host den Service-Status abfragen (einmaliger Remote-Aufruf pro Host)
$hostStatusMapping = @{}
foreach ($hostname in $hostServices.Keys) {
    $servicesArray = $hostServices[$hostname] | Sort-Object
    $serviceStatus = @{}

    foreach ($service in $servicesArray) {
        try {
            $svc = Invoke-Command -ComputerName $hostname -ScriptBlock {
                param($s)
                Get-Service -Name $s -ErrorAction Stop
            } -ArgumentList $service -ErrorAction Stop

            if ($svc.Status -eq 'Running') {
                $serviceStatus[$service] = "running"
            }
            else {
                $serviceStatus[$service] = "stopped"
            }
        }
        catch {
            $serviceStatus[$service] = "error"
        }
    }
    $hostStatusMapping[$hostname] = $serviceStatus
}

# Aktualisiere die Einträge in den Endpunkt-Daten mit den abgefragten Statuswerten
foreach ($epData in $endpointsData) {
    foreach ($entry in $epData.entries) {
        $hostname = $entry.hostname
        if ($hostStatusMapping.ContainsKey($hostname)) {
            $mapping = $hostStatusMapping[$hostname]
            $entry.status_service = if ($mapping.ContainsKey($entry.servicename)) { $mapping[$entry.servicename] } else { "unknown" }
            $entry.status_relay = if ($mapping.ContainsKey($entry.servicenamerelay)) { $mapping[$entry.servicenamerelay] } else { "unknown" }
        }
        else {
            $entry.status_service = "Error"
            $entry.status_relay = "Error"
        }
    }
}

# Ausgabe des Ergebnis als JSON (höhere Depth für verschachtelte Strukturen)
Write-Output ($endpointsData | ConvertTo-Json -Depth 5 -Compress)
exit 0