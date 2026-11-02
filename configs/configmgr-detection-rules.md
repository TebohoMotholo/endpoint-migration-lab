# App install, uninstall and detection (ConfigMgr and Intune)

The same logic is used in both systems, so the Intune app sees an existing ConfigMgr install and does not reinstall.

| App | Type | Install | Uninstall | Detection |
|---|---|---|---|---|
| 7-Zip | MSI | `msiexec /i "7z-x64.msi" /qn` | `msiexec /x {ProductCode} /qn` | MSI product code |
| Chrome Enterprise | MSI | `msiexec /i "googlechromestandaloneenterprise64.msi" /qn` | `msiexec /x {ProductCode} /qn` | `C:\Program Files\Google\Chrome\Application\chrome.exe` exists |
| Notepad++ | EXE | `npp-installer.exe /S` | `"C:\Program Files\Notepad++\uninstall.exe" /S` | `C:\Program Files\Notepad++\notepad++.exe` exists |
| VLC | EXE | `vlc-<version>-win64.exe /L=1033 /S` | `"C:\Program Files\VideoLAN\VLC\uninstall.exe" /S` | `C:\Program Files\VideoLAN\VLC\vlc.exe` exists |

Find an MSI product code after a test install:

```powershell
Get-Package -Name "7-Zip*" | Format-List Name, Version, FastPackageReference
```
