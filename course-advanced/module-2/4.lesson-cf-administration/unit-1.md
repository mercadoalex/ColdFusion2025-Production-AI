---
kind: unit

title: CF Administration Automation

name: cf-admin-api-cfconfig-automation-unit-1
---

## Why automate CF administration?

Every ColdFusion server needs to be configured: datasources, mail servers, JVM settings, scheduled tasks, security policies. The traditional approach — clicking through the CF Admin UI — is slow, error-prone, and impossible to reproduce reliably across environments. Two automation paths fix this.

::image-box
---
:src: __static__/cf-admin-automation-paths-v1.png
:alt: Two-path diagram — left path shows CFML code calling cfide.adminapi.datasource.setH2() to add a datasource at runtime, labelled "CF Admin API — runtime changes from CFML". Right path shows a .CFConfig.json file with arrow to box cfconfig import command, labelled "CFConfig — version-controlled idempotent apply"
:max-width: 900px
---
_Two automation paths: the CF Admin API for runtime changes, CFConfig for declarative config-as-code._
::

| Approach | When to use |
|---|---|
| **CF Admin API** (`cfide.adminapi.*`) | Programmatic changes at runtime from CFML — useful for dynamic datasource provisioning |
| **CFConfig** (`.CFConfig.json`) | Version-controlled config file, applied idempotently via CommandBox — the preferred approach for CI/CD |

---

## 1. The CF Admin API

The Admin API is a set of CFCs bundled with ColdFusion under `cfide.adminapi`. They expose every CF Admin function programmatically. **Always authenticate first** — the API requires the same credentials as the CF Admin UI.

::image-box
---
:src: __static__/cf-admin-api-script-v1.png
:alt: admin_api_demo.cfm open in VS Code showing createObject calls for cfide.adminapi.administrator, cfide.adminapi.datasource, and cfide.adminapi.runtime, with adminSvc.login("admin") highlighted and a comment saying "authenticate before any other API call"
:max-width: 860px
---
_The Admin API pattern: authenticate → get a service object → call methods._
::

**Activity:** Create `admin_api_demo.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/admin_api_demo.cfm << 'EOF'
<cfscript>
  // ── Step 1: Authenticate ────────────────────────────────────────────
  adminSvc = createObject("component", "cfide.adminapi.administrator");
  adminSvc.login("admin");   // CF Admin password

  // ── Step 2: List datasources ────────────────────────────────────────
  dsSvc   = createObject("component", "cfide.adminapi.datasource");
  sources = dsSvc.getDatasources();

  cfheader(name="Content-Type", value="application/json");
  result = {};
  for (ds in sources) {
    result[ds.name] = {
      driver:    ds.driver ?: "unknown",
      connected: dsSvc.verifyDatasource(ds.name)
    };
  }
  writeOutput(serializeJSON(result));

  // ── Step 3: Read JVM args ───────────────────────────────────────────
  // runtimeSvc = createObject("component", "cfide.adminapi.runtime");
  // writeOutput("<br>JVM: " & runtimeSvc.getJVMArgs());
</cfscript>
EOF
```

Test it:

```bash
curl -s http://localhost:8500/admin_api_demo.cfm | python3 -m json.tool
```

::hint-box
---
:summary: Admin API password vs CF Admin UI password
---
The password you pass to `adminSvc.login()` is the **CF Administrator password**, not a user account password. It is stored in `neo-security.xml` and is what you type when you open the CF Admin console at `/CFIDE/administrator/`. In this lab environment, the password is `admin`.

Never hardcode this password in source code. Use an environment variable or CFConfig secret instead.
::

::simple-task
---
:tasks: tasks
:name: verify_admin_api_accessible
---
#active
Confirm the CF Admin is reachable at `http://localhost:8500/CFIDE/administrator/index.cfm`.

#completed
CF Admin is reachable. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_admin_api_script
---
#active
Create `admin_api_demo.cfm` at `/opt/coldfusion2025/cfusion/wwwroot/admin_api_demo.cfm`.

