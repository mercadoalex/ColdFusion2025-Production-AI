---
kind: challenge

title: 'Schedule a Database Maintenance Task'

description: |
  Create a scheduled task that runs a database maintenance operation and logs
  its execution. The task must be guarded against external HTTP access.

categories:
  - programming

tagz:
  - coldfusion
  - scheduling
  - automation

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  maintenance_task_page:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/tasks/db_maintenance.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "tasks/db_maintenance.cfm not found"
        exit 1
      fi
      if ! grep -qi "cgi.REMOTE_ADDR\|127.0.0.1\|remote_addr" "${FILE}"; then
        echo "db_maintenance.cfm does not guard against external access"
        exit 1
      fi
      echo "db_maintenance.cfm exists with access guard ✓"

  task_registered:
    machine: cf-dev
    user: laborant
    needs:
      - maintenance_task_page
    run: |
      BODY=$(curl -s http://localhost:8500/schedule_challenge.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "schedule_challenge.cfm threw an error"
        exit 1
      fi
      if ! echo "${BODY}" | grep -qi "created\|registered\|update\|ok"; then
        echo "Task creation not confirmed in output"
        exit 1
      fi
      echo "Scheduled task registered ✓"

  task_runs:
    machine: cf-dev
    user: laborant
    needs:
      - task_registered
    run: |
      # Trigger the task immediately
      curl -s "http://localhost:8500/schedule_challenge.cfm?run=1" > /dev/null
      sleep 3
      # Check the log for evidence it ran
      LOG="/opt/coldfusion2025/cfusion/logs/scheduler.log"
      if ! grep -q "db_maintenance" "${LOG}" 2>/dev/null; then
        echo "No db_maintenance entry in scheduler.log — task may not have run"
        exit 1
      fi
      echo "Task execution logged ✓"
---

## Schedule a Database Maintenance Task

### Requirements

1. Create `tasks/db_maintenance.cfm` that:
   - Guards against external access (checks `cgi.REMOTE_ADDR`)
   - Logs its execution with `cflog(file="scheduler", text="...")`
   - Performs a simple DB operation (e.g., delete closed tickets older than 90 days)

2. Create `schedule_challenge.cfm` that registers the task with `cfschedule` and confirms creation.

::simple-task
---
:tasks: tasks
:name: maintenance_task_page
---
#active
Create `tasks/db_maintenance.cfm` with a `cgi.REMOTE_ADDR` access guard.

#completed
db_maintenance.cfm exists with access guard. ✓
::

::simple-task
---
:tasks: tasks
:name: task_registered
---
#active
Create `schedule_challenge.cfm` that registers the maintenance task with `cfschedule`.

#completed
Scheduled task registered. ✓
::

::simple-task
---
:tasks: tasks
:name: task_runs
---
#active
Trigger the task and confirm it logs an entry in the scheduler log.

#completed
Task execution logged. ✓
::
