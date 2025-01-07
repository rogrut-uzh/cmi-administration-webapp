# CMI Administration Webapp

Used for retrieving information about the CMI installations, and for maintenance jobs.

## Access

http://localhost:5000 or https://zidbacons02.uzh.ch

## reverse proxy

Created with [caddy](https://caddyserver.com/). Port 80 and 443 are redirected to localhost:5000. Currently, a self signed certificate is used. 

## Windows Service "cmi-administration-webapp"

Created with nssm ([The Non-Sucking Service Manager](https://nssm.cc/)).

  - `nssm install cmi-administration-webapp`
  - `nssm edit cmi-administration-webapp`
    - Path: `python.exe`
    - Startup Directory: `D:\gitlab\cmi-administration-webapp`
    - Arguments: `D:\gitlab\cmi-administration-webapp\app.py`
  - Logon with `uzh\rogrut-adm`, Startup Automatic.