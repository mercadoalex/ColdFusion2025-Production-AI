---
kind: unit

title: Automation and Scheduling

name: automation-scheduling-unit-1
---

> *"The most powerful tool we have as developers is automation."*
> — Scott Hanselman

---

## Why your application needs a task scheduler

Picture a support helpdesk at 2 AM. Nobody is at a keyboard, yet your application still needs to:

- Archive tickets closed more than 90 days ago to keep the `hd_tickets` table lean
- Email a daily digest of open P1 tickets to the on-call team
- Pre-warm the application cache so the first customer of the morning gets a fast response
- Run a data quality check that flags duplicate customer records

None of these belong in a request/response cycle — they are **background jobs**. Triggering them from a browser is fragile, slow, and requires a human. The right tool is a task scheduler.

ColdFusion ships with one built in: `cfschedule`.

::image-box
---
:src: __static__/cfschedule-architecture-v1.svg
:alt: Architecture diagram showing the ColdFusion scheduler firing an internal HTTP GET to a task page, the task page doing work and writing to scheduler.log, and the CF Admin UI managing tasks via the Admin API
:max-width: 900px
---
_The CF scheduler fires an internal HTTP GET to a CFML page at the scheduled time. That page does the work and logs results._
::

::hint-box
---
:summary: The scheduler is an HTTP client — not a cron daemon
---
`cfschedule` works differently from Linux `cron`. It does **not** fork a process or run a script directly. Instead, the ColdFusion engine makes an **internal HTTP GET request** to a URL you specify at the scheduled time.

This design has important consequences:

- The target page (`/tasks/nightly_report.cfm`) is a **normal CFML page** reachable over HTTP
- ColdFusion **must be running** for scheduled tasks to fire — tasks are stored inside the CF engine, not in the OS
- Because the URL is publicly accessible, you **must guard task pages** from external calls (check `cgi.REMOTE_ADDR`)
- Task output is **not** printed to a browser — use `cflog()` to observe what happened
- The scheduler honours `requestTimeOut` — set it, or a runaway task will hold a thread pool slot indefinitely
::

---

## 1. The task lifecycle

Understanding the five-step lifecycle is the foundation for building reliable scheduled jobs.

::image-box
---
:src: __static__/cfschedule-lifecycle-v1.svg
:alt: Five-step task lifecycle diagram showing Register → Trigger time → HTTP GET → CFML runs → cflog(), plus an interval reference table below
:max-width: 900px
---
_From registration to log entry — every scheduled task follows the same five steps._
::

**Step by step:**

1. **Register** — `cfschedule(action="update", ...)` stores the task definition inside the CF engine. You specify the URL, start date/time, and interval.
2. **Trigger time** — At the configured time, the CF scheduler wakes up and prepares the HTTP request.
3. **HTTP GET** — The scheduler makes an internal GET to `http://localhost:8500/tasks/your_page.cfm`.
4. **CFML runs** — Your task page executes: queries the database, sends emails, writes files — whatever the job requires.
5. **Log** — `cflog()` writes the outcome to `scheduler.log`. This is your only observability window.

### Interval values

| `interval` value | Fires | Typical use |
|---|---|---|
| `"daily"` | Once per day at `startTime` | Nightly reports, DB cleanup |
| `"weekly"` | Once per week | Weekly digest emails |
| `"monthly"` | Once per month | Monthly invoice generation |
| `900` *(seconds)* | Every 15 minutes | Cache warm-up, health checks |
| `3600` *(seconds)* | Every hour | Sync with external APIs |
| `"once"` | One time only | One-off data migrations |

---

## 2. Build the task target page

The task target page is a regular CFML file. It must do three things: **guard itself**, **do the work**, and **log the outcome**.

**Activity — create the task target page:**

```bash
# Create the tasks directory
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/tasks

# Create the task target page
sudo tee /opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm << 'EOF'
<cfscript>
  // ── ① Guard: only the CF scheduler (localhost) may call this page ──────────
  if (cgi.REMOTE_ADDR != "127.0.0.1" && cgi.REMOTE_ADDR != "::1") {
    cfheader(statuscode=403, statustext="Forbidden");
    writeOutput("Forbidden");
    abort;
  }

  cflog(file="scheduler", text="nightly_report started at #dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')#");

  // ── ② Do the work ──────────────────────────────────────────────────────────
  try {
    // Count open tickets and log the result
    result = queryExecute(
      "SELECT COUNT(*) AS cnt FROM hd_tickets WHERE status = 'open'",
      {},
      { datasource: "training_db" }
    );
    cflog(file="scheduler", text="Open tickets: #result.cnt#");

    // Archive tickets closed more than 90 days ago
    archived = queryExecute(
      "DELETE FROM hd_tickets WHERE status = 'closed'
       AND updated_at < DATEADD('DAY', -90, CURRENT_DATE)",
      {},
      { datasource: "training_db" }
    );
    cflog(file="scheduler", text="Archived #archived.recordCount# old closed tickets");

  } catch (any e) {
    cflog(file="scheduler", type="error", text="nightly_report FAILED: #e.message# — #e.detail#");
  }

  // ── ③ Always write a response (scheduler reads the HTTP status) ────────────
  cflog(file="scheduler", text="nightly_report completed");
  writeOutput("OK");
</cfscript>
EOF
```

