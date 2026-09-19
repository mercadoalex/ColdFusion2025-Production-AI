---
kind: lesson

title: From Developer to DevOps Engineer
description: |
  Bridge the gap between writing ColdFusion code and running it reliably in
  production. Understand the three core problems DevOps solves, why containers
  exist, and what you will build in this module — before touching any tooling.

name: from-developer-to-devops
slug: from-developer-to-devops

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- devops
- docker

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_cf_running:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/)
      if [ "${STATUS}" != "200" ] && [ "${STATUS}" != "302" ]; then
        echo "ColdFusion is not responding on port 8500 (HTTP ${STATUS})"
        exit 1
      fi
      echo "ColdFusion is running on cf-dev ✓"

  verify_ssh_to_prod:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cf_running
    run: |
      RESULT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
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
