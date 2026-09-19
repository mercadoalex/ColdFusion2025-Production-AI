---
kind: unit

title: Multi-VM Deployment & CF Admin Automation

name: multi-vm-deployment-cf-prod-unit-1
---

## The multi-VM deployment problem

In production, your application rarely lives on a single server. The advanced lab mirrors a realistic architecture: you develop on one VM (`cf-dev`) and promote releases to a separate production VM (`cf-prod`). Both run ColdFusion 2025, both are on the same private network, and both must stay in sync.

::image-box
---
:src: __static__/multi-vm-deployment-architecture-v1.png
:alt: Diagram showing two VMs on the same private network — cf-dev on the left with a developer icon, and cf-prod on the right with a server icon. An arrow labelled rsync over SSH points from cf-dev to cf-prod. A browser icon above cf-prod shows the production URL being verified.
:max-width: 900px
---
_cf-dev and cf-prod share the same private network — SSH and rsync move code between them._
::

| VM | Role | Hostname |
|---|---|---|
| `cf-dev` | Development — you write and test here | `cf-dev` |
| `cf-prod` | Production target — students deploy here | `cf-prod` |

The workflow you'll build: **write on `cf-dev` → test → push to `cf-prod` via `rsync` over SSH**.

---

## 1. Set up SSH key-based access

Password-based SSH is impractical for automated scripts. Key-based auth lets `cf-dev` connect to `cf-prod` without a password prompt.

::image-box
---
:src: __static__/ssh-key-setup-v1.png
:alt: Terminal showing three commands — ssh-keygen generating an ed25519 key pair with no passphrase, ssh-copy-id copying the public key to cf-prod, and ssh laborant@cf-prod "echo SSH works" returning the confirmation string
:max-width: 860px
---
_SSH key setup: generate → copy public key → test passwordless login._
::

**Activity:** In the **Terminal (dev)** tab, run these commands:

```bash
# Generate a key pair (accept all defaults — no passphrase for automation)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy the public key to cf-prod
ssh-copy-id -i ~/.ssh/id_ed25519.pub laborant@cf-prod

# Verify passwordless login works
ssh laborant@cf-prod "echo SSH works"
```

You should see `SSH works` printed without any password prompt.

::hint-box
---
:summary: 🔑 What is ssh-copy-id doing?
---
`ssh-copy-id` appends your public key to `~/.ssh/authorized_keys` on the remote machine. From then on, anyone with the matching private key can log in without a password. The private key (`~/.ssh/id_ed25519`) never leaves `cf-dev`.

In production systems, you'd use shorter-lived keys or certificate-based auth, but for lab and CI/CD pipelines, key-based auth with a passphrase-free key is the standard pattern.
::

::simple-task
---
:tasks: tasks
:name: verify_ssh_to_prod
---
#active
Run `ssh-keygen` and `ssh-copy-id` on cf-dev, then verify with `ssh laborant@cf-prod "echo ok"`.

#completed
SSH from cf-dev → cf-prod works without a password. ✓
::

---

## 2. Write a deployment script

A deployment script encodes your exact deploy procedure. It's reproducible, auditable, and can be triggered from CI.

::image-box
---
:src: __static__/deploy-script-vscode-v1.png
:alt: VS Code editor showing deploy.sh — a bash script with set -euo pipefail at the top, variables for WWWROOT and PROD_HOST, an rsync command syncing the webroot with --delete and --exclude flags, an SSH command writing a deploy_marker.txt with a UTC timestamp, and a curl command verifying cf-prod:8500 responds
:max-width: 860px
---
_deploy.sh — a self-documenting deployment script that syncs, marks, and verifies._
::

**Activity:** Create `/home/laborant/deploy.sh` on **cf-dev**:

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

# Drop a timestamp marker so we can verify the push
ssh "${PROD_USER}@${PROD_HOST}" \
  "echo 'deployed at $(date -u +%Y-%m-%dT%H:%M:%SZ)' \
   > ${WWWROOT}/deploy_marker.txt"

echo "[deploy] Done. Verifying prod..."
curl -sf http://${PROD_HOST}:8500/index.cfm > /dev/null && echo "[deploy] cf-prod responded OK"
EOF

chmod +x /home/laborant/deploy.sh
```

Run it:

```bash
~/deploy.sh
```

::hint-box
---
:summary: What does rsync --delete do?
---
`--delete` removes files on the destination that no longer exist on the source. Without it, deleted files would linger on cf-prod forever — a common source of "ghost" functionality and hard-to-debug differences between dev and prod.

Always pair `--delete` with `--exclude` patterns to protect log files, uploads directories, and other server-side data you don't want to wipe.
::

::simple-task
---
:tasks: tasks
:name: verify_deploy_script
---
#active
Create `/home/laborant/deploy.sh` that references `cf-prod` and run it successfully.

#completed
deploy.sh exists and references cf-prod. ✓
::

---

## 3. Verify the deployment

After running `deploy.sh`, confirm the files arrived on `cf-prod`.

**Activity:** From the **Terminal (dev)** tab:

```bash
# Check the deployment marker on cf-prod
ssh laborant@cf-prod "cat /opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt"
# Expected: deployed at 2026-09-03T14:32:11Z

