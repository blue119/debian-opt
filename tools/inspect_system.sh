#!/usr/bin/env bash
# Read-only system inspector for Debian + AwesomeWM.

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/output"
OUT="$OUTPUT_DIR/baseline_report.txt"

mkdir -p "$OUTPUT_DIR"

section() {
  printf '\n=== %s ===\n' "$1"
}

run_if_available() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    printf '[not installed] %s\n' "$command_name"
  fi
}

{
  printf 'Generated: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
  printf 'Inspector privilege: uid=%s (no privilege escalation)\n' "$(id -u)"

  section '1. SYSTEM & KERNEL'
  uname -a 2>&1 || true
  run_if_available lsb_release -ds

  section '2. MEMORY & SWAP'
  run_if_available free -h
  run_if_available swapon --show
  if command -v sysctl >/dev/null 2>&1; then
    sysctl vm.swappiness vm.vfs_cache_pressure vm.dirty_ratio \
      vm.dirty_background_ratio 2>&1 || true
  fi

  section '3. DISK & MOUNTS'
  run_if_available lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,DISC-MAX
  if [[ -r /etc/fstab ]]; then
    # Redact common credential-bearing mount options from the report.
    sed -E \
      -e 's/(password|passwd|credentials|username|user)=[^,[:space:]]+/\1=REDACTED/gI' \
      -e '/^[[:space:]]*#/d' \
      -e '/^[[:space:]]*$/d' /etc/fstab
  else
    printf '[unreadable] /etc/fstab\n'
  fi

  section '4. BOOT PERFORMANCE'
  if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze time 2>&1 || true
    systemd-analyze blame 2>&1 | head -n 25 || true
  else
    printf '[not installed] systemd-analyze\n'
  fi

  section '5. RUNNING SYSTEM SERVICES'
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --state=running --no-pager 2>&1 || true
  else
    printf '[not installed] systemctl\n'
  fi

  section '6. RUNNING USER SERVICES'
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user list-units --type=service --state=running --no-pager \
      2>&1 || true
  else
    printf '[not installed] systemctl\n'
  fi

  section '7. TOP MEMORY PROCESSES'
  if ps aux --sort=-%mem >/dev/null 2>&1; then
    ps aux --sort=-%mem | head -n 25 || true
  else
    ps aux | head -n 25 || true
  fi

  section '8. AWESOMEWM & PICOM FILE PRESENCE'
  for candidate in \
    "$HOME/.config/awesome/rc.lua" \
    "$HOME/.config/picom.conf" \
    /etc/xdg/picom.conf; do
    if [[ -e "$candidate" ]]; then
      printf 'present: %s\n' "$candidate"
    else
      printf 'absent:  %s\n' "$candidate"
    fi
  done

  section '9. APT & JOURNAL CONFIG'
  if command -v apt-config >/dev/null 2>&1; then
    apt-config dump 2>&1 | grep -E 'Install-Recommends|Install-Suggests' || true
  else
    printf '[not installed] apt-config\n'
  fi
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --disk-usage 2>&1 || true
  else
    printf '[not installed] journalctl\n'
  fi

  section '10. RELEVANT OPTIONAL SERVICES (STATE ONLY)'
  if command -v systemctl >/dev/null 2>&1; then
    for unit in \
      bluetooth.service cups.service cups-browsed.service ModemManager.service \
      avahi-daemon.service packagekit.service speech-dispatcher.service \
      fstrim.timer; do
      printf '%-32s enabled=%-10s active=%s\n' \
        "$unit" \
        "$(systemctl is-enabled "$unit" 2>/dev/null || true)" \
        "$(systemctl is-active "$unit" 2>/dev/null || true)"
    done
  fi
} >"$OUT"

printf 'Done. Read-only report saved to %s\n' "$OUT"