Verify the file is in place:

```bash
cat /opt/coldfusion2025/cfusion/wwwroot/tasks/nightly_report.cfm
```

---

## 3. Register the scheduled task

Now create the setup page that calls `cfschedule` to register the task in the CF engine.

**Activity — create `schedule_setup.cfm`:**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_setup.cfm << 'EOF'
<cfscript>
  // Register (or update) the NightlyReport task
  cfschedule(
    action         = "update",
    task           = "NightlyReport",
    operation      = "HTTPRequest",
    url            = "http://localhost:8500/tasks/nightly_report.cfm",
    startDate      = "2026-01-01",
    startTime      = "02:00 AM",
    interval       = "daily",
    requestTimeOut = 120,
    publish        = false,
    resolveURL     = false
  );

  // ── Confirm the task was registered ────────────────────────────────────────
  cfschedule(action="list", result="allTasks");
  found = false;
  for (t in allTasks) {
    if (t.task == "NightlyReport") {
      found = true;
      break;
    }
  }

  writeOutput(found
    ? "<p style='color:green'>✓ NightlyReport task registered — next run: 02:00 daily</p>"
    : "<p style='color:red'>✗ ERROR: task not found after registration</p>"
  );
</cfscript>
EOF
```

**Activity — run the setup page:**

```bash
curl -s http://localhost:8500/schedule_setup.cfm
```

You should see: `✓ NightlyReport task registered — next run: 02:00 daily`

::simple-task
---
:tasks: tasks
:name: verify_task_created
---
#active
Run `curl http://localhost:8500/schedule_setup.cfm` — confirm the setup page exists and responds.

#completed
schedule_setup.cfm exists and is accessible. ✓
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

## 4. Run the task and watch the log

Don't wait until 2 AM to test. Use `cfschedule(action="run")` to trigger the task immediately.

**Activity — trigger the task now and tail the log:**

```bash
# Trigger the task immediately (runs the URL synchronously)
curl -s "http://localhost:8500/schedule_setup.cfm?run=1"
```

Create a page to fire it on demand:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_run.cfm << 'EOF'
<cfscript>
  cfschedule(action="run", task="NightlyReport");
  writeOutput("Task triggered. Check scheduler.log for output.");
</cfscript>
EOF

# Trigger the task
curl -s http://localhost:8500/schedule_run.cfm

# Watch the log
tail -20 /opt/coldfusion2025/cfusion/logs/scheduler.log
```

**Expected log output:**

```
Information,scheduler,,nightly_report started at 2026-09-03 14:22:10
Information,scheduler,,Open tickets: 14
Information,scheduler,,Archived 3 old closed tickets
Information,scheduler,,nightly_report completed
```

::simple-task
---
:tasks: tasks
:name: verify_task_runs
---
#active
Create `schedule_run.cfm`, run it with `curl`, then confirm an entry appears in `scheduler.log`.

#completed
Task ran and logged output to scheduler.log. ✓
::

::hint-box
---
:summary: Where is scheduler.log?
---
`cflog(file="scheduler", text="...")` writes to:

```
/opt/coldfusion2025/cfusion/logs/scheduler.log
```

The `file` parameter is the log file basename — ColdFusion appends `.log` automatically. You can use any name (e.g. `file="myapp"` → `myapp.log`), but keeping job-related output in `scheduler.log` keeps things tidy.

You can also view scheduled task run history in the CF Admin UI:
**Debugging & Logging → Scheduled Tasks**
::

---

## 5. Manage the full task lifecycle

Once a task is registered, you have full lifecycle control via `cfschedule` actions.

**Activity — explore task management:**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/schedule_manage.cfm << 'EOF'
<cfscript>
  action = url.action ?: "list";

  switch (action) {
    case "list":
      cfschedule(action="list", result="tasks");
      writeOutput("<h3>Registered tasks (" & arrayLen(tasks) & ")</h3><ul>");
      for (t in tasks) {
        writeOutput("<li><strong>#t.task#</strong> — interval: #t.interval#,
                     next: #t.nextFireTime#, status: #t.status#</li>");
      }
      writeOutput("</ul>");
      break;

    case "pause":
      cfschedule(action="pause", task="NightlyReport");
      writeOutput("NightlyReport paused.");
      break;

    case "resume":
      cfschedule(action="resume", task="NightlyReport");
      writeOutput("NightlyReport resumed.");
      break;

    case "run":
      cfschedule(action="run", task="NightlyReport");
      writeOutput("NightlyReport triggered immediately.");
      break;

    case "delete":
      cfschedule(action="delete", task="NightlyReport");
      writeOutput("NightlyReport deleted.");
      break;
  }
</cfscript>
EOF

# List tasks
curl -s "http://localhost:8500/schedule_manage.cfm?action=list"

# Pause a task
curl -s "http://localhost:8500/schedule_manage.cfm?action=pause"

# Resume it
curl -s "http://localhost:8500/schedule_manage.cfm?action=resume"
```

