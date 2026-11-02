<#
.SYNOPSIS
    Checks SQL Server is ready for a ConfigMgr site database.
.NOTES
    Run on: CM01, elevated, signed in as the account that will run ConfigMgr Setup.
    Tests the way Setup connects (FQDN over TCP), not just localhost.
#>

$fqdn = "CM01.lab.teboho.co.za"

"--- Service account (must not be NT Service\...)"
Get-CimInstance Win32_Service -Filter "Name='MSSQLSERVER'" | Select-Object Name, StartName, State

"--- TCP 1433 reachable by FQDN"
Test-NetConnection $fqdn -Port 1433 | Select-Object ComputerName, TcpTestSucceeded

"--- Collation (must be SQL_Latin1_General_CP1_CI_AS) and sysadmin (must be 1)"
sqlcmd -S $fqdn -E -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('Collation') AS varchar(60)) AS Collation, IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin" -W

"--- Databases (only master, tempdb, model, msdb before install)"
sqlcmd -S $fqdn -E -Q "SET NOCOUNT ON; SELECT name FROM sys.databases" -W

<# Fixes used in this lab:
 1. SQL Server Configuration Manager, Protocols for MSSQLSERVER, enable TCP/IP,
    IPAll TCP Port 1433, Dynamic Ports blank.
 2. SQL Server Services, SQL Server (MSSQLSERVER), Log On: LAB\svc-cmsql.
    Use this tool, not services.msc, so file and registry rights are set.
 3. Firewall:
    New-NetFirewallRule -DisplayName "SQL Server 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
 4. Index create memory default:
    sqlcmd -S localhost -E -Q "EXEC sp_configure 'show advanced options',1; RECONFIGURE; EXEC sp_configure 'index create memory',0; RECONFIGURE;"
#>
