TODO:
- remove 'Windows Defender'
- sc delete wuauserv - only way to disable update ???

================================================================================
Apply .reg files from Linux (offline hive with hivex)
================================================================================

Use hivexregedit to merge Windows .reg files into an offline registry hive.
chntpw is better for interactive edits; prefer hivex for batch .reg imports.

WARNING: Offline merges rewrite critical Windows files under
Windows\System32\config\ (and user NTUSER.DAT). Always back up the hive first.
Windows must be shut down cleanly (not hibernated / Fast Startup) before you
edit its hives.

--------------------------------------------------------------------------------
1. Install tools (Arch)
--------------------------------------------------------------------------------

  sudo pacman -S hivex dos2unix

Verify: packages install with no errors.

--------------------------------------------------------------------------------
2. Map root keys to hive files
--------------------------------------------------------------------------------

With the Windows partition mounted at /mnt:

  HKEY_LOCAL_MACHINE\SOFTWARE  ->  /mnt/Windows/System32/config/SOFTWARE
  HKEY_LOCAL_MACHINE\SYSTEM    ->  /mnt/Windows/System32/config/SYSTEM
  HKEY_CURRENT_USER\...        ->  /mnt/Users/<Username>/NTUSER.DAT
                                   (or Users\Default\NTUSER.DAT for the default profile)

Files in this folder (one hive per .reg — never mix SYSTEM and SOFTWARE):

  disable-services.reg                                    -> SYSTEM
  utc-time.reg                                            -> SYSTEM
  Disable_Windows_Defender_Security_Center-SYSTEM.reg     -> SYSTEM
  Disable_Windows_Defender_Security_Center-SOFTWARE.reg   -> SOFTWARE
  explorer-settings.reg                                   -> NTUSER.DAT (HKCU only;
                                                            UTF-8; parent keys declared)

hivexregedit edits one physical hive file at a time. A .reg that contains both
HKEY_LOCAL_MACHINE\SYSTEM\... and HKEY_LOCAL_MACHINE\SOFTWARE\... keys will
fail when the first SOFTWARE block is reached if you only passed the SYSTEM
hive (and the reverse). Split mixed files before merging.

--------------------------------------------------------------------------------
3. Back up the target hive
--------------------------------------------------------------------------------

SYSTEM:

  sudo cp /mnt/Windows/System32/config/SYSTEM \
          /mnt/Windows/System32/config/SYSTEM.bak

SOFTWARE:

  sudo cp /mnt/Windows/System32/config/SOFTWARE \
          /mnt/Windows/System32/config/SOFTWARE.bak

Verify:

  ls /mnt/Windows/System32/config/SYSTEM.bak
  ls /mnt/Windows/System32/config/SOFTWARE.bak

For explorer-settings.reg, back up that user's NTUSER.DAT the same way.

--------------------------------------------------------------------------------
4. Convert .reg encoding to UTF-8 + LF
--------------------------------------------------------------------------------

Windows regedit often exports UTF-16LE with CRLF. hivexregedit expects local
UTF-8 (or ASCII) with Unix line endings.

Check first:

  file install/*.reg

If the file is UTF-16LE:

  iconv -f utf-16le -t utf-8 < install/your.reg | dos2unix > /tmp/converted.reg

If it is already UTF-8 / ASCII (Defender splits, disable-services.reg,
explorer-settings.reg, and often utc-time.reg), still normalize line endings:

  dos2unix -n install/your.reg /tmp/converted.reg

Verify:

  file /tmp/converted.reg
  # expect "UTF-8 Unicode text" or "ASCII text", not UTF-16

Ignore Perl locale warnings from hivexregedit; they are unrelated to merge
success or failure.

--------------------------------------------------------------------------------
5. CurrentControlSet (SYSTEM hive only)
--------------------------------------------------------------------------------

CurrentControlSet is a live Windows alias. It does NOT exist in the offline
SYSTEM hive. Keys must target ControlSet001 (or whichever set Select\Current
points to).

Find the active control set:

  sudo hivexregedit --export \
    --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
    /mnt/Windows/System32/config/SYSTEM '\Select'

If "Current"=dword:00000001, use ControlSet001.
If "Current"=dword:00000002, use ControlSet002.

Rewrite paths in the converted .reg before merging when needed:

  sed 's/CurrentControlSet/ControlSet001/g' /tmp/converted.reg > /tmp/merged.reg

(Replace ControlSet001 with the set from Select\Current.)

Note: Disable_Windows_Defender_Security_Center-SYSTEM.reg and
disable-services.reg already use ControlSet001. utc-time.reg still uses
CurrentControlSet and MUST be rewritten before an offline merge.

--------------------------------------------------------------------------------
6. Declare missing parent keys (SOFTWARE policies)
--------------------------------------------------------------------------------

hivexregedit does not create missing ancestor keys. If you merge a deep path
like ...\WindowsUpdate\AU and the parents do not exist yet, the merge fails.

For each missing ancestor, declare an empty key block, then a blank line,
then the next key. A blank line is required: without it, hivexregedit stays
inside the previous key and reports
"parse error: unexpected text found ... near [HKEY_...]".

Example (already done in
Disable_Windows_Defender_Security_Center-SOFTWARE.reg):

  [HKEY_LOCAL_MACHINE\SOFTWARE\Policies]

  [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft]

  [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows]

  [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate]

  [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
  "NoAutoUpdate"=dword:00000001

Do the same for any other deep paths that may be missing on a fresh install.

--------------------------------------------------------------------------------
7. Merge into the hives
--------------------------------------------------------------------------------

SYSTEM (after ControlSet rewrite when required):

  sudo hivexregedit --merge /mnt/Windows/System32/config/SYSTEM \
    --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
    /tmp/merged.reg

Defender SYSTEM half (already ControlSet001; convert encoding first):

  dos2unix -n install/Disable_Windows_Defender_Security_Center-SYSTEM.reg \
    /tmp/defender-system.reg
  sudo hivexregedit --merge /mnt/Windows/System32/config/SYSTEM \
    --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' \
    /tmp/defender-system.reg

Defender SOFTWARE half (parents already declared in the file):

  dos2unix -n install/Disable_Windows_Defender_Security_Center-SOFTWARE.reg \
    /tmp/defender-software.reg
  sudo hivexregedit --merge /mnt/Windows/System32/config/SOFTWARE \
    --prefix 'HKEY_LOCAL_MACHINE\SOFTWARE' \
    /tmp/defender-software.reg

HKCU / explorer-settings.reg (merge into the target user's NTUSER.DAT;
this profile on disk is often /mnt/Users/-/NTUSER.DAT):

  dos2unix -n install/explorer-settings.reg /tmp/explorer.reg
  sudo cp /mnt/Users/<Username>/NTUSER.DAT \
          /mnt/Users/<Username>/NTUSER.DAT.bak
  sudo hivexregedit --merge /mnt/Users/<Username>/NTUSER.DAT \
    --prefix 'HKEY_CURRENT_USER' \
    /tmp/explorer.reg

Success is usually silent (no Perl error traces about wrong hive / missing
parents). Windows will read the updated hives on next boot.

To undo: copy the .bak hive back over the original (while Windows is still offline).
