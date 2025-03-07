#################################
# cmi-download-config-files.ps1 #
#################################
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

# Lokaler Basisordner zum Zwischenspeichern der Dateien
$tempPath = "C:\temp\MandantenFiles"
if (-Not (Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
}

function Get-CMI-Config-Data {
    $ApiUrl = "http://127.0.0.1:5001/api/data"
    $RawJson = (Invoke-WebRequest -Uri $ApiUrl -Method Get -UseBasicParsing -ErrorAction Stop).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

$mandanten = Get-CMI-Config-Data
$mandantenNeededValues = @()
foreach ($mandant in $mandanten) {
    $mandantenNeededValues += ,@(
        $mandant.app.host, 
        $mandant.app.installpath, 
        (Split-Path -Path $mandant.app.installpath -Leaf),
        @("$($mandant.app.installpath)\Client\MetaTool.ini","$($mandant.app.installpath)\Server\MetaTool.ini","$($mandant.app.installpath)\Server\install_service.bat","$($mandant.app.installpath)\Server\uninstall_service.bat")
    )
}
for ($i = 0; $i -lt $mandantenNeededValues.Count; $i++) {
    # Extrahiere die Gruppen-Elemente
    $computer      = $mandantenNeededValues[$i][0]
    $installPath   = $mandantenNeededValues[$i][1]
    $leafName      = $mandantenNeededValues[$i][2]
    $arrFilePaths  = $mandantenNeededValues[$i][3]
    
    # Umgebungszuordnung: "test" falls im Installationspfad " Test" vorkommt, sonst "prod"
    if ($installPath -match " Test") {
         $envFolder = "test"
    } else {
         $envFolder = "prod"
    }
    
    # Aufbau einer PSSession zum Remote-Computer
    $session = New-PSSession -ComputerName $computer
    
    foreach ($file in $arrFilePaths) {
         # Bestimme, ob die Datei im Client- oder Server-Unterordner abgelegt werden soll
         if ($file -match "\\Client\\") {
             $subfolder = "Client"
         } elseif ($file -match "\\Server\\") {
             $subfolder = "Server"
         } else {
             $subfolder = "Misc"
         }
         
         # Zielordner: Basis\envFolder\subfolder\LeafName
         $destinationFolder = Join-Path -Path $tempPath -ChildPath "${envFolder}\${leafName}\${subfolder}"
         if (-Not (Test-Path $destinationFolder)) {
             New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
         }
         
         # Bestimme den Dateinamen und den vollen Zielpfad
         $fileName = Split-Path -Path $file -Leaf
         $destinationPath = Join-Path -Path $destinationFolder -ChildPath $fileName
         # Kopiere die Datei vom Remote-Rechner
         try {
             Copy-Item -FromSession $session -Path $file -Destination $destinationPath -ErrorAction $ErrorActionPreference
             #Write-Host "Kopiert: $file von $computer nach $destinationPath"
         } catch {
             #Write-Warning ("Fehler beim Kopieren von {0} von {1}: {2}" -f $file, $computer, $_)

         }
    }
    
    # Schließe die PSSession
    Remove-PSSession $session
}

# Erstelle das ZIP-Archiv aus dem Basisordner
$zipPath = "C:\temp\MandantenFiles.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path "$tempPath\*" -DestinationPath $zipPath

#Write-Host "ZIP-Archiv erstellt: $zipPath"

# ZIP-Datei einlesen und in Base64 kodieren
$bytes = [System.IO.File]::ReadAllBytes($zipPath)
$base64Output = [Convert]::ToBase64String($bytes)

Write-Output $base64Output

exit 0
