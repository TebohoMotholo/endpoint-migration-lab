# 08. Application migration (ConfigMgr to Intune)

## Goal

Repackage every ConfigMgr application as an Intune Win32 app with the same install, uninstall and detection logic, then remove the ConfigMgr deployment.

## Packaging

One source folder per app, containing only that app's installer:

```
C:\Pkg\
├── IntuneWinAppUtil.exe
├── 7zip\src\     7z-x64.msi
├── Chrome\src\   googlechromestandaloneenterprise64.msi
├── Notepad\src\  npp-installer.exe
├── VLC\src\      vlc-<version>-win64.exe
└── out\
```

```powershell
cd C:\Pkg
.\IntuneWinAppUtil.exe -c C:\Pkg\VLC\src -s vlc-<version>-win64.exe -o C:\Pkg\out -q
```

Batch version: [`scripts/intune/New-IntuneWinPackages.ps1`](../scripts/intune/New-IntuneWinPackages.ps1)

## App settings

| App | Install | Uninstall | Detection |
|---|---|---|---|
| 7-Zip | `msiexec /i "7z-x64.msi" /qn` | `msiexec /x {ProductCode} /qn` | MSI product code |
| Chrome | `msiexec /i "googlechromestandaloneenterprise64.msi" /qn` | `msiexec /x {ProductCode} /qn` | File `C:\Program Files\Google\Chrome\Application\chrome.exe` |
| Notepad++ | `npp-installer.exe /S` | `"C:\Program Files\Notepad++\uninstall.exe" /S` | File `C:\Program Files\Notepad++\notepad++.exe` |
| VLC | `vlc-<version>-win64.exe /L=1033 /S` | `"C:\Program Files\VideoLAN\VLC\uninstall.exe" /S` | File `C:\Program Files\VideoLAN\VLC\vlc.exe` |

All: install behaviour System, 64-bit Windows 10/11, assigned Required to `Pilot-Devices` first.

## Cutover

1. Intune app installs on client02 and Intune detection sees the existing install (no reinstall).
2. Remove client02 from the ConfigMgr deployment collections.
3. Move the Client Apps co-management workload once all apps are migrated.
4. Widen the Intune assignment, delete the ConfigMgr deployments.

## Verify

- Apps, Monitor, App install status
- Client log: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| IntuneWinAppUtil: "The folder you specified can not be accessed" | Interactive mode answered with a file path, then with the whole command line | Ran it from a normal prompt with `-c -s -o -q`, source folders under `C:\Pkg` |
| `C:\Pkg\IntuneWinAppUtil.exe.` not recognised | Trailing full stop typed after the command, then the tool was not in `C:\Pkg` | Removed the dot, found the extracted tool and copied it in |
