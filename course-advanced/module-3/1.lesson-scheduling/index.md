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
  name: cf-training-devops-3039c6bb

challenges:
  scheduling-1e51e423: {}

tasks:
  verify_task_created:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "schedule_setup.cfm not found — create it following the Activity in section 1"
        exit 1
      fi
      echo "schedule_setup.cfm found ✓"
    hintcheck: |
      echo "Create schedule_setup.cfm — follow the cfschedule Activity in section 1."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm ..."

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
    hintcheck: |
      echo "schedule_setup.cfm must contain a <cfschedule> or cfschedule() call to register a task."

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
    hintcheck: |
      echo "Create the scheduled task target file:"
      echo "  mkdir -p /opt/coldfusion2025/cfusion/wwwroot/tasks"
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm ..."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_page_exists
    run: |
      echo "Scheduling lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
