#!/usr/bin/env bash
# Offline harden/restore of Windows Update binaries and task XML.
# Windows must be shut down; pass the mount root of the Windows volume.
#
# Usage:
#   sudo ./install/offline-wu-files.sh disable [/mnt]
#   sudo ./install/offline-wu-files.sh enable  [/mnt]
#   sudo ./install/offline-wu-files.sh clean   [/mnt]

set -euo pipefail

usage() {
  echo "Usage: $0 disable|enable|clean [mount_root]" >&2
  echo "  mount_root defaults to /mnt" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
ACTION=$1
MOUNT=${2:-/mnt}

case "$ACTION" in
  disable|enable|clean) ;;
  *) usage ;;
esac

SYS32="$MOUNT/Windows/System32"
TASKS="$SYS32/Tasks/Microsoft/Windows"
TASKS_BAK="$SYS32/Tasks.bak-wu"

BINARIES=(
  WaaSMedicSvc.dll
  wuaueng.dll
  UsoClient.exe
)

TASK_TREES=(
  UpdateOrchestrator
  WaaSMedic
  WindowsUpdate
)

die() {
  echo "error: $*" >&2
  exit 1
}

need_mount() {
  [[ -d "$SYS32" ]] || die "Windows System32 not found at $SYS32 (bad mount root?)"
}

rel() {
  # path relative to mount for messages
  local p=$1
  echo "${p#"$MOUNT"/}"
}

cmd_disable() {
  need_mount

  local b tree
  for b in "${BINARIES[@]}"; do
    if [[ -e "$SYS32/$b.bak" ]]; then
      die "backup already exists: $(rel "$SYS32/$b.bak") — run clean first if originals were restored"
    fi
  done
  if [[ -e "$TASKS_BAK" ]]; then
    die "backup already exists: $(rel "$TASKS_BAK") — run clean first if live tasks were restored"
  fi

  for b in "${BINARIES[@]}"; do
    if [[ -e "$SYS32/$b" ]]; then
      mv -- "$SYS32/$b" "$SYS32/$b.bak"
      echo "renamed $(rel "$SYS32/$b") -> $(rel "$SYS32/$b.bak")"
    else
      echo "warning: missing $(rel "$SYS32/$b") — skipped" >&2
    fi
  done

  mkdir -p -- "$TASKS_BAK"
  for tree in "${TASK_TREES[@]}"; do
    if [[ -e "$TASKS/$tree" ]]; then
      cp -a -- "$TASKS/$tree" "$TASKS_BAK/$tree"
      rm -rf -- "$TASKS/$tree"
      echo "backed up and removed $(rel "$TASKS/$tree")"
    else
      echo "warning: missing $(rel "$TASKS/$tree") — skipped" >&2
    fi
  done

  # drop empty backup dir if nothing was copied
  if [[ -d "$TASKS_BAK" ]] && [[ -z "$(find "$TASKS_BAK" -mindepth 1 -print -quit)" ]]; then
    rmdir -- "$TASKS_BAK"
  fi

  echo "disable done"
}

cmd_enable() {
  need_mount

  local b tree has_bak=0
  for b in "${BINARIES[@]}"; do
    if [[ -e "$SYS32/$b.bak" ]]; then
      has_bak=1
      if [[ -e "$SYS32/$b" ]]; then
        die "original exists alongside backup: $(rel "$SYS32/$b") and $(rel "$SYS32/$b.bak") — run clean first"
      fi
    fi
  done
  if [[ -e "$TASKS_BAK" ]]; then
    has_bak=1
  fi
  [[ $has_bak -eq 1 ]] || die "nothing to restore (no .bak files and no Tasks.bak-wu)"

  for b in "${BINARIES[@]}"; do
    if [[ -e "$SYS32/$b.bak" ]]; then
      mv -- "$SYS32/$b.bak" "$SYS32/$b"
      echo "restored $(rel "$SYS32/$b")"
    fi
  done

  if [[ -d "$TASKS_BAK" ]]; then
    mkdir -p -- "$TASKS"
    for tree in "${TASK_TREES[@]}"; do
      if [[ -e "$TASKS_BAK/$tree" ]]; then
        if [[ -e "$TASKS/$tree" ]]; then
          die "live task tree exists alongside backup: $(rel "$TASKS/$tree") — run clean first"
        fi
        mv -- "$TASKS_BAK/$tree" "$TASKS/$tree"
        echo "restored $(rel "$TASKS/$tree")"
      fi
    done
    rmdir --ignore-fail-on-non-empty -- "$TASKS_BAK" 2>/dev/null || rm -rf -- "$TASKS_BAK"
  fi

  echo "enable done"
}

cmd_clean() {
  need_mount

  local b tree cleaned=0 any_live_task=0

  for b in "${BINARIES[@]}"; do
    if [[ -e "$SYS32/$b" && -e "$SYS32/$b.bak" ]]; then
      rm -f -- "$SYS32/$b.bak"
      echo "removed stale backup $(rel "$SYS32/$b.bak") (original present)"
      cleaned=1
    fi
  done

  for tree in "${TASK_TREES[@]}"; do
    if [[ -e "$TASKS/$tree" ]]; then
      any_live_task=1
      break
    fi
  done

  if [[ $any_live_task -eq 1 && -e "$TASKS_BAK" ]]; then
    rm -rf -- "$TASKS_BAK"
    echo "removed stale backup $(rel "$TASKS_BAK") (live task trees present)"
    cleaned=1
  fi

  if [[ $cleaned -eq 0 ]]; then
    echo "nothing to clean"
  else
    echo "clean done"
  fi
}

case "$ACTION" in
  disable) cmd_disable ;;
  enable)  cmd_enable ;;
  clean)   cmd_clean ;;
esac
