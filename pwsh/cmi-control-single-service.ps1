param (
    [string]$Service,
    [string]$Action,      # "start" oder "stop"
    [string]$Hostname
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"

$scriptBlock = {
    param($Service, $Action)

    if ($Action -eq "start") {
        Start-Service -Name $Service -ErrorAction Stop
        $targetStatus = "Running"
    } elseif ($Action -eq "stop") {
        Stop-Service -Name $Service -ErrorAction Stop
        $targetStatus = "Stopped"
    } else {
        Write-Error "Ungültige Aktion: $Action"
        exit 1
    }

    # Warten auf Zielstatus, max 30 Sekunden
    $timeout = 30
    $elapsed = 0
    while ($true) {
        $status = (Get-Service -Name $Service).Status
        if ($status -eq $targetStatus) {
            break
        }
        Start-Sleep -Seconds 1
        $elapsed++
        if ($elapsed -ge $timeout) {
            Write-Output "timeout"
            break
        }
    }

    # Gib den finalen Status zurück
    (Get-Service -Name $Service).Status.ToString().ToLower()
}

Invoke-Command -ComputerName $Hostname -ScriptBlock $scriptBlock -ArgumentList $Service, $Action
