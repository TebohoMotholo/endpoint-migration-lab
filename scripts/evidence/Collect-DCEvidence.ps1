<#
.SYNOPSIS
    Collects Active Directory, DNS, DHCP, Group Policy and time evidence.
.NOTES
    Run on: DC01, in Windows PowerShell as administrator (LAB\Administrator).
    Read-only: it changes nothing.
#>
. "$PSScriptRoot\Common.ps1"
if (-not (Test-IsAdmin)) { Write-Warning "Run this as administrator."; return }
$out = New-EvidenceFolder -Role "DC"
Import-Module ActiveDirectory, GroupPolicy -ErrorAction SilentlyContinue

# Domain and forest
Save-Evidence "01-forest"            { Get-ADForest | Select Name, ForestMode, Domains, UPNSuffixes, SchemaMaster, DomainNamingMaster | Format-List }
Save-Evidence "02-domain"            { Get-ADDomain | Select DNSRoot, NetBIOSName, DomainMode, PDCEmulator, RIDMaster, InfrastructureMaster | Format-List }
Save-Evidence "03-domain-controllers"{ Get-ADDomainController -Filter * | Select Name, IPv4Address, IsGlobalCatalog, OperatingSystem, Site | Format-Table -AutoSize }
Save-Evidence "04-fsmo"              { netdom query fsmo }
Save-Evidence "05-dcdiag"            { dcdiag /q }
Save-Evidence "06-repadmin-summary"  { repadmin /replsummary }
Save-Evidence "07-repadmin-showrepl" { repadmin /showrepl }
Save-Evidence "08-shares"            { net share }

# Structure
Save-Evidence "10-ou-tree"           { Get-ADOrganizationalUnit -Filter * | Sort DistinguishedName | Select Name, DistinguishedName | Format-Table -AutoSize }
Save-Csv      "11-users"             { Get-ADUser -Filter * -SearchBase "OU=Lab,$((Get-ADDomain).DistinguishedName)" -Properties Department, Enabled, UserPrincipalName, Country, MemberOf |
                                         Select Name, SamAccountName, UserPrincipalName, Enabled, Country, @{n='Groups';e={($_.MemberOf | % { ($_ -split ',')[0] -replace 'CN=' }) -join '; '}}, DistinguishedName }
Save-Csv      "12-groups"            { Get-ADGroup -Filter * -SearchBase "OU=Lab,$((Get-ADDomain).DistinguishedName)" |
                                         Select Name, GroupScope, @{n='Members';e={(Get-ADGroupMember $_ | Select -Expand Name) -join '; '}} }
Save-Csv      "13-computers"         { Get-ADComputer -Filter * -Properties OperatingSystem, IPv4Address, LastLogonDate | Select Name, OperatingSystem, IPv4Address, LastLogonDate, DistinguishedName }
Save-Evidence "14-redirected-computers" { (Get-ADDomain).ComputersContainer }

# Cloud integration objects
Save-Evidence "20-azureadkerberos"   { Get-ADComputer AzureADKerberos -Properties whenCreated | Select Name, DistinguishedName, whenCreated | Format-List }
Save-Evidence "21-hybrid-join-scp"   { Get-ADObject -SearchBase "CN=Configuration,$((Get-ADRootDSE).rootDomainNamingContext)" -Filter "name -eq '62a0ff2e-97b9-4513-943f-0d221bd30080'" -Properties keywords | Select -Expand keywords }
Save-Evidence "22-msol-account"      { Get-ADUser -Filter "Name -like 'MSOL_*'" | Select Name, Enabled | Format-Table }
Save-Evidence "23-system-management" { Get-ADObject -Filter "Name -eq 'System Management'" -SearchBase "CN=System,$((Get-ADDomain).DistinguishedName)" | Format-List }

# DNS and DHCP
Save-Evidence "30-dns-zones"         { Get-DnsServerZone | Format-Table -AutoSize }
Save-Evidence "31-dns-records"       { Get-DnsServerResourceRecord -ZoneName (Get-ADDomain).DNSRoot | Where-Object RecordType -in 'A','CNAME' | Select HostName, RecordType, @{n='Data';e={ if ($_.RecordData.IPv4Address) { $_.RecordData.IPv4Address } else { $_.RecordData.HostNameAlias } }} | Format-Table -AutoSize }
Save-Evidence "32-dns-forwarders"    { Get-DnsServerForwarder }
Save-Evidence "33-dhcp-scopes"       { Get-DhcpServerv4Scope | Format-Table -AutoSize }
Save-Evidence "34-dhcp-options"      { Get-DhcpServerv4Scope | ForEach-Object { Get-DhcpServerv4OptionValue -ScopeId $_.ScopeId } | Format-Table -AutoSize }
Save-Evidence "35-dhcp-leases"       { Get-DhcpServerv4Scope | ForEach-Object { Get-DhcpServerv4Lease -ScopeId $_.ScopeId } | Select IPAddress, HostName, AddressState | Format-Table -AutoSize }

# Group Policy
Save-Csv      "40-gpo-list"          { Get-GPO -All | Select DisplayName, GpoStatus, CreationTime, ModificationTime }
Save-Evidence "41-gpo-links"         { Get-ADOrganizationalUnit -Filter * | ForEach-Object { $l = (Get-GPInheritance -Target $_.DistinguishedName).GpoLinks; if ($l) { "$($_.Name): " + (($l | Select -Expand DisplayName) -join ', ') } } }
try { Get-GPOReport -All -ReportType Html -Path (Join-Path $out "42-all-gpos.html"); Write-Host "OK    42-all-gpos.html" -ForegroundColor Green } catch { Write-Host "FAIL  GPO report" -ForegroundColor Yellow }
Save-Evidence "43-gpo-retired-pilot" { Get-GPO -All | ForEach-Object { $g = $_; Get-GPPermission -Guid $g.Id -All | Where-Object { $_.Trustee.Name -eq 'GPO-Retired-Pilot' } | ForEach-Object { "$($g.DisplayName): $($_.Permission) Denied=$($_.Denied)" } } }

# Time
Save-Evidence "50-time"              { Get-TimeZone; "Local: $(Get-Date -Format s)"; "UTC:   $([DateTime]::UtcNow.ToString('s'))"; w32tm /query /source; w32tm /query /status }

Complete-Evidence