#completed
admin_api_demo.cfm exists. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_admin_api_runs
---
#active
Confirm `admin_api_demo.cfm` runs without any ColdFusion error or exception.

#completed
admin_api_demo.cfm runs without errors. ✓
::

---

## 2. CFConfig — config as code

CFConfig is a CommandBox module that reads and writes ColdFusion's `neo-*.xml` configuration files through a clean JSON abstraction. Your server config lives in `.CFConfig.json` — version-controlled, reviewable in a PR, and applied identically to every environment.

```json
{
  "adminPassword": "admin",
  "datasources": {
    "training_db": {
      "driver":      "H2",
      "database":    "/opt/coldfusion2025/cfusion/db/training",
      "username":    "sa",
      "password":    "",
      "description": "Help Desk training database"
    }
  },
  "mailServers": [
    {
      "smtp":     "localhost",
      "port":     25,
      "username": "",
      "password": ""
    }
  ],
  "jvmArgs": "-Xms512m -Xmx1024m -XX:+UseG1GC"
}
```

**Activity:** Export the current server config, inspect it, then apply it:

```bash
# Export current cf-dev config to a file
box cfconfig export \
  to=/home/laborant/.CFConfig.json \
  toFormat=adobe2025 \
  from=/opt/coldfusion2025/cfusion/

# Inspect the exported JSON
cat /home/laborant/.CFConfig.json | python3 -m json.tool | head -40

# Apply it back (idempotent — makes no change if already in sync)
box cfconfig import \
  to=/opt/coldfusion2025/cfusion/ \
  toFormat=adobe2025 \
  from=/home/laborant/.CFConfig.json

echo "CFConfig applied ✓"
```

::simple-task
---
:tasks: tasks
:name: verify_cfconfig_file
---
#active
Generate a `.CFConfig.json` file anywhere under `/home/laborant/` or `/opt/coldfusion2025/`.

#completed
.CFConfig.json found. ✓
::

---

## 3. Sync both VMs with CFConfig

The real power: keep `cf-dev` and `cf-prod` in sync with one script.

```bash
# Export current dev config
box cfconfig export \
  to=/home/laborant/.CFConfig.json \
  toFormat=adobe2025 \
  from=/opt/coldfusion2025/cfusion/

# Push config to cf-prod and apply
scp /home/laborant/.CFConfig.json laborant@cf-prod:/home/laborant/.CFConfig.json
ssh laborant@cf-prod \
  "box cfconfig import \
   to=/opt/coldfusion2025/cfusion/ \
   toFormat=adobe2025 \
   from=/home/laborant/.CFConfig.json"

# Restart CF on prod to pick up JVM arg changes
ssh laborant@cf-prod "sudo systemctl restart cf-server"

# Verify prod is back online
curl -sf http://cf-prod:8500/index.cfm && echo "cf-prod back online ✓"
```

::hint-box
---
:summary: When do I need to restart CF after CFConfig import?
---
- **Datasource changes** — no restart needed; CF reloads datasources dynamically
- **JVM arguments** (`-Xmx`, GC settings) — **restart required**; JVM args only take effect at process start
- **Mail server changes** — no restart needed
- **Admin password changes** — no restart needed; encrypted in `neo-security.xml`

As a safe default, restart after any CFConfig import in production.
::

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Authenticate Admin API | `cfide.adminapi.administrator.login("password")` |
| List datasources | `cfide.adminapi.datasource.getDatasources()` |
| Verify datasource | `cfide.adminapi.datasource.verifyDatasource(name)` |
| JVM args | `cfide.adminapi.runtime.getJVMArgs()` |
| Export config | `box cfconfig export to=file.json toFormat=adobe2025 from=/opt/cf/cfusion/` |
| Import config | `box cfconfig import to=/opt/cf/cfusion/ toFormat=adobe2025 from=file.json` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Admin API script and CFConfig file are both in place — hit **Check** to complete the lesson.

#completed
CF Administration lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.cf-administration-XXXXXXXX
---
::
