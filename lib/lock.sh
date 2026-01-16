#!/usr/bin/env bash
# --------------------------------------------------
# GingerStack lock library
# --------------------------------------------------

lock_init() {
  LOCK_NAME="${1:-gingerstack-installer}"
  LOCK_DIR="${LOCK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  LOCKFILE="$LOCK_DIR/${LOCK_NAME}.lock"

  mkdir -p "$LOCK_DIR"

  exec 9>"$LOCKFILE" || {
    echo "ERROR: Cannot open lockfile: $LOCKFILE"
    exit 1
  }

  if ! flock -n 9; then
    echo "ERROR: Another instance is already running."
    echo
    lock_show
    exit 1
  fi

  lock_write
  trap lock_cleanup EXIT INT TERM
}

lock_write() {
  cat >"$LOCKFILE" <<EOF
GINGERSTACK LOCK
────────────────────────────────
LOCK_NAME : $LOCK_NAME
PID       : $$
PPID      : $PPID
USER      : $(id -un)
HOST      : $(hostname)
STARTED   : $(date -Is)
SCRIPT    : ${0}
WORKDIR   : $(pwd)
BASH      : $BASH_VERSION
EOF
}

lock_show() {
  if [[ -f "$LOCKFILE" ]]; then
    echo "Lockfile: $LOCKFILE"
    echo "────────────────────────────────"
    cat "$LOCKFILE"
    echo "────────────────────────────────"

    local pid
    pid=$(grep '^PID' "$LOCKFILE" 2>/dev/null | awk '{print $3}')
    if [[ -n "$pid" ]]; then
      if kill -0 "$pid" 2>/dev/null; then
        echo "Status : RUNNING (PID $pid)"
      else
        echo "Status : STALE (process not running)"
        echo "Hint   : You may safely remove the lockfile"
      fi
    fi
  else
    echo "No lockfile present."
  fi
}

lock_update() {
  # Append runtime info (progress markers, phases, etc.)
  echo "$(date -Is) | $*" >>"$LOCKFILE"
}

lock_cleanup() {
  flock -u 9 2>/dev/null || true
  rm -f "$LOCKFILE"
}

lock_force_clear() {
  echo "Forcing lock removal:"
  echo "  $LOCKFILE"
  rm -f "$LOCKFILE"
}
