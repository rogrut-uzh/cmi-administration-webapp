# CMI Administration Webapp

Used for retrieving information about the CMI installations, and for maintenance jobs.

## Prerequisites
CMI Config https://gitlab.uzh.ch/dba/zidbacons2/cmi-config must be running. 

## Access

  - http://localhost:5000
  - https://zidbacons02.d.uzh.ch

Reverse proxy created with [caddy](https://caddyserver.com/). Port 80 and 443 are redirected to localhost:5000. Uses UZH Web-Certificate. 

## Windows Service "cmi-admin-webapp"

Created with nssm ([The Non-Sucking Service Manager](https://nssm.cc/)).

  - `nssm install cmi-admin-webapp`
  - `nssm edit cmi-admin-webapp`
    - Path: `powershell.exe`
    - Startup Directory: `D:\gitlab\cmi-administration-webapp`
    - Arguments: `D:\gitlab\cmi-administration-webapp\start.ps1`
  - Logon with `uzh\adb-srv-zidbacons02`, Startup Automatic.
