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

## Service Account Zugang zur DB geben

```
-- Login für AD-Konto erstellen
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'UZH\adb-srv-zidbacons02')
    CREATE LOGIN [uzh\adb-srv-zidbacons02] FROM WINDOWS;

-- User in den einzelnen Datenbanken anlegen und Backup Permissions geben
USE [star_afm_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [star_uaz_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [star_uaz_benutzung_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_zzm_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_wwf_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_vsf_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_vpedu_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_trf_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_rwf_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_rechtsdienst_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_professuren_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_philosophfak_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_mnf_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_medizinfak_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_lizenzserver_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_intrev_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_informatik_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_generalsek_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_dfpdib_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

USE [axioma_bm_TEST];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'uzh\adb-srv-zidbacons02')
    CREATE USER [uzh\adb-srv-zidbacons02] FOR LOGIN [uzh\adb-srv-zidbacons02];
GRANT BACKUP DATABASE TO [uzh\adb-srv-zidbacons02];

```