---
kind: lesson

title: Multi-VM Deployment & CF Admin Automation
description: |
  Use the three-VM advanced environment to practise a real deployment workflow:
  build on cf-dev, promote artifacts to cf-prod over SSH, and automate CF Admin
  configuration with the Admin API and CFConfig.

name: multi-vm-deployment-cf-prod
slug: multi-vm-deployment-cf-prod

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming
- ci-cd

tagz:
- coldfusion
- deployment
- ssh
- production

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  production-deploy-ba4aeb6e: {}

tasks:
  init_wait_for_cf:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 120
    run: |
      until curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/ | grep -q "200\|302"; do
        echo "Waiting for ColdFusion on port 8500..."
        sleep 5
      done
      echo "ColdFusion is up ✓"

  verify_ssh_to_prod:
    machine: cf-dev
    user: laborant
    run: |
      if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               laborant@cf-prod "echo ok" 2>/dev/null; then
        echo "Cannot SSH from cf-dev to cf-prod — check SSH key setup"
        exit 1
      fi
      echo "SSH from cf-dev → cf-prod works ✓"

  verify_deploy_script:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ssh_to_prod
    run: |
      if [ ! -f "/home/laborant/deploy.sh" ]; then
        echo "deploy.sh not found at /home/laborant/deploy.sh"
        exit 1
      fi
      if ! grep -q "cf-prod" /home/laborant/deploy.sh; then
        echo "deploy.sh does not reference cf-prod"
        exit 1
      fi
      echo "deploy.sh exists and references cf-prod ✓"

  verify_deployed_file:
    machine: cf-prod
    user: laborant
    needs:
      - verify_deploy_script
    run: |
      if [ ! -f "/opt/coldfusion2025/cfusion/wwwroot/deploy_marker.txt" ]; then
        echo "deploy_marker.txt not found on cf-prod — run deploy.sh first"
        exit 1
      fi
      echo "Deployment marker present on cf-prod ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_deployed_file
    run: |
      echo "Production deployment lesson complete ✓"
---
