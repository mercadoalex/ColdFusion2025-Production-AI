---
kind: lesson

title: Automation and Scheduling
description: |
  Automate recurring operations in ColdFusion using cfschedule.
  Configure scheduled tasks, manage them via the CF Admin API,
  and build reliable background job patterns.

name: automation-scheduling
slug: automation-scheduling

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- scheduling
- automation

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  scheduling-1e51e423: {}

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

  verify_task_created:
    machine: cf-dev
    user: laborant
    run: |
      BODY=$(curl -s http://localhost:8500/schedule_setup.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "schedule_setup.cfm threw an error"
        exit 1
      fi
      echo "schedule_setup.cfm ran without errors ✓"

  verify_cfschedule_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_created
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm"
      if ! grep -qi "cfschedule" "${FILE}" 2>/dev/null; then
        echo "cfschedule tag not found in schedule_setup.cfm"
        exit 1
      fi
      echo "cfschedule is used ✓"

  verify_task_page_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfschedule_used
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "tasks/nightly_report.cfm not found — task target page missing"
        exit 1
      fi
      echo "Task target page exists ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_page_exists
    run: |
      echo "Scheduling lesson complete ✓"
---
