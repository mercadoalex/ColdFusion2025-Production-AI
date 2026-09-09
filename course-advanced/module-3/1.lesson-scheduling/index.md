---
kind: lesson

title: Automation and Scheduling
description: |
  Automate recurring operations in ColdFusion using cfschedule.
  Configure scheduled tasks, manage them via the CF Admin API,
  and build reliable background job patterns.

name: automation-scheduling
slug: automation-scheduling

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- scheduling
- automation

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_task_created:
    machine: cf-dev
    user: laborant
    run: |
      BODY=$(curl -s http://localhost:8500/schedule_setup.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "schedule_setup.cfm threw an error"
        exit 1
      fi
      echo "schedule_setup.cfm ran without errors"

  verify_cfschedule_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_task_created
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm"
      if ! grep -qi "cfschedule\|cfschedule" "${FILE}" 2>/dev/null; then
        echo "cfschedule tag not found in schedule_setup.cfm"
        exit 1
      fi
      echo "cfschedule is used"

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
      echo "Task target page exists"
---

## Create a scheduled task with cfschedule

```cfml
<cfschedule
  action    = "update"
  task      = "NightlyReport"
  operation = "HTTPRequest"
  url       = "http://localhost:8500/tasks/nightly_report.cfm"
  startDate = "2026-01-01"
  startTime = "02:00 AM"
  interval  = "daily"
  requestTimeOut = "120"
  publish   = "no">
```

## List and delete tasks

```cfml
<cfscript>
  // list all tasks
  cfschedule(action="list", result="tasks");
  writeDump(tasks);

  // delete a task
  cfschedule(action="delete", task="NightlyReport");
</cfscript>
```

## Task target page pattern

```cfml
<!--- tasks/nightly_report.cfm --->
<cfscript>
  // guard: only allow internal calls
  if (!cgi.remote_addr == "127.0.0.1") {
    cfheader(statuscode=403, statustext="Forbidden");
    abort;
  }

  cflog(file="scheduler", text="nightly_report started");

  // do work
  queryExecute(
    "INSERT INTO reports (created_at) VALUES (NOW())",
    {},
    {datasource: "training_db"}
  );

  cflog(file="scheduler", text="nightly_report completed");
</cfscript>
```

## Manage via CF Admin API

```cfml
<cfscript>
  scheduler = createObject("component", "cfide.adminapi.scheduler");
  scheduler.login("admin123");
  tasks = scheduler.getAllTasks();
  writeDump(tasks);
</cfscript>
```

