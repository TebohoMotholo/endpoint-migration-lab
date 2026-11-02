# 10. Cloud authentication: Cloud Kerberos Trust and password writeback

## Goal

Move sign-in towards cloud identity without breaking access to on-premises resources.

## Windows Hello for Business with Cloud Kerberos Trust

Lets a user sign in with a Windows Hello PIN and still get Kerberos tickets for on-premises file shares, without certificates or extra infrastructure.

### Steps

1. Create the Microsoft Entra Kerberos server object (DC01, elevated):
   ```powershell
   Install-Module -Name AzureADHybridAuthenticationManagement -AllowClobber
   $domain = $env:USERDNSDOMAIN
   $upn = "<cloud-admin>@<tenant>.onmicrosoft.com"
   $domainCred = Get-Credential
   Set-AzureADKerberosServer -Domain $domain -UserPrincipalName $upn -DomainCredential $domainCred
   ```
   An `AzureADKerberos` object appears in the Domain Controllers OU.
2. Intune, Endpoint security, Account protection: Use Windows Hello for Business, **Use cloud trust for on-prem auth**. Assign to `Pilot-Devices`.
3. Co-managed devices: move Device Configuration to Pilot Intune, or the policy never applies.
4. Sign out, set up a PIN, sign in **with the PIN**.

### Verify (normal, non-elevated prompt)

```powershell
klist cloud_debug   # Cloud Kerberos enabled by policy: 1, Public Key Credential Present: 1
dsregcmd /status    # CloudTgt YES, NgcSet YES
```

Then open `\\FS01\Shared` with no password prompt.

### Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| `Cloud Kerberos enabled by policy: 0` | Device Configuration workload still owned by ConfigMgr | Moved it to Pilot Intune for the pilot collection |
| `klist` failed with `0xc000005f` | Run from an elevated window, which uses a different logon session | Ran it from a normal window |
| `Plaintext Password Present: 1`, no key credential | Signed in with a password, not the Hello PIN | Signed in with the PIN |

Status: in progress.

## Password writeback and self-service password reset

### Steps

1. Entra Connect: Optional features, Password writeback.
2. AD permissions for the `MSOL_` connector account ([`scripts/ad/Set-PasswordWritebackPermissions.ps1`](../scripts/ad/Set-PasswordWritebackPermissions.ps1)).
3. Entra, Password reset, On-premises integration: writeback on, allow unlock without reset.
4. SSPR enabled for the licensed group, users register at first sign-in.
5. Domain password policy minimum age `0` so a reset is not blocked.

### Verify

Reset a normal synced user's password at `https://aka.ms/sspr`, then log on to a lab PC as `LAB\<user>` with the new password.

Protected admin accounts are excluded from writeback by design, so test with a normal user.

## Line-of-business app: Entra sign-in in front of web01

The internal web app (Nginx on web01) is put behind Entra sign-in with an app registration and oauth2-proxy. Config: [`configs/oauth2-proxy.cfg.example`](../configs/oauth2-proxy.cfg.example) and [`configs/nginx-mysite-oauth.conf`](../configs/nginx-mysite-oauth.conf).

Status: planned.
