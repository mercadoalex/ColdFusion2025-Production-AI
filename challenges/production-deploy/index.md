---
kind: challenge

title: 'Deploy a ColdFusion App from cf-dev to cf-prod'

description: |
  Set up passwordless SSH from cf-dev to cf-prod, write a deployment script
  that syncs the CF webroot with rsync, drop a timestamped marker file on
  cf-prod, and confirm ColdFusion is serving on the production VM.

categories:
  - programming

tagz:
  - coldfusion
  - deployment
  - ssh
  - devops

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-devops-3039c6bb

tasks:
  ssh_keys_configured:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f "/home/laborant/.ssh/id_ed25519" ]; then
        echo "SSH private key not found at ~/.ssh/id_ed25519"
        exit 1
      fi
      if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               laborant@cf-prod "echo ok" 2>/dev/null | grep -q "ok"; then
        echo "Cannot SSH to cf-prod without a password — run ssh-copy-id first"
        exit 1
      fi
      echo "Passwordless SSH from cf-dev to cf-prod works ✓"
    hintcheck: |
      echo "Run on cf-dev:"
      echo "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N \"\""
      echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub laborant@cf-prod"
      echo "  ssh laborant@cf-prod 'echo ok'"

  deploy_script_exists:
    machine: cf-dev
    user: laborant
    needs:
      - ssh_keys_configured
    run: |
      if [ ! -f "/home/laborant/deploy.sh" ]; then
        echo "deploy.sh not found at /home/laborant/deploy.sh"
        exit 1
      fi
      if ! grep -q "cf-prod" /home/laborant/deploy.sh; then
        echo "deploy.sh does not reference cf-prod"
        exit 1
      fi
      if ! grep -q "rsync" /home/laborant/deploy.sh; then
        echo "deploy.sh does not use rsync"
        exit 1
      fi
      echo "deploy.sh found and references cf-prod and rsync ✓"
    hintcheck: |
      echo "Create /home/laborant/deploy.sh that:"
      echo "  - uses rsync to sync /opt/coldfusion2025/cfusion/wwwroot/ to cf-prod"
      echo "  - writes a deploy_marker.txt with a UTC timestamp via SSH"
      echo "  - references the hostname cf-prod"

  marker_on_prod:
    machine: cf-prod
    user: laborant
    needs:
      - deploy_script_exists
    run: |
      if [ ! -f "/opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt" ]; then
        echo "deploy_marker.txt not found on cf-prod — run ~/deploy.sh on cf-dev first"
        exit 1
      fi
      echo "Deployment marker present on cf-prod ✓"
    hintcheck: |
      echo "Run ~/deploy.sh on the cf-dev terminal, then check cf-prod:"
      echo "  cat /opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt"

  cf_prod_responds:
    machine: cf-prod
    user: laborant
    needs:
      - marker_on_prod
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/index.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "ColdFusion on cf-prod not responding (HTTP ${STATUS})"
        exit 1
      fi
      echo "ColdFusion on cf-prod is serving HTTP 200 ✓"
    hintcheck: |
      echo "Check ColdFusion is running on cf-prod:"
      echo "  curl -s -o /dev/null -w \"%{http_code}\" http://localhost:8500/index.cfm"
      echo "If CF is not running: sudo systemctl start cf-server"
---

## Deploy a ColdFusion App from cf-dev to cf-prod

Work through four tasks that build the complete deployment pipeline: SSH key setup, a deployment script, a verification marker, and a live HTTP check on cf-prod.

All commands run on the **Terminal (dev)** tab unless otherwise noted.

---

### Task 1 — Set up passwordless SSH from cf-dev to cf-prod

Generate an SSH key pair on cf-dev and copy the public key to cf-prod so scripts can connect without a password prompt:

```bash
# Generate an ed25519 key pair with no passphrase
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy the public key to cf-prod
ssh-copy-id -i ~/.ssh/id_ed25519.pub laborant@cf-prod

# Verify — you should see "SSH works" with no password prompt
ssh laborant@cf-prod "echo SSH works"
```

::simple-task
---
:tasks: tasks
:name: ssh_keys_configured
---
#active
Generate `~/.ssh/id_ed25519` on cf-dev and copy it to cf-prod with `ssh-copy-id`. Confirm `ssh laborant@cf-prod "echo ok"` returns without a password prompt.

#completed
Passwordless SSH from cf-dev to cf-prod works. ✓
::

---

### Task 2 — Write the deployment script

Create `/home/laborant/deploy.sh` that syncs the CF webroot to cf-prod and drops a timestamped marker file:

```bash
tee /home/laborant/deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

WWWROOT="/opt/coldfusion2025/cfusion/wwwroot"
PROD_HOST="cf-prod"
PROD_USER="laborant"

echo "[deploy] Syncing wwwroot to ${PROD_HOST}..."
rsync -avz --delete \
  --exclude="*.log" \
  --exclude=".git" \
  "${WWWROOT}/" \
  "${PROD_USER}@${PROD_HOST}:${WWWROOT}/"

ssh "${PROD_USER}@${PROD_HOST}" \
  "echo 'deployed at $(date -u +%Y-%m-%dT%H:%M:%SZ)' \
   > ${WWWROOT}/deploy_marker.txt"

echo "[deploy] Done."
EOF

chmod +x /home/laborant/deploy.sh
```

::simple-task
---
:tasks: tasks
:name: deploy_script_exists
---
#active
Create `/home/laborant/deploy.sh` referencing `cf-prod` and using `rsync` to sync the webroot.

#completed
deploy.sh found — references cf-prod and rsync. ✓
::

---

### Task 3 — Run the script and confirm the marker on cf-prod

Run the deployment script from cf-dev:

```bash
~/deploy.sh
```

Then check the marker landed on cf-prod (either from the **Terminal (dev)** tab via SSH, or from the **Terminal (prod)** tab directly):

```bash
# From Terminal (dev)
ssh laborant@cf-prod "cat /opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt"

# Or from Terminal (prod)
cat /opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt
```

Expected output: `deployed at 2026-09-03T14:32:11Z`

::simple-task
---
:tasks: tasks
:name: marker_on_prod
---
#active
Run `~/deploy.sh` on cf-dev and confirm `deploy_marker.txt` exists on cf-prod under the CF webroot.

#completed
Deployment marker present on cf-prod. ✓
::

---

### Task 4 — Confirm ColdFusion is serving on cf-prod

From the **Terminal (prod)** tab, curl the default CF page:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8500/index.cfm
```

Expected: `200`

::simple-task
---
:tasks: tasks
:name: cf_prod_responds
---
#active
Confirm `http://localhost:8500/index.cfm` on cf-prod returns HTTP 200.

#completed
ColdFusion on cf-prod is serving HTTP 200. ✓
::
