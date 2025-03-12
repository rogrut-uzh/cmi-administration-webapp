#############################################
# cmi-stop-start-services-webapp-single.ps1 #
#############################################

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
        $jsonData = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing
        if ($jsonData -isnot [System.Collections.IEnumerable]) {
            $jsonData = @($jsonData)
        }
        foreach ($item in $jsonData) {
            # Annahme: Die API liefert Objekte, in denen unter result.app die Daten stehen.
            $appInfo = $item.result.app
            $hostname = ($appInfo.hostname).Trim()
            $servicename = ($appInfo.servicename).Trim()
            $servicenamerelay = ($appInfo.servicenamerelay).Trim()
            
            $entry = @{
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
$endpointsData | ConvertTo-Json -Depth 5
exit 0
