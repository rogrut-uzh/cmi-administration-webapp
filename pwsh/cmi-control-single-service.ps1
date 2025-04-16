param (
    [string]$Service,
    [string]$Action,      # "start" oder "stop"
    [string]$Hostname
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Setze Proxy-Umgebungsvariablen
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"



# Invoke-Command mit Error-Handling
try {
    # Scriptblock mit Timeout-Logik
    $scriptBlock = {
        param($Service, $Action)
        $ReturnCode = $null

        $WarningPreference = 'SilentlyContinue'  # Unterdrückt PowerShell-Warnings wie "Waiting for service..."

        try {
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

            # Max. 30 Sekunden auf Zielstatus warten
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
                    $msg = "timeout"
                }
            }

            # Gib den finalen Status aus
            $msg = (Get-Service -Name $Service).Status.ToString().ToLower()
            

        } catch {
            $msg = "Fehler bei der Dienststeuerung: $_"
        }
        return $msg
    }
    
    $Result = Invoke-Command -ComputerName $Hostname -ScriptBlock $scriptBlock -ArgumentList $Service, $Action -ErrorAction Stop
    write-host $Result
    if ($Result -match '^Stopped' -or $Result -match '^Running') {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Error "Invoke-Command fehlgeschlagen: $_"
    exit 3
}

