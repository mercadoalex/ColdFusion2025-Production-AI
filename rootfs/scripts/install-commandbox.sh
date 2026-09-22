#!/usr/bin/env bash
# =============================================================================
# install-commandbox.sh
# Installs CommandBox CLI via the official Ortus APT repository (Ubuntu/Debian).
# Pre-bakes a Lucee 5 server configuration for the student app at ~/app/
# =============================================================================
set -euo pipefail

CB_VERSION="${COMMANDBOX_VERSION:-6.3.4}"
CB_HOME="${COMMANDBOX_HOME:-/opt/commandbox}"
LUCEE_VERSION="${LUCEE_VERSION:-7.0.4.34}"
APP_DIR="/home/${LAB_USER:-laborant}/app"

# ─── Java check ──────────────────────────────────────────────────────────────
# CF's bundled JRE is at /opt/coldfusion2025/jre (on PATH via Dockerfile ENV).
if ! command -v java >/dev/null 2>&1; then
  echo "[BOX] WARNING: java not found on PATH. Will proceed anyway."
fi

# ─── Install CommandBox via Ortus APT repo ───────────────────────────────────
echo "[BOX] Installing CommandBox via APT..."

# 1. Add Ortus GPG key
curl -fsSL https://downloads.ortussolutions.com/debs/gpg \
  | gpg --dearmor -o /usr/share/keyrings/ortus-commandbox.gpg

# 2. Add the stable APT source
echo "deb [signed-by=/usr/share/keyrings/ortus-commandbox.gpg] \
https://downloads.ortussolutions.com/debs/noarch /" \
  > /etc/apt/sources.list.d/commandbox.list