# Curl cf-prod directly to confirm CF is serving
curl -s http://cf-prod:8500/index.cfm | head -5
```

From the **Terminal (prod)** tab:

```bash
# Confirm the marker file is on cf-prod
cat /opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt

# List the webroot to see what synced
ls /opt/coldfusion2025/cfusion/wwwroot/
```

::image-box
---
:src: __static__/deployment-verification-v1.png
:alt: Split terminal — left shows cf-dev running the deploy.sh script with rsync progress output, right shows cf-prod terminal with cat deploy_marker.txt returning a UTC timestamp and curl http://cf-prod:8500 returning an HTTP 200 response
:max-width: 900px
---
_Verification: deploy_marker.txt confirms the timestamp, curl confirms CF is serving on cf-prod._
::

::simple-task
---
:tasks: tasks
:name: verify_deployed_file
---
#active
Run `deploy.sh` and confirm `deploy_marker.txt` exists on cf-prod at `/opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt`.

#completed
Deployment marker present on cf-prod. ✓
::

---

## 4. Automate CF Admin configuration with CFConfig

Keeping two CF servers configured identically is error-prone when done by hand. CFConfig lets you export your CF server configuration as a JSON file and apply it to any server with one command.

::hint-box
---
:summary: What is CFConfig?
---
CFConfig is a CommandBox module that reads and writes ColdFusion server configuration files (`neo-*.xml`) through a clean JSON abstraction. Instead of hand-editing XML or clicking through the admin UI, you describe your desired server state in `.CFConfig.json` and apply it idempotently.

This is the foundation of **Infrastructure as Code** for ColdFusion.
::

**Activity:** On **cf-dev**, export the current CF config:

```bash
# Export cf-dev's config to a versioned file
box cfconfig export \
  to=/home/laborant/.CFConfig.json \
  toFormat=adobe2025 \
  from=/opt/coldfusion2025/cfusion/

cat /home/laborant/.CFConfig.json | python3 -m json.tool | head -30
```

Push it to cf-prod and apply:

```bash
# Copy the config file to cf-prod
scp /home/laborant/.CFConfig.json laborant@cf-prod:/home/laborant/.CFConfig.json

# Apply it on cf-prod
ssh laborant@cf-prod \
  "box cfconfig import \
   to=/opt/coldfusion2025/cfusion/ \
   toFormat=adobe2025 \
   from=/home/laborant/.CFConfig.json"

# Restart CF on prod to pick up JVM changes
ssh laborant@cf-prod "sudo systemctl restart cf-server"
curl -sf http://cf-prod:8500/index.cfm && echo "cf-prod back online"
```

---

## Blue/green deployment — zero-downtime variant

For zero-downtime deployments, maintain two webroot directories and swap a symlink atomically:

::image-box
---
:src: __static__/blue-green-deployment-v1.png
:alt: Diagram showing two webroot directories — wwwroot-blue (active, green border) and wwwroot-green (staging, grey border). A symlink labelled wwwroot points to wwwroot-blue. An arrow shows the symlink being atomically updated to point to wwwroot-green after the new code is deployed there.
:max-width: 860px
---
_Blue/green: deploy to the inactive slot, then atomically swap the symlink — zero downtime._
::

```bash
# On cf-prod — initial blue/green setup (run once)
sudo cp -r /opt/coldfusion2025/cfusion/wwwroot \
           /opt/coldfusion2025/cfusion/wwwroot-blue
sudo ln -sfn /opt/coldfusion2025/cfusion/wwwroot-blue \
             /opt/coldfusion2025/cfusion/wwwroot

# Deploy new code to the inactive (green) slot
rsync -avz "${WWWROOT}/" laborant@cf-prod:/opt/coldfusion2025/cfusion/wwwroot-green/

# Atomic swap (single ln command is atomic on Linux)
ssh laborant@cf-prod \
  "sudo ln -sfn /opt/coldfusion2025/cfusion/wwwroot-green \
                /opt/coldfusion2025/cfusion/wwwroot"
```

---

## Key concepts reference

| Concept | Tool / Command |
|---|---|
| Passwordless SSH | `ssh-keygen -t ed25519` + `ssh-copy-id` |
| File synchronisation | `rsync -avz --delete --exclude` |
| Verify deployment | `curl -sf http://cf-prod:8500/` |
| Zero-downtime swap | `ln -sfn` to atomically update symlink |
| Export CF config | `box cfconfig export to=.CFConfig.json toFormat=adobe2025` |
| Apply CF config | `box cfconfig import to=... toFormat=adobe2025 from=...` |
| Deployment marker | Write timestamp to `deploy_marker.txt` via SSH |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
SSH key, deploy script, and deploy marker are all in place — hit **Check** to complete the lesson.

#completed
Production deployment lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.production-deploy-XXXXXXXX
---
::
