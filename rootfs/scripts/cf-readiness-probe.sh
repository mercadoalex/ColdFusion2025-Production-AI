#!/usr/bin/env bash
# =============================================================================
# cf-readiness-probe.sh
# Waits for ColdFusion (port 8500) and Lucee (port 8888) to be accepting
# HTTP connections before marking the service ready.
#
# Runs as a oneshot systemd unit at boot.  Completes in 5-10 s on a warm JVM
# image; up to 60 s on first cold boot.
# =============================================================================
set -euo pipefail

CF_PORT=8500
LUCEE_PORT=8888
MAX_WAIT=150   # seconds
POLL_INTERVAL=2

log() { echo "[readiness-probe] $*"; }

wait_for_port() {
  local label="$1"
  local port="$2"
  local elapsed=0

  log "Waiting for ${label} on port ${port}..."
  while ! nc -z 127.0.0.1 "${port}" 2>/dev/null; do
    if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
      log "TIMEOUT: ${label} did not open port ${port} within ${MAX_WAIT}s"
      return 1
    fi
    sleep "${POLL_INTERVAL}"
    elapsed=$(( elapsed + POLL_INTERVAL ))
    log "  ... still waiting for ${label} (${elapsed}/${MAX_WAIT}s)"
  done
  log "${label} is up on port ${port} (after ${elapsed}s)"
}

# ── ColdFusion is mandatory ───────────────────────────────────────────────────
wait_for_port "ColdFusion 2025" "${CF_PORT}"

# ── Lucee is optional (graceful timeout, not a hard failure) ─────────────────
wait_for_port "Lucee/CommandBox" "${LUCEE_PORT}" || \
  log "WARNING: Lucee not ready — CommandBox server may not have started yet."

log "All services ready. Playground is open."

# ── Auto-seed the training_db ─────────────────────────────────────────────────
# Hit seed-db.cfm once so tables and data exist before students run any queries.
# Safe to call repeatedly — the CFM skips inserts if data is already present.
log "Seeding training_db..."
SEED_RESULT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8500/seed-db.cfm 2>/dev/null || echo "failed")
if [ "${SEED_RESULT}" = "200" ]; then
  log "training_db seeded OK."
else
  log "WARNING: seed-db.cfm returned ${SEED_RESULT} — DB may not be populated."
fi

# Write a ready-flag file that init tasks can test
touch /run/cf-training-ready