# 3. Install
apt-get update -qq
apt-get install -y commandbox
apt-get clean
rm -rf /var/lib/apt/lists/*

# 4. Verify
box version || { echo "[BOX] ERROR: box CLI not functional"; exit 1; }
echo "[BOX] CommandBox installed: $(box version 2>/dev/null)"

# ─── Pre-bake the student app scaffold ───────────────────────────────────────
echo "[BOX] Creating student app scaffold at ${APP_DIR}..."
mkdir -p "${APP_DIR}"

cat > "${APP_DIR}/.box.json" <<EOF
{
  "name": "cf-training-app",
  "version": "1.0.0",
  "description": "ColdFusion Training Starter App",
  "cfengine": "lucee@${LUCEE_VERSION}"
}
EOF

cat > "${APP_DIR}/server.json" <<EOF
{
  "name": "training-app",
  "app": {
    "cfengine": "lucee@${LUCEE_VERSION}",
    "webroot": "."
  },
  "web": {
    "http": {
      "port": 8888,
      "enable": true
    },
    "host": "0.0.0.0",
    "ssl": {
      "enable": false
    }
  },
  "jvm": {
    "heapSize": "512m",
    "minHeapSize": "256m",
    "args": "-cp /opt/coldfusion2025/cfusion/lib/h2-2.2.224.jar"
  },
  "openbrowser": false,
  "cfconfig": {
    "adminPassword": "training",
    "dataSources": {
      "training_db": {
        "type":             "Other",
        "class":            "org.h2.Driver",
        "connectionString": "jdbc:h2:mem:training_db;DB_CLOSE_DELAY=-1;DATABASE_TO_UPPER=FALSE",
        "username":         "sa",
        "password":         "",
        "blob":             false,
        "clob":             false,
        "connectionLimit":  -1,
        "connectionTimeout": 1,
        "storage":          false,
        "verify":           false,
        "custom":           ""
      }
    }
  }
}
EOF

# ─── Pre-bake Lucee engine cache ─────────────────────────────────────────────
# If lucee-engine-${LUCEE_VERSION}.zip is present in /tmp/cf-downloads/ (copied
# from downloads/ in the build context), we manually place it into the
# CommandBox engine cache so students get instant first-start with no download.
#
# Cache path: /opt/commandbox/engine/cfml/server/lucee_<version>/
# The service runs as laborant with COMMANDBOX_HOME=/opt/commandbox so the
# engine cache must live there — not under /root/.CommandBox (build-time user).
#
# IMPORTANT: CommandBox's ForgeBox provider resolves the cached artifact by the
# slug it downloads from ForgeBox. For Lucee the slug is "lucee" and CommandBox
# stores the zip as "lucee-light-<version>+0.zip" inside the cache directory.
# Using any other filename causes a cache miss and forces a live download.
LUCEE_ZIP="/tmp/cf-downloads/lucee-engine-${LUCEE_VERSION}.zip"
CB_ENGINE_CACHE="${CB_HOME}/engine/cfml/server/lucee_${LUCEE_VERSION}"
# ForgeBox artifact name CommandBox expects inside the cache directory:
CB_ENGINE_FILENAME="lucee-light-${LUCEE_VERSION}+0.zip"

if [ -f "${LUCEE_ZIP}" ]; then
  echo "[BOX] Pre-baking Lucee ${LUCEE_VERSION} engine cache from local ZIP..."
  mkdir -p "${CB_ENGINE_CACHE}"
  cp "${LUCEE_ZIP}" "${CB_ENGINE_CACHE}/${CB_ENGINE_FILENAME}"
  echo "[BOX] Lucee engine cached at ${CB_ENGINE_CACHE}/${CB_ENGINE_FILENAME}"

  # ── Inject H2 JDBC driver into the Lucee engine WAR at build time ──────────
  # Lucee ships as a WAR/ZIP. The server-wide JDBC lib path inside it is:
  #   WEB-INF/lucee-server/context/lib/
  # By injecting at build time we guarantee the driver is present when CommandBox
  # extracts the engine on first VM boot — no runtime inject script needed.
  H2_SRC="/opt/coldfusion2025/cfusion/lib/h2-2.2.224.jar"
  if [ -f "${H2_SRC}" ]; then
    echo "[BOX] Injecting H2 jar into Lucee engine ZIP..."
    INJECT_TMP=$(mktemp -d)
    cp "${CB_ENGINE_CACHE}/${CB_ENGINE_FILENAME}" "${INJECT_TMP}/lucee.zip"
    # Add the jar at the correct path inside the ZIP (zip merges if entry exists)
    ( cd "${INJECT_TMP}" && \
      mkdir -p WEB-INF/lucee-server/context/lib && \
      cp "${H2_SRC}" WEB-INF/lucee-server/context/lib/ && \
      zip -r lucee.zip WEB-INF/lucee-server/context/lib/h2-2.2.224.jar )
    cp "${INJECT_TMP}/lucee.zip" "${CB_ENGINE_CACHE}/${CB_ENGINE_FILENAME}"
    rm -rf "${INJECT_TMP}"
    echo "[BOX] H2 jar injected into Lucee engine ZIP."
  else
    echo "[BOX] WARNING: H2 jar not found at ${H2_SRC} — skipping injection."
  fi
else
  echo "[BOX] NOTE: lucee-engine-${LUCEE_VERSION}.zip not found in downloads/."
  echo "[BOX] Lucee will download on first box server start inside the VM (~60s)."
fi

# ─── Pre-bake ColdBox into the ForgeBox package cache ────────────────────────
# Same pattern as Lucee engine cache: if the zip is present in /tmp/cf-downloads/
# CommandBox finds it in the cache and skips the ForgeBox download entirely.
# Cache path: /opt/commandbox/packages/forgebox/coldbox/<version>/
# The file must be named coldbox-<version>.zip to match ForgeBox slug resolution.
COLDBOX_ZIP=$(ls /tmp/cf-downloads/coldbox-*.zip 2>/dev/null | sort -V | tail -1)
if [ -n "${COLDBOX_ZIP}" ]; then
  COLDBOX_VERSION=$(basename "${COLDBOX_ZIP}" | sed 's/coldbox-//;s/\.zip//')
  CB_PKG_CACHE="${CB_HOME}/packages/forgebox/coldbox/${COLDBOX_VERSION}"
  echo "[BOX] Pre-baking ColdBox ${COLDBOX_VERSION} package cache..."
  mkdir -p "${CB_PKG_CACHE}"
  cp "${COLDBOX_ZIP}" "${CB_PKG_CACHE}/coldbox-${COLDBOX_VERSION}.zip"
  echo "[BOX] ColdBox cached at ${CB_PKG_CACHE}/coldbox-${COLDBOX_VERSION}.zip"
else
  echo "[BOX] NOTE: No coldbox-*.zip found in downloads/ — students will download at runtime."
fi

# ─── PATH entry for all users ────────────────────────────────────────────────
cat > /etc/profile.d/commandbox.sh <<'PROFILE'
# CommandBox CLI + ColdFusion bundled JRE — added by cf-training rootfs
export JAVA_HOME="/opt/coldfusion2025/jre"
export PATH="$JAVA_HOME/bin:$PATH:/usr/bin"
PROFILE

# ─── Pre-create runtime directories so chown in Dockerfile Layer 9 covers them ──
# laborant user does not exist yet at this build stage — chown happens later.
# We just ensure the directories exist so box can write into them at runtime.
mkdir -p \
  "${CB_HOME}/engine/cfml/cli/lucee-server" \
  "${CB_HOME}/engine/cfml/cli/cfml-web" \
  "${CB_HOME}/logs" \
  "${CB_HOME}/temp" \
  "${CB_HOME}/servers"

echo "[BOX] CommandBox installation complete."
