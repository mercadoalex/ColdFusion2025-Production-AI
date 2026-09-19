---
kind: challenge

title: 'Deploy and Verify an Application to cf-prod'

description: |
  Set up SSH key-based authentication from cf-dev to cf-prod, write a deployment
  script that syncs the webroot, and verify the deployment with a marker file.

categories:
  - programming

tagz:
  - coldfusion
  - deployment
  - ssh
  - production

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  ssh_keys_configured:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f "/home/laborant/.ssh/id_ed25519" ]; then
        echo "SSH private key not found — run ssh-keygen first"
        exit 1
      fi
      if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               laborant@cf-prod "echo ok" 2>/dev/null; then
        echo "Cannot SSH to cf-prod without password — set up ssh-copy-id"
        exit 1
      fi
      echo "Passwordless SSH to cf-prod works ✓"

  deploy_script_runs:
    machine: cf-dev
    user: laborant
    needs:
      - ssh_keys_configured
    run: |
      if [ ! -f "/home/laborant/deploy.sh" ]; then
        echo "deploy.sh not found"
        exit 1
      fi
      bash /home/laborant/deploy.sh
      echo "deploy.sh ran successfully ✓"

  marker_on_prod:
    machine: cf-prod
    user: laborant
    needs:
      - deploy_script_runs
    run: |
      if [ ! -f "/opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt" ]; then
        echo "deploy_marker.txt not found on cf-prod"
        exit 1
      fi
      echo "Deployment marker present on cf-prod ✓"

  cf_prod_responds:
    machine: cf-prod
    user: laborant
    needs:
      - marker_on_prod
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/index.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "CF on cf-prod not responding (HTTP ${STATUS})"
        exit 1
      fi
      echo "CF on cf-prod is responding ✓"
---

## Deploy and Verify an Application to cf-prod

Complete the full deployment workflow from cf-dev to cf-prod.

### Steps

1. **Generate an SSH key pair** on cf-dev (if not already done):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ```

2. **Copy the public key** to cf-prod:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub laborant@cf-prod
   ```

3. **Write `/home/laborant/deploy.sh`** that uses `rsync` to sync the CF webroot and writes a `deploy_marker.txt` with a UTC timestamp.

4. **Run the script** and confirm the marker file appears on cf-prod.

::simple-task
---
:tasks: tasks
:name: ssh_keys_configured
---
#active
Configure passwordless SSH from cf-dev to cf-prod.

#completed
Passwordless SSH to cf-prod works. ✓
::

::simple-task
---
:tasks: tasks
:name: deploy_script_runs
---
#active
Create and run `/home/laborant/deploy.sh`.

#completed
deploy.sh ran successfully. ✓
::

::simple-task
---
:tasks: tasks
:name: marker_on_prod
---
#active
Confirm `deploy_marker.txt` exists on cf-prod after running deploy.sh.

#completed
Deployment marker present on cf-prod. ✓
::

::simple-task
---
:tasks: tasks
:name: cf_prod_responds
---
#active
Confirm ColdFusion on cf-prod returns HTTP 200 on port 8500.

#completed
CF on cf-prod is responding. ✓
::
