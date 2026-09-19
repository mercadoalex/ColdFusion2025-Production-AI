#!/usr/bin/env bash
# =============================================================================
# lucee-inject-h2.sh
# Copies the H2 JDBC driver from the Adobe CF installation into every
# Lucee server home found under /opt/commandbox/server/.
# Runs as ExecStartPre in lucee-server.service on every boot — idempotent.
# =============================================================================
set -euo pipefail

H2_SRC="/opt/coldfusion2025/cfusion/lib/h2-2.2.224.jar"
CB_SERVER_ROOT="/opt/commandbox/server"

if [ ! -f "${H2_SRC}" ]; then
  echo "[lucee-inject-h2] WARNING: ${H2_SRC} not found — skipping H2 injection"
  exit 0
fi

# Find all Lucee server homes — may be 0 on very first boot (not yet unpacked)
for lucee_home in "${CB_SERVER_ROOT}"/*/lucee-*/; do
  lib_dir="${lucee_home}WEB-INF/lucee-server/context/lib"
  dest="${lib_dir}/h2-2.2.224.jar"
  if [ ! -f "${dest}" ]; then
    mkdir -p "${lib_dir}"
    cp "${H2_SRC}" "${dest}"
    echo "[lucee-inject-h2] Copied H2 jar → ${dest}"
  else
    echo "[lucee-inject-h2] H2 jar already present at ${dest}"
  fi
done
