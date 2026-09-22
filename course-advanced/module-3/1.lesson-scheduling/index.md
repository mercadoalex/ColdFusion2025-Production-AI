---
kind: lesson

title: Automation and Scheduling
description: |
  Automate recurring operations in ColdFusion using cfschedule.
  Build guarded task target pages, register daily/interval tasks,
  trigger and observe execution via scheduler.log, manage the full
  task lifecycle, and apply production-ready reliability patterns.

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
- background-jobs

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
        echo "schedule_setup.cfm not found — create it following the Activity in section 3"
        exit 1
      fi
      echo "schedule_setup.cfm found ✓"
    hintcheck: |
      echo "Create schedule_setup.cfm with cfschedule(action='update', ...) — section 3 of the lesson."
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
      echo "schedule_setup.cfm must contain a cfschedule() call with action='update' to register the task."

  verify_task_page_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfschedule_used
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "tasks/nightly_report.cfm not found — create the task target page (section 2)"
        exit 1
      fi
      # Also verify the access guard is present
      if ! grep -qi "REMOTE_ADDR\|127\.0\.0\.1" "${FILE}" 2>/dev/null; then
        echo "nightly_report.cfm is missing the cgi.REMOTE_ADDR access guard"
        exit 1
      fi
      echo "Task target page exists with access guard ✓"
    hintcheck: |
      echo "Create tasks/nightly_report.cfm with a cgi.REMOTE_ADDR guard — section 2 of the lesson."
      echo "  mkdir -p /opt/coldfusion2025/cfusion/wwwroot/tasks"
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm ..."

  verify_task_runs:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_page_exists
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/schedule_run.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "schedule_run.cfm not found — create it following the Activity in section 4"
        exit 1
      fi
      if ! grep -qi "cfschedule.*run\|action.*run" "${FILE}" 2>/dev/null; then
        echo "schedule_run.cfm does not call cfschedule(action='run', ...)"
        exit 1
      fi
      # Trigger the task and give it a moment to execute
      curl -sf http://localhost:8500/schedule_run.cfm > /dev/null 2>&1 || true
      sleep 2
      echo "schedule_run.cfm exists and triggers the task ✓"
    hintcheck: |
      echo "Create schedule_run.cfm with cfschedule(action='run', task='NightlyReport') — section 4."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_run.cfm ..."

  verify_log_entry:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_runs
    run: |
      LOG="/opt/coldfusion2025/cfusion/logs/scheduler.log"
      if [ ! -f "${LOG}" ]; then
        echo "scheduler.log not found — has the task been triggered yet?"
        echo "Run: curl http://localhost:8500/schedule_run.cfm"
        exit 1
      fi
      if ! grep -qi "nightly_report" "${LOG}" 2>/dev/null; then
        echo "No nightly_report entry found in scheduler.log"
        echo "Trigger the task: curl http://localhost:8500/schedule_run.cfm"
        echo "Then check: tail -20 ${LOG}"
        exit 1
      fi
      echo "scheduler.log contains nightly_report entries ✓"
      tail -5 "${LOG}"
    hintcheck: |
      echo "Trigger the task first: curl http://localhost:8500/schedule_run.cfm"
      echo "Then check the log:     tail -20 /opt/coldfusion2025/cfusion/logs/scheduler.log"
      echo "Your task page must call cflog(file='scheduler', text='...') to write log entries."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_log_entry
    run: |
      echo "Automation & Scheduling lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
