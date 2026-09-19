#!/usr/bin/env bash
# =============================================================================
# get-gitea.sh — Install Gitea as a pre-baked service on cf-dev
#
# What this does:
#   1. Downloads the Gitea binary (~100 MB) to /usr/local/bin/gitea
#   2. Creates the 'git' system user and required directories
#   3. Writes a minimal app.ini config (SQLite, port 3000)
#   4. Creates the admin user (labadmin / labpassword)
#
# The gitea.service systemd unit starts Gitea at VM boot automatically.
# Students open the Gitea tab immediately — no waiting, no downloads.
# =============================================================================
set -eu

GITEA_VERSION=${GITEA_VERSION:-1.22.3}
GITEA_ARCH=${GITEA_ARCH:-linux-amd64}
GITEA_BIN=/usr/local/bin/gitea

echo ">>> Downloading Gitea ${GITEA_VERSION}..."
curl -fsSL \
  "https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-${GITEA_ARCH}" \
  -o "${GITEA_BIN}"
chmod +x "${GITEA_BIN}"

echo ">>> Creating git system user..."
useradd --system --shell /bin/bash --home /var/lib/gitea --create-home git 2>/dev/null || true

echo ">>> Creating Gitea directories..."
mkdir -p /var/lib/gitea/{custom,data,log} /etc/gitea
chown -R git:git /var/lib/gitea /etc/gitea
chmod 770 /etc/gitea

echo ">>> Writing app.ini..."
cat > /etc/gitea/app.ini << 'CONF'
[server]
HTTP_PORT = 3000
ROOT_URL  = http://localhost:3000/

[database]
DB_TYPE = sqlite3
PATH    = /var/lib/gitea/data/gitea.db

[security]
INSTALL_LOCK   = true
SECRET_KEY     = labsecretkey12345678

[service]
DISABLE_REGISTRATION = true

[log]
MODE  = file
LEVEL = Warn
ROOT_PATH = /var/lib/gitea/log
CONF

chown git:git /etc/gitea/app.ini
chmod 640 /etc/gitea/app.ini

echo ">>> Initialising Gitea DB and creating admin user..."
# Run as git user to initialise the DB, then create the admin account
sudo -u git "${GITEA_BIN}" admin user create \
  --config /etc/gitea/app.ini \
  --username labadmin \
  --password labpassword \
  --email lab@localhost \
  --admin \
  --must-change-password=false 2>/dev/null || true

echo ">>> Gitea ${GITEA_VERSION} installed at ${GITEA_BIN}"
