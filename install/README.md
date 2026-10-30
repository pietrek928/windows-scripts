# Install scripts

## TODO

- remove 'Windows Defender'
- `sc delete wuauserv` — only way to disable update ???

## Apply `.reg` files from Linux (offline hive with hivex)

Use `hivexregedit` to merge Windows `.reg` files into an offline registry hive.
`chntpw` is better for interactive edits; prefer hivex for batch `.reg` imports.

> **Warning:** Offline merges rewrite critical Windows files under
> `Windows\System32\config\` (and user `NTUSER.DAT`). Always back up the hive
> first. Windows must be shut down cleanly (not hibernated / Fast Startup)
> before you edit its hives.

`.reg` files in this folder are already UTF-8 (or ASCII) with Unix LF endings.
Merge them directly; no `iconv`/`dos2unix` step is required for repo files.

Ignore Perl locale warnings from `hivexregedit`; they are unrelated to merge
success or failure.

### 1. Install tools (Arch)

```bash
sudo pacman -S hivex
```

Verify: package installs with no errors.

### 2. Map root keys to hive files

With the Windows partition mounted at `/mnt`:

| Root key | Hive file |
|----------|-----------|
| `HKEY_LOCAL_MACHINE\SOFTWARE` | `/mnt/Windows/System32/config/SOFTWARE` |
| `HKEY_LOCAL_MACHINE\SYSTEM` | `/mnt/Windows/System32/config/SYSTEM` |
| `HKEY_CURRENT_USER\...` | `/mnt/Users/<Username>/NTUSER.DAT` (or `Users\Default\NTUSER.DAT`) |

Files in this folder (one hive per `.reg` — never mix SYSTEM and SOFTWARE):

| File | Target hive |
|------|-------------|
| `disable-services.reg` | SYSTEM |
| `utc-time.reg` | SYSTEM |
| `Disable_Windows_Defender_Security_Center-SYSTEM.reg` | SYSTEM |
| `Disable_Windows_Defender_Security_Center-SOFTWARE.reg` | SOFTWARE |
| `explorer-settings.reg` | NTUSER.DAT (HKCU; UTF-8; parent keys declared) |

`hivexregedit` edits one physical hive file at a time. A `.reg` that contains both
`HKEY_LOCAL_MACHINE\SYSTEM\...` and `HKEY_LOCAL_MACHINE\SOFTWARE\...` keys will
fail when the first SOFTWARE block is reached if you only passed the SYSTEM
hive (and the reverse). Split mixed files before merging.

### 3. Back up the target hive

SYSTEM:

```bash
sudo cp /mnt/Windows/System32/config/SYSTEM \
        /mnt/Windows/System32/config/SYSTEM.bak
```

SOFTWARE:

```bash
sudo cp /mnt/Windows/System32/config/SOFTWARE \
        /mnt/Windows/System32/config/SOFTWARE.bak
```

Verify:

```bash
ls /mnt/Windows/System32/config/SYSTEM.bak
ls /mnt/Windows/System32/config/SOFTWARE.bak
```

For `explorer-settings.reg`, back up that user's `NTUSER.DAT` the same way.

### 4. CurrentControlSet (SYSTEM hive only)

`CurrentControlSet` is a live Windows alias. It does **not** exist in the offline
SYSTEM hive. Keys must target `ControlSet001` (or whichever set `Select\Current`
points to).

Find the active control set:

```bash
sudo hivexregedit --export \
  --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
  /mnt/Windows/System32/config/SYSTEM '\Select'
```

- If `"Current"=dword:00000001`, use `ControlSet001`.
- If `"Current"=dword:00000002`, use `ControlSet002`.

Rewrite paths before merging when needed:

```bash
sed 's/CurrentControlSet/ControlSet001/g' install/utc-time.reg > /tmp/utc-time.reg
```

(Replace `ControlSet001` with the set from `Select\Current`.)

Note: `Disable_Windows_Defender_Security_Center-SYSTEM.reg` and
`disable-services.reg` already use `ControlSet001`. `utc-time.reg` still uses
`CurrentControlSet` and **must** be rewritten before an offline merge.

### 5. Declare missing parent keys (SOFTWARE policies)

`hivexregedit` does not create missing ancestor keys. If you merge a deep path
like `...\WindowsUpdate\AU` and the parents do not exist yet, the merge fails.

For each missing ancestor, declare an empty key block, then a blank line,
then the next key. A blank line is required: without it, `hivexregedit` stays
inside the previous key and reports
`parse error: unexpected text found ... near [HKEY_...]`.

Example (already done in `Disable_Windows_Defender_Security_Center-SOFTWARE.reg`):

```reg
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies]

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft]

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows]

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate]

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
"NoAutoUpdate"=dword:00000001
```

Do the same for any other deep paths that may be missing on a fresh install.

### 6. Merge into the hives

From the repo root, apply every `.reg` in `install/` (back up hives first — section 3).
Replace `<Username>` with the Windows profile name (often `-` on this machine).

```bash
# SYSTEM — disable-services.reg
sudo hivexregedit --merge /mnt/Windows/System32/config/SYSTEM \
  --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
  install/disable-services.reg

# SYSTEM — utc-time.reg (rewrite CurrentControlSet first; see section 4)
sed 's/CurrentControlSet/ControlSet001/g' install/utc-time.reg > /tmp/utc-time.reg
sudo hivexregedit --merge /mnt/Windows/System32/config/SYSTEM \
  --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
  /tmp/utc-time.reg