### `cfschedule` action reference

| Action | What it does |
|---|---|
| `"update"` | Create a new task or update an existing one |
| `"list"` | Return an array of all registered tasks |
| `"run"` | Execute a task immediately (fire-and-forget) |
| `"pause"` | Stop a task from firing until resumed |
| `"resume"` | Re-enable a paused task |
| `"delete"` | Permanently remove the task |

---

## 6. Manage tasks via the CF Admin API

For scripts that provision environments automatically, use the Admin API directly — no CFML page required.

**Activity — Admin API task management:**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/admin_scheduler.cfm << 'EOF'
<cfscript>
  // Authenticate with CF Admin
  scheduler = createObject("component", "cfide.adminapi.scheduler");
  scheduler.login("training");   // Admin password set during CF install

  // List all tasks
  tasks = scheduler.getAllTasks();
  writeOutput("<h3>Tasks via Admin API (" & structCount(tasks) & ")</h3><ul>");
  for (key in tasks) {
    t = tasks[key];
    writeOutput("<li>#t.task# — #t.interval# — #t.startdate# #t.starttime#</li>");
  }
  writeOutput("</ul>");

  // Get a specific task
  if (scheduler.taskExists("NightlyReport")) {
    task = scheduler.getTask("NightlyReport");
    writeOutput("<p>NightlyReport next fire: #task.nextFireTime#</p>");
  }
</cfscript>
EOF

curl -s http://localhost:8500/admin_scheduler.cfm
```

::hint-box
---
:summary: cfschedule vs Admin API — which to use?
---
| Situation | Use |
|---|---|
| Task setup from within your app | `cfschedule` tag/function |
| Automated environment provisioning | `cfide.adminapi.scheduler` |
| Querying task state from code | Either — both work |
| CF Admin UI (manual management) | Browser → `localhost:8500/CFIDE/administrator` |

In production, prefer the Admin API for provisioning scripts because it doesn't require an HTTP endpoint to be live.
::

::simple-task
---
:tasks: tasks
:name: verify_log_entry
---
#active
Run `curl http://localhost:8500/schedule_run.cfm` then `tail /opt/coldfusion2025/cfusion/logs/scheduler.log` — confirm at least one `nightly_report` entry is logged.

#completed
scheduler.log contains a nightly_report entry. ✓
::

---

## 7. Production-ready patterns

::image-box
---
:src: __static__/cfschedule-patterns-v1.svg
:alt: Five production patterns: access guard with cgi.REMOTE_ADDR check, wrap work in try/catch, log everything with cflog, make tasks idempotent, set requestTimeOut
:max-width: 900px
---
_Apply all five patterns to every scheduled task — they prevent the most common production failures._
::

### Anti-patterns to avoid

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| No `cgi.REMOTE_ADDR` guard | Any external caller can execute your task | Always check `== "127.0.0.1"` |
| No `try/catch` | Unhandled exceptions silently abort the task with no log entry | Wrap all work in try/catch |
| No `cflog()` | You have no way to know if the task ran, or what it did | Log start, key metrics, and end |
| INSERT without idempotency | Running twice inserts duplicates | Use UPSERT, status flags, or existence checks |
| No `requestTimeOut` | A slow DB query holds a thread pool slot indefinitely | Set a ceiling (e.g. `120` seconds) |
| Doing too much in one task | One failure aborts the whole job | Split into focused single-purpose tasks |

---

## Key concepts reference

| Concept | Syntax |
|---|---|
| Register / update task | `cfschedule(action="update", task="Name", url="...", interval="daily", startDate="...", startTime="...")` |
| List all tasks | `cfschedule(action="list", result="myVar")` |
| Run immediately | `cfschedule(action="run", task="Name")` |
| Pause a task | `cfschedule(action="pause", task="Name")` |
| Resume a task | `cfschedule(action="resume", task="Name")` |
| Delete a task | `cfschedule(action="delete", task="Name")` |
| Log output | `cflog(file="scheduler", text="message")` |
| Guard against external access | `if (cgi.REMOTE_ADDR != "127.0.0.1") { cfheader(statuscode=403); abort; }` |
| Admin API | `createObject("component","cfide.adminapi.scheduler").login("password")` |
| Tail the log | `tail -f /opt/coldfusion2025/cfusion/logs/scheduler.log` |

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
Automation & Scheduling lesson complete. Your background jobs are production-ready. ✓
::

---

## Put It Into Practice

> *"Don't watch the clock; do what it does. Keep going."*
> — Sam Levenson

Apply what you have covered with the challenge below. You will build a complete database maintenance scheduler — one that runs, logs, and proves it works.

::card
---
:challenge: challenges.scheduling-1e51e423
---
::
