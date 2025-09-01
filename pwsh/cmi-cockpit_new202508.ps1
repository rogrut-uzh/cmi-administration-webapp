###################
# cmi-cockpit.ps1 #
###################
# 
# Für Aufruf in der Webapp gedacht. Sammelt Informationen zu den CMI-Installationen.
#
# Autor: rogrut / Dezember 2024
#
###################
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = "http://zoneproxy.zi.uzh.ch:8080"
$env:HTTPS_PROXY = "http://zoneproxy.zi.uzh.ch:8080"


$elements = (Invoke-WebRequest -Uri "http://localhost:5001/api/data" -Method Get).Content
if (($elements | Measure-Object).count -lt 1) {
    write-host "nothing found."
    exit 1
}
$elements
