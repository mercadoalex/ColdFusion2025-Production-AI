---
kind: challenge

title: 'Schedule a Database Maintenance Task'

description: |
  Build a production-ready scheduled job from scratch: a guarded task target page
  that archives stale data, a setup page that registers it with cfschedule, a
  trigger page that fires it on demand, and confirmed log output. All five
  production patterns must be applied — guard, try/catch, cflog, idempotency,
  and requestTimeOut.

categories:
  - programming

tagz:
  - coldfusion
  - scheduling
  - automation
  - background-jobs

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
      # Must have access guard
      if ! grep -qi "REMOTE_ADDR\|127\.0\.0\.1" "${FILE}"; then
        echo "db_maintenance.cfm is missing the cgi.REMOTE_ADDR access guard"
        exit 1
      fi
      # Must have error handling
      if ! grep -qi "try\|catch" "${FILE}"; then
        echo "db_maintenance.cfm is missing a try/catch block"
        exit 1
      fi
      # Must log something
      if ! grep -qi "cflog" "${FILE}"; then
        echo "db_maintenance.cfm must use cflog() to record execution"
        exit 1
      fi
      echo "db_maintenance.cfm exists with guard, try/catch, and cflog ✓"

  task_registered:
    machine: cf-dev
    user: laborant
    needs:
      - maintenance_task_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/schedule_challenge.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "schedule_challenge.cfm not found"
        exit 1
      fi
      if ! grep -qi "cfschedule" "${FILE}"; then
        echo "schedule_challenge.cfm must call cfschedule()"
        exit 1
      fi
      if ! grep -qi "requestTimeOut\|requesttimeout" "${FILE}"; then
        echo "schedule_challenge.cfm must set requestTimeOut on the task"
        exit 1
      fi
      BODY=$(curl -sf http://localhost:8500/schedule_challenge.cfm 2>/dev/null || echo "CURL_FAILED")
      if echo "${BODY}" | grep -qi "error\|exception\|CURL_FAILED"; then
        echo "schedule_challenge.cfm threw an error or was not reachable"
        echo "Response: ${BODY}"
        exit 1
      fi
      if ! echo "${BODY}" | grep -qi "created\|registered\|update\|ok\|✓"; then
        echo "Task creation not confirmed in page output"
        echo "Response: ${BODY}"
        exit 1
      fi
      echo "Scheduled task registered with requestTimeOut ✓"

  task_runs:
    machine: cf-dev
    user: laborant
    needs:
      - task_registered
    run: |
      # Trigger the task immediately via schedule_challenge.cfm?run=1 or schedule_run_challenge.cfm
      curl -sf "http://localhost:8500/schedule_challenge.cfm?run=1" > /dev/null 2>&1 || \
      curl -sf "http://localhost:8500/schedule_run_challenge.cfm"    > /dev/null 2>&1 || true
      sleep 3
      LOG="/opt/coldfusion2025/cfusion/logs/scheduler.log"
      if [ ! -f "${LOG}" ]; then
        echo "scheduler.log not found — task has not run yet"
        exit 1
      fi
      if ! grep -qi "db_maintenance" "${LOG}" 2>/dev/null; then
        echo "No db_maintenance entry in scheduler.log — trigger the task and check cflog() calls"
        exit 1
      fi
      echo "Task execution confirmed in scheduler.log ✓"
      tail -5 "${LOG}"

  task_idempotent:
    machine: cf-dev
    user: laborant
    needs:
      - task_runs
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/tasks/db_maintenance.cfm"
      # Check for idempotency patterns: WHERE clause with date/status, UPSERT, or existence check
      if ! grep -qiE "WHERE|status|updated_at|created_at|DATEADD|DATEDIFF|exists" "${FILE}"; then
        echo "db_maintenance.cfm does not appear to use a WHERE clause for safe deletion"
        echo "Ensure the DELETE or UPDATE targets only specific rows (not the whole table)"
        exit 1
      fi
      echo "Task uses a WHERE clause — idempotency pattern present ✓"
---

## Schedule a Database Maintenance Task

Build a complete, production-ready scheduled job that archives stale helpdesk data.

### Requirements

**1. Create `tasks/db_maintenance.cfm`** — the task target page:
- Guard against external access: check `cgi.REMOTE_ADDR == "127.0.0.1"`
- Wrap all work in `try/catch` — failures must be caught and logged, never silent
- Use `cflog(file="scheduler", text="...")` to log start, key metrics, and completion
- Perform a safe DB operation — delete or archive tickets with a `WHERE` clause that limits scope (e.g. closed tickets older than 30 days)
- Write `writeOutput("OK")` at the end so the scheduler sees a successful HTTP response

**2. Create `schedule_challenge.cfm`** — the task registration page:
- Register the `DBMaintenance` task using `cfschedule(action="update", ...)`
- Set `requestTimeOut = 60` (or higher)
- Set `interval = "daily"` with a `startTime` of your choice
- Output a confirmation message when the task is found in the task list

**3. Trigger and confirm:**
- Either add `?run=1` handling to `schedule_challenge.cfm` or create `schedule_run_challenge.cfm`
- Trigger the task so it actually executes
- Confirm a `db_maintenance` entry appears in `scheduler.log`

### Hints

```bash
# Check your files exist
ls /opt/coldfusion2025/cfusion/wwwroot/tasks/
ls /opt/coldfusion2025/cfusion/wwwroot/schedule_challenge.cfm

# Trigger and watch
curl http://localhost:8500/schedule_challenge.cfm?run=1
tail -20 /opt/coldfusion2025/cfusion/logs/scheduler.log
```

::simple-task
---
:tasks: tasks
:name: maintenance_task_page
---
#active
Create `tasks/db_maintenance.cfm` with: `cgi.REMOTE_ADDR` guard, `try/catch`, `cflog()`, and a `WHERE`-bounded DB operation.

#completed
db_maintenance.cfm exists with guard, try/catch, and cflog. ✓
::

::simple-task
---
:tasks: tasks
:name: task_registered
---
#active
Create `schedule_challenge.cfm` that registers `DBMaintenance` with `cfschedule` and sets `requestTimeOut`.

#completed
Scheduled task registered with requestTimeOut. ✓
::

::simple-task
---
:tasks: tasks
:name: task_runs
---
#active
Trigger the task and confirm a `db_maintenance` entry appears in `scheduler.log`.

#completed
Task execution confirmed in scheduler.log. ✓
::

::simple-task
---
:tasks: tasks
:name: task_idempotent
---
#active
Ensure `db_maintenance.cfm` uses a `WHERE` clause so running it twice is safe.

#completed
Idempotency pattern confirmed — WHERE clause present. ✓
::
