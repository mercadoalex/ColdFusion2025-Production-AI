---
kind: unit

title: Automation and Scheduling

name: automation-scheduling-unit-1
---

## Background jobs in ColdFusion

Not all work happens in response to an HTTP request. Nightly reports, cache pre-warming, data synchronisation, email digests — these are background jobs that need to run on a schedule. ColdFusion's `<cfschedule>` tag is its built-in task scheduler.

::image-box
---
:src: __static__/cfschedule-architecture-v1.png
:alt: Diagram showing the ColdFusion scheduler making an internal HTTP GET request to a task target page (tasks/nightly_report.cfm) on the same server, with a clock showing 2:00 AM trigger, and a log file being written by the task page
:max-width: 860px
---
_cfschedule triggers an internal HTTP request to a CFML page — the task page does the work._
::

::hint-box
---
:summary: How cfschedule actually works
---
`cfschedule` is not a cron daemon — it is ColdFusion making **an internal HTTP GET request** to a URL you specify, at the scheduled time. This means:

- The task page (`nightly_report.cfm`) is a normal CFML page accessible via HTTP
- The CF engine must be running for tasks to fire
- You must guard task pages against external access (check `cgi.REMOTE_ADDR`)
- Task output is captured in the CF Admin scheduled task log, not printed to a browser
::

---

## 1. Create a scheduled task

**Activity:** Create the task target page first:

```bash
# Create the tasks directory
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/tasks

# Create the task target page
sudo tee /opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm << 'EOF'
<cfscript>
  // Guard: only accept requests from localhost
  if (cgi.REMOTE_ADDR != "127.0.0.1" && cgi.REMOTE_ADDR != "::1") {
    cfheader(statuscode=403, statustext="Forbidden");
    writeOutput("Forbidden");
    abort;
  }

  cflog(file="scheduler", text="nightly_report started at #now()#");

  // Simulate work — query open tickets
  try {
    tickets = queryExecute(
      "SELECT COUNT(*) AS cnt FROM hd_tickets WHERE status = 'open'",
      {}, { datasource: "training_db" }
    );
    cflog(file="scheduler", text="Open tickets: #tickets.cnt#");
  } catch (any e) {
    cflog(file="scheduler", text="nightly_report ERROR: #e.message#");
  }

  cflog(file="scheduler", text="nightly_report completed");
  writeOutput("OK");
</cfscript>
EOF
```

Now create `schedule_setup.cfm` to register the task:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm << 'EOF'
<cfscript>
  cfschedule(
    action         = "update",
    task           = "NightlyReport",
    operation      = "HTTPRequest",
    url            = "http://localhost:8500/tasks/nightly_report.cfm",
    startDate      = "2026-01-01",
    startTime      = "02:00 AM",
    interval       = "daily",
    requestTimeOut = 120,
    publish        = false
  );

  // Verify it was created
  cfschedule(action="list", result="tasks");
  found = false;
  for (t in tasks) {
    if (t.task == "NightlyReport") {
      found = true;
      break;
    }
  }

  writeOutput(found ? "NightlyReport task created ✓" : "ERROR: task not found");
</cfscript>
EOF
```

Run it:

```bash
curl -s http://localhost:8500/schedule_setup.cfm
```

::simple-task
---
:tasks: tasks
:name: verify_task_created
---
#active
Run `curl http://localhost:8500/schedule_setup.cfm` — it should run without throwing an error.

#completed
schedule_setup.cfm ran without errors. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_cfschedule_used
---
#active
Confirm `schedule_setup.cfm` contains a `cfschedule` call.

#completed
cfschedule is used in schedule_setup.cfm. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_task_page_exists
---
#active
Create `tasks/nightly_report.cfm` at `/opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm`.

#completed
Task target page exists. ✓
::

---

## 2. List, pause, and delete tasks

```cfml
<cfscript>
  // List all scheduled tasks
  cfschedule(action="list", result="tasks");
  for (t in tasks) {
    writeOutput(t.task & " — next run: " & t.nextFireTime & "<br>");
  }

  // Pause a task (won't fire until resumed)
  cfschedule(action="pause",  task="NightlyReport");

  // Resume a paused task
  cfschedule(action="resume", task="NightlyReport");

  // Run a task immediately (for testing)
  cfschedule(action="run",    task="NightlyReport");

  // Delete a task
  // cfschedule(action="delete", task="NightlyReport");
</cfscript>
```

::hint-box
---
:summary: Where do I see scheduled task output?
---
Task run logs are written to the CF log file you specify in `cflog()`. You can also see task history in the CF Admin UI at **Debugging & Logging → Scheduled Tasks**, or tail the log directly:

```bash
tail -f /opt/coldfusion2025/cfusion/logs/scheduler.log
```

The log file name in `cflog(file="scheduler", ...)` maps to `scheduler.log` in the CF logs directory.
::

---

## 3. Manage tasks via the CF Admin API

For automated provisioning, use the Admin API instead of `cfschedule`:

```cfml
<cfscript>
  scheduler = createObject("component", "cfide.adminapi.scheduler");
  scheduler.login("admin");

  // List all tasks
  tasks = scheduler.getAllTasks();
  writeDump(tasks);

  // Get a specific task
  task = scheduler.getTask("NightlyReport");
  writeOutput("Next run: " & task.nextFireTime);
</cfscript>
```

---

## 4. Reliable task patterns

| Pattern | Why |
|---|---|
| Guard with `cgi.REMOTE_ADDR` check | Prevent external access to task pages |
| Wrap in `<cftry>` | Task failures should be logged, not crash the page |
| Use `cflog()` liberally | No browser output for scheduled tasks — logs are your only window |
| Keep tasks idempotent | A task that runs twice should produce the same result as running once |
| Set a reasonable `requestTimeOut` | Default is very long; set a ceiling to prevent runaway tasks |

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Create task | `cfschedule(action="update", task="Name", url="...", interval="daily")` |
| List tasks | `cfschedule(action="list", result="tasks")` |
| Run immediately | `cfschedule(action="run", task="Name")` |
| Log output | `cflog(file="scheduler", text="message")` |
| Guard external access | Check `cgi.REMOTE_ADDR == "127.0.0.1"` |
| Admin API | `cfide.adminapi.scheduler.getAllTasks()` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all previous tasks pass.

#completed
Scheduling lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Amateurs sit and wait for inspiration. The rest of us just show up and get to work."*
> — Stephen King

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.scheduling-1e51e423
---
::
