#!/usr/bin/env bash
# =============================================================================
# get-act-runner.sh — Install and register Gitea Act Runner on cf-dev
#
# What this does:
#   1. Downloads the Gitea Act Runner binary
#   2. Writes a config.yaml (labels include ubuntu-latest so workflows
#      that use runs-on: ubuntu-latest are picked up)
#   3. Registers the runner against the local Gitea instance using a
#      shared registration token generated at runtime
#   4. Installs act-runner.service so it starts automatically at boot
#
# The registration step runs After=gitea-create-admin.service so Gitea
# is fully up and the token API is available.
# =============================================================================
set -eu

ACT_RUNNER_VERSION=${ACT_RUNNER_VERSION:-0.2.10}
ACT_RUNNER_BIN=/usr/local/bin/act_runner
ACT_RUNNER_HOME=/var/lib/act_runner

echo ">>> Downloading Gitea Act Runner ${ACT_RUNNER_VERSION}..."
curl -fsSL \
  "https://dl.gitea.com/act_runner/${ACT_RUNNER_VERSION}/act_runner-${ACT_RUNNER_VERSION}-linux-amd64" \
  -o "${ACT_RUNNER_BIN}"
chmod +x "${ACT_RUNNER_BIN}"

echo ">>> Creating act_runner directories..."
mkdir -p "${ACT_RUNNER_HOME}"

echo ">>> Writing Act Runner config..."
cat > "${ACT_RUNNER_HOME}/config.yaml" << 'CONF'
runner:
  labels:
    - "ubuntu-latest:docker://node:20-bookworm-slim"
    - "ubuntu-22.04:docker://node:20-bookworm-slim"
    - "ubuntu-20.04:docker://node:20-bookworm-slim"
    - "self-hosted:host"
CONF

echo ">>> Writing act-runner-register.sh (runs at first boot after Gitea is up)..."
cat > /usr/local/bin/act-runner-register << 'SCRIPT'
#!/bin/bash
# Wait for Gitea to be fully ready, then register the runner.
# Runs once at VM boot via act-runner-register.service.
set -eu

ACT_RUNNER_HOME=/var/lib/act_runner
GITEA_URL=http://localhost:3000

# Wait up to 60 s for Gitea API
for i in $(seq 1 30); do
  if curl -sf "${GITEA_URL}/api/v1/version" -o /dev/null 2>/dev/null; then
    break
  fi
  sleep 2
done

# Skip if already registered
if [ -f "${ACT_RUNNER_HOME}/.runner" ]; then
  echo "Act Runner already registered — skipping."
  exit 0
fi

# Generate a shared runner registration token via Gitea admin API
TOKEN=$(curl -s -X POST "${GITEA_URL}/api/v1/admin/runners/registration-token" \
  -u labadmin:labpassword \
  -H "Content-Type: application/json" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")

if [ -z "${TOKEN}" ]; then
  echo "ERROR: Could not obtain runner registration token from Gitea" >&2
  exit 1
fi

# Register the runner (non-interactive)
/usr/local/bin/act_runner register \
  --no-interactive \
  --instance "${GITEA_URL}" \
  --token "${TOKEN}" \
  --name "cf-dev-runner" \
  --labels "ubuntu-latest,ubuntu-22.04,ubuntu-20.04,self-hosted" \
  --config "${ACT_RUNNER_HOME}/config.yaml" \
  --working-dir "${ACT_RUNNER_HOME}"

echo "Act Runner registered successfully."
SCRIPT
chmod +x /usr/local/bin/act-runner-register

echo ">>> Writing act-runner-register.service..."
cat > /etc/systemd/system/act-runner-register.service << 'SVC'
[Unit]
Description=Register Gitea Act Runner on first boot
After=gitea-create-admin.service
Requires=gitea.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/act-runner-register
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC

echo ">>> Writing act-runner.service..."
cat > /etc/systemd/system/act-runner.service << 'SVC'
[Unit]
Description=Gitea Act Runner
After=act-runner-register.service
Requires=gitea.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon --config /var/lib/act_runner/config.yaml
Restart=on-failure
RestartSec=5s
StandardOutput=append:/var/lib/act_runner/act-runner.log
StandardError=append:/var/lib/act_runner/act-runner.log

[Install]
WantedBy=multi-user.target
SVC

systemctl enable act-runner-register.service
systemctl enable act-runner.service

echo ">>> Gitea Act Runner ${ACT_RUNNER_VERSION} installed."
