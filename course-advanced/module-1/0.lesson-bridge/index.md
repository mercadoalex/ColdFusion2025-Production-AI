---
kind: lesson

title: From Solid Foundations to Full Domination
description: |
  Survey the full landscape of the Advanced course — Operations, AI development,
  platform integrations, and enterprise frameworks. Then get your lab environment
  ready for Module 1 with two quick verification checks.

name: from-developer-to-devops
slug: from-developer-to-devops

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- devops
- docker

playground:
  name: cf-training-advanced-7442b9e0

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

  verify_cf_running:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/index.cfm)
      if [ "${STATUS}" = "000" ] || [ -z "${STATUS}" ]; then
        echo "ColdFusion is not responding on port 8500 (got: ${STATUS})"
        exit 1
      fi
      echo "ColdFusion is running on cf-dev (HTTP ${STATUS}) ✓"

  verify_ssh_to_prod:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cf_running
    run: |
      RESULT=$(ssh -o StrictHostKeyChecking=no \
                   -o ConnectTimeout=10 \
                   laborant@cf-prod "echo reachable" 2>/dev/null)
      if [ "${RESULT}" != "reachable" ]; then
        echo "Cannot SSH from cf-dev to cf-prod — check network connectivity"
        exit 1
      fi
      echo "cf-prod is reachable from cf-dev via SSH ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ssh_to_prod
    run: |
      echo "Bridge lesson complete ✓"
---
