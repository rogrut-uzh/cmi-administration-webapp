#############################################
# cmi-stop-start-services-webapp-single.ps1 #
#############################################
Param(
    [Parameter(Mandatory = $true)]
    [string]$Host,

    [Parameter(Mandatory = $true)]
    [string]$Services
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$serviceList = $Services -split ','
$results = @{}

foreach ($service in $serviceList) {
    try {
        # Abfrage des Service-Status per Invoke-Command auf dem Remote-Host
        $svc = Invoke-Command -ComputerName $Host -ScriptBlock {
            param($s)
            Get-Service -Name $s -ErrorAction Stop
        } -ArgumentList $service

        if ($svc.Status -eq 'Running') {
            $results[$service] = "running"
        }
        else {
            $results[$service] = "stopped"
        }
    }
    catch {
        # Falls ein Fehler auftritt (z.B. Service nicht gefunden), wird "error" zurückgegeben.
        $results[$service] = "error"
    }
}

# Ausgabe der Ergebnisse als JSON
$results | ConvertTo-Json
exit 0
