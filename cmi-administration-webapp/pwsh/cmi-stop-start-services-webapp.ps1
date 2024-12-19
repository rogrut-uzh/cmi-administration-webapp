######################################
# cmi-stop-start-services-webapp.ps1 #
######################################
# 
# Stoppt oder startet die angegebenen CMI-Windows-Services.
# 
# Aufruf: 
# ./cmi-stop-start-services-test.ps1 -Action "stop" -App "cmi" -Env "test"
# ./cmi-stop-start-services-test.ps1 -Action "start" -App "ais" -Env "prod" -IncludeRelay $false
#
# Argumente:
# -Action:          "start" oder "stop" des Services
# -App:             "cmi" für CMI oder "ais" für die Archivinformationssysteme (inkl. Benutzungsverwaltung"
# -Env:             "prod" für Produktiv-Umgebung, "test" für Testumgebung
# -IncludeRelay:    true/false. Ob auch die Relay-Server berücksichtigt werden sollen. Default: true
#
# Script in der Admin-Console ausführen, oder als Teil der Web-App.
# Funktioniert mit Powershell 5.x.
#
# Autor: rogrut / Dezember 2024
#
######################################
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("cmi", "ais")]
    [string]$App,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "prod")]
    [string]$Env,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("start", "stop")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeRelay = $true  # Optional parameter with a default value
)

# Exit, wenn nicht als admin ausgeführt
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    write-host "run as admin"
    exit 1
}

# Variablen
$Delay = 2
$ApiUrl = "http://localhost:5001/api/data"
$WindowsServicesList = @()
if ($Env -like "test") {
    $RemoteHost = "ziaxiomatap02"
} else {
    if ($App -like "cmi") {
        $RemoteHost = "ziaxiomapap03"
    } elseif ($App -like "ais") {
        $RemoteHost = "ziaxiomapap04"
    }
}

#Functions
function Stop-ServicesRemote {
    param (
        [string[]]$Services,    # Liste der Dienste
        [string]$RemoteHost,    # Remote-Hostname oder IP-Adresse
        [int]$Delay = 2         # Verzögerung zwischen Stop-Versuchen
    )
    
    $Sb = {
        param (
            [string[]]$Services,
            [int]$Delay
        )

        foreach ($service in $Services) {
            Write-Output ""
            Write-Output "Versuche den Service $service zu stoppen..."
            $output = net stop "$service" 2>&1
            if ($output -match "service was stopped successfully") {
                Write-Output "Service $service erfolgreich gestoppt."
            } else {
                Write-Output "Stoppen fehlgeschlagen: $service. Error: $output"
            }
            Start-Sleep -Seconds $Delay
        }
    }

    # Remoting auf dem Remote-Host ausführen
    Invoke-Command -ComputerName $RemoteHost -ScriptBlock $Sb -ArgumentList $Services, $Delay
}

function Start-ServicesRemote {
    param (
        [string[]]$Services,    # Liste der Dienste
        [string]$RemoteHost,    # Remote-Hostname oder IP-Adresse
        [int]$Delay = 2         # Verzögerung zwischen Stop-Versuchen
    )
    
    $Sb = {
        param (
            [string[]]$Services,
            [int]$Delay
        )

        foreach ($service in $services) {
            write-host ""
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObj -and $serviceObj.Status -ne 'Running') {
                Write-Output "Service starten: $service"
                $output = net start "$service" 2>&1  # Capture output and errors
                if ($output -match "service was started successfully") {
                    Write-Output "Befehl für Starten des Service $service wurde ausgeführt. Warte bis er gestartet wurde..." 
                    $isRunning = $false
                    while (-not $isRunning) {
                        Start-Sleep -Seconds 1 
                        # Überprüfe den Status des Dienstes
                        $serviceStatus = Get-Service -Name "$service" -ErrorAction SilentlyContinue
                        if ($serviceStatus.Status -eq 'Running') {
                            $isRunning = $true
                            Write-Output "Service $service wurde jetzt gestartet."
                        } else {
                            Write-Output "Service $service startet immernoch..."
                        }
                    }
                } else { 
                    Write-Output "Starten fehlgeschlagen: $service. Error: $output" 
                }
            } else {
                 Write-Output "Service $service läuft bereits." 
            }
            Start-Sleep -Seconds $Delay
        }
    }

    # Remoting auf dem Remote-Host ausführen
    Invoke-Command -ComputerName $RemoteHost -ScriptBlock $Sb -ArgumentList $Services, $Delay
}

function Get-CMI-Config-Data {
    param (
        [string]$App,
        [string]$Env
    )
    $Url = "${ApiUrl}/${App}/${Env}"
	write-host "Calling $Url"
    $RawJson = (Invoke-WebRequest -Uri $Url -Method Get).Content
    #$ParsedJson = ($RawJson | ConvertFrom-Json) | ConvertTo-Json -Depth 10 -Compress:$false # nur zu testzwecken für die schöne ausgabe am terminal
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}




$elements = Get-CMI-Config-Data -App $App -Env $Env

if (($elements | Measure-Object).count -lt 1) {
    write-host "nothing found."
    exit 1
} else {
	Write-Host "Answer received. Getting the names of the corresponding services..."
}

foreach ($ele in $elements) {
	if ($IncludeRelay) {
		$WindowsServicesList += $ele.app.servicenamerelay
	}
	$WindowsServicesList += $ele.app.servicename
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

    
write-host ""
write-host "Found Services:"
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