# SYSTEM — Disable_Windows_Defender_Security_Center-SYSTEM.reg
sudo hivexregedit --merge /mnt/Windows/System32/config/SYSTEM \
  --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
  install/Disable_Windows_Defender_Security_Center-SYSTEM.reg

# SOFTWARE — Disable_Windows_Defender_Security_Center-SOFTWARE.reg
# (policies, SecurityHealth Run delete, Defender + Windows Update TaskCache Tree deletes)
sudo hivexregedit --merge /mnt/Windows/System32/config/SOFTWARE \
  --prefix 'HKEY_LOCAL_MACHINE\SOFTWARE' \
  install/Disable_Windows_Defender_Security_Center-SOFTWARE.reg

# NTUSER.DAT — explorer-settings.reg
sudo cp /mnt/Users/<Username>/NTUSER.DAT \
        /mnt/Users/<Username>/NTUSER.DAT.bak
sudo hivexregedit --merge /mnt/Users/<Username>/NTUSER.DAT \
  --prefix 'HKEY_CURRENT_USER' \
  install/explorer-settings.reg
```

Defender and Windows Update TaskCache Tree deletes are in the SOFTWARE `.reg`.
Orphaned `TaskCache\Tasks\{GUID}` entries and `System32\Tasks` XML may remain;
tasks often recreate if related services stay enabled or after a Feature Update —
apply the Defender SYSTEM `.reg` as well (see section 7).

Apply Defender SYSTEM **after** `disable-services.reg` so `mpssvc` stays
`Start=2` (Automatic) and so WU services (`UsoSvc`, `BITS`, `uhssvc`, …) get
`Start=4` + FailureActions from the Defender SYSTEM pack.
`disable-services.reg` still sets `mpssvc` to disabled and `BITS` to manual;
the Defender SYSTEM merge overrides those for the offline WU disable.

Success is usually silent (no Perl error traces about wrong hive / missing
parents). Windows will read the updated hives on next boot.

To undo: copy the `.bak` hive back over the original (while Windows is still offline).

### 7. Windows Update offline disable

`NoAutoUpdate=1` alone does **not** stop update services from starting. On boot,
Update Orchestrator / Medic scheduled tasks and service FailureActions can rewrite
`Start` and bring `wuauserv` / `UsoSvc` back.

The Defender SYSTEM + SOFTWARE pair therefore also sets:

- **SYSTEM:** `wuauserv`, `WaaSMedicSvc`, `UsoSvc`, `uhssvc`, `BITS` → `Start=4`,
  plus FailureActions “take no action” (no restart-on-fail)
- **SOFTWARE:** deletes the entire TaskCache Tree folders
  `UpdateOrchestrator`, `WaaSMedic`, and `WindowsUpdate` (not individual
  children — avoids missing version-specific task names; Defender tasks stay
  listed individually)
- **SOFTWARE policies (already present):** `NoAutoUpdate=1`,
  `DisableWindowsUpdateAccess=1`

Prefer applying both Defender hive merges together so `UsoSvc` / `BITS` /
`uhssvc` are not only covered by `disable-services.reg`.

**Temporary re-enable (services.msc):** This pack stops *unattended*
reenable-on-boot; it does not ACL-lock the SCM Start type.

- `wuauserv`, `UsoSvc`, `BITS`, `uhssvc` can usually be set to Manual/Automatic
  and started as admin. FailureActions and TaskCache deletes do **not** block that.
- `WaaSMedicSvc` is often greyed out (TrustedInstaller ACL); Medic is not required
  for a one-shot manual update.
- Starting services alone is usually **not** enough while WU policies remain.
- Background/scheduled auto-runs stay mostly off until Windows recreates the
  deleted TaskCache trees (Feature Update / repair / reimport).

Checklist for a temporary update session:

1. In `services.msc` (or `sc config` / `sc start`): set `UsoSvc`, `BITS`,
   `wuauserv` to Manual (and `uhssvc` if needed); start them.
2. Temporarily clear WU policy blocks under
   `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` — set
   `DisableWindowsUpdateAccess` to `0` (or delete) and under `...\AU` set
   `NoAutoUpdate` to `0` (or delete).
3. Trigger update via Settings → Windows Update, or an Orchestrator kick
   (e.g. `UsoClient.exe StartScan` where available).
4. When done: stop the services, set Start back to Disabled (`4`), restore the
   two policy DWORDs to `1` if you want the pack’s behavior again.
5. Optional: leave Medic disabled; do not expect deleted TaskCache trees to
   return until Windows recreates them.

### 8. Tamper Protection and Avast

**Tamper Protection:** Offline hive merges bypass live `WdFilter` registry
callbacks. The pack sets both:

- `HKLM\SOFTWARE\Microsoft\Windows Defender\Features\TamperProtection=0`
  (the real local state used for first boot)
- `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Features\TamperProtection=0`

Together with Defender engines at `Start=4` (`WinDefend`, `WdFilter`, etc.),
Tamper Protection cannot re-arm settings at runtime because those services never
start. Residual risk: Feature Updates / repair can restore Defender services.

**Avast:** Disabling Defender engines is fine (one real-time AV). In the Defender
SYSTEM `.reg`:

- `mpssvc` is **enabled** (`Start=2`) — required; Avast manages firewall profiles
  while this service keeps running
- `wscsvc` stays **disabled** (`Start=4`) by choice — Avast may still protect;
  Windows Security Center status can look wrong (trust Avast’s own UI)
- `SecurityHealthService` stays **disabled** (UI only)

After first boot, verify with Avast’s UI and optionally:

```powershell
Get-MpComputerStatus | Select-Object IsTamperProtected, AMRunningMode, AntivirusEnabled
```

Expect Defender not actively protecting when its services are disabled.
