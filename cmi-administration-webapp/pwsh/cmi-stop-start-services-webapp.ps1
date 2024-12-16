###############################
# cmi-stop-start-services.ps1 #
###############################
# 
# Stoppt oder startet die angegebenen CMI-Windows-Services.
# 
# Aufruf: 
# ./cmi-stop-start-services-test.ps1 -Action "stop" -App "cmi" -Env "test"
# ./cmi-stop-start-services-test.ps1 -Action "start" -App "ais" -Env "prod"
#
# Argumente:
# -Action: 	"start" oder "stop" des Services
# -App: 	"cmi" für CMI oder "ais" für die Archivinformationssysteme (inkl. Benutzungsverwaltung"
# -Env: 	"prod" für Produktiv-Umgebung, "test" für Testumgebung
#
# Script in der Admin-Console ausführen.
# Funktioniert mit Powershell 5.x.
#
# Autor: rogrut / 13.12.2024
#
###############################
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
    $remoteHost = "ziaxiomatap02"
} else {
	if ($App -like "cmi") {
		$remoteHost = "ziaxiomapap03"
	} elseif ($App -like "ais") {
		$remoteHost = "ziaxiomapap04"
	}
}

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
		Stop-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $remoteHost -Delay $Delay
	}
	if ($Action -like "start") {
		Start-ServicesRemote -Services $WindowsServicesListSorted -RemoteHost $remoteHost -Delay $Delay
	}
} else {
	write-host "no services found."
	exit 1
}

exit 0
