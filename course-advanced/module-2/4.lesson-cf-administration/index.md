---
kind: lesson

title: CF Administration Automation
description: |
  Automate ColdFusion server configuration using the CF Admin API
  (cfide.adminapi) and CFConfig JSON files. Manage datasources, mail servers,
  and JVM settings programmatically — no clicking through the admin UI.

name: cf-admin-api-cfconfig-automation
slug: cf-admin-api-cfconfig-automation

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming
- ci-cd

tagz:
- coldfusion
- admin-api
- cfconfig
- automation

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  cf-administration-78ebd278: {}

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

  verify_admin_api_accessible:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/index.cfm)
      if [ "${STATUS}" = "000" ]; then
        echo "CF Admin is not reachable (connection refused)"
        exit 1
      fi
      echo "CF Admin is reachable (HTTP ${STATUS}) ✓"

  verify_admin_api_script:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_accessible
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/admin_api_demo.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "admin_api_demo.cfm not found at ${FILE}"
        exit 1
      fi
      echo "admin_api_demo.cfm exists ✓"

  verify_admin_api_runs:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_script
    run: |
      BODY=$(curl -s http://localhost:8500/admin_api_demo.cfm)
      if echo "${BODY}" | grep -qi "error\|exception\|login failed"; then
        echo "admin_api_demo.cfm threw an error: ${BODY}"
        exit 1
      fi
      echo "admin_api_demo.cfm ran without errors ✓"

  verify_cfconfig_file:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_runs
    run: |
      FILE=$(find /home/laborant /opt/coldfusion2025 -name ".CFConfig.json" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo ".CFConfig.json not found — create one to capture server config"
        exit 1
      fi
      echo ".CFConfig.json found at ${FILE} ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfconfig_file
    run: |
      echo "CF Administration lesson complete ✓"
---
