param (
    [string]$Service,
    [string]$Action,      # "start" oder "stop"
    [string]$Hostname
)



$scriptBlock = {
    param($Service, $Action)
    if ($Action -eq "start") {
        Start-Service -Name $Service -ErrorAction Stop
    } elseif ($Action -eq "stop") {
        Stop-Service -Name $Service -ErrorAction Stop
    }
    (Get-Service -Name $Service).Status.ToString().ToLower()
}

Invoke-Command -ComputerName $Hostname -ScriptBlock $scriptBlock -ArgumentList $Service, $Action


