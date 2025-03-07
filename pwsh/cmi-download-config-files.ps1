###################
# cmi-download-config-files.ps1 #
###################


# make sure only the json is being outputted otherwise the python flask app will not recognize the response as json and will fail


[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

# Lokaler Basisordner zum Zwischenspeichern der Dateien
$tempPath = "C:\temp\MandantenFiles"
if (-Not (Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
}

function Get-CMI-Config-Data {
    $ApiUrl = "http://localhost:5001/api/data"
    $RawJson = (Invoke-WebRequest -Uri $ApiUrl -Method Get -ErrorAction Stop).Content
    $ParsedJson = $RawJson | ConvertFrom-Json
    return $ParsedJson
}

$mandanten = Get-CMI-Config-Data
$useful = @()
foreach ($mandant in $mandanten) {
    $useful += ,@(
        $mandant.app.host, 
        $mandant.app.installpath, 
        (Split-Path -Path $mandant.app.installpath -Leaf),
        @("$($mandant.app.installpath)\Client\MetaTool.ini","$($mandant.app.installpath)\Server\MetaTool.ini","$($mandant.app.installpath)\Server\install_service.bat","$($mandant.app.installpath)\Server\uninstall_service.bat")
    )
}
for ($i = 0; $i -lt $useful.Count; $i++) {
    # Extrahiere die Gruppen-Elemente
    $computer      = $useful[$i][0]
    $installPath   = $useful[$i][1]
    $leafName      = $useful[$i][2]
    $arrFilePaths     = $useful[$i][3]
    
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
         $file
         # Kopiere die Datei vom Remote-Rechner
         try {
             Copy-Item -FromSession $session -Path $file -Destination $destinationPath -ErrorAction $ErrorActionPreference
             Write-Host "Kopiert: $file von $computer nach $destinationPath"
         } catch {
             Write-Warning ("Fehler beim Kopieren von {0} von {1}: {2}" -f $file, $computer, $_)

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

Write-Host "ZIP-Archiv erstellt: $zipPath"

# ZIP-Datei einlesen und in Base64 kodieren
$bytes = [System.IO.File]::ReadAllBytes($zipPath)
$base64Output = [Convert]::ToBase64String($bytes)

# Falls nötig, sicherstellen, dass der Base64-String korrekt gepadded ist (normalerweise ist das bereits der Fall)
$paddedBase64Output = $base64Output

# Ausgabe des Base64-codierten ZIP-Inhalts
Write-Output $paddedBase64Output



exit 0






<#
if (-not ($allConfigFiles.Count -eq 0)) {
	try {
		$jsonOutput = $allConfigFiles | ConvertTo-Json -Depth 10 -Compress
		# Convert JSON to bytes
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonOutput)

		# Create a memory stream for compressed data
		$memoryStream = [System.IO.MemoryStream]::new()

		# Use GZipStream for compression
		$gzipStream = [System.IO.Compression.GZipStream]::new($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
		$gzipStream.Write($bytes, 0, $bytes.Length)
		$gzipStream.Close()

		# Get the compressed data
		$compressedData = $memoryStream.ToArray()

		# Convert compressed data to Base64
		$base64Output = [Convert]::ToBase64String($compressedData)

		# Ensure proper Base64 padding
		$paddedBase64Output = $base64Output.PadRight((([math]::Ceiling($base64Output.Length / 4)) * 4), '=')

		Write-Output $paddedBase64Output
		exit 0
	} catch {
		Write-Output "Failed to compress or encode JSON: $_"
		exit 1
	}
} else {
	Write-Error "No file found"
	exit 2
}

#>