---
kind: lesson

title: CF Admin API & CFConfig Automation
description: |
  Automate ColdFusion server configuration using the CF Admin API (cfide.adminapi)
  and CFConfig JSON files. Manage datasources, mail servers, and JVM settings
  programmatically — no clicking through the admin UI.

name: cf-admin-api-cfconfig-automation
slug: cf-admin-api-cfconfig-automation

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming
- ci-cd

tagz:
- coldfusion
- admin-api
- cfconfig
- automation

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_admin_api_accessible:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/index.cfm)
      if [ "${STATUS}" = "000" ]; then
        echo "CF Admin is not reachable (connection refused)"
        exit 1
      fi
      echo "CF Admin is reachable (HTTP ${STATUS}) ✓"

  verify_admin_api_script:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_accessible
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/admin_api_demo.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "admin_api_demo.cfm not found at ${FILE}"
        exit 1
      fi
      echo "admin_api_demo.cfm exists ✓"

  verify_admin_api_runs:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_script
    run: |
      BODY=$(curl -s http://localhost:8500/admin_api_demo.cfm)
      if echo "${BODY}" | grep -qi "error\|exception\|login failed"; then
        echo "admin_api_demo.cfm threw an error: ${BODY}"
        exit 1
      fi
      echo "admin_api_demo.cfm ran without errors ✓"

  verify_cfconfig_file:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_api_runs
    run: |
      FILE=$(find /home/laborant /opt/coldfusion2025 -name ".CFConfig.json" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo ".CFConfig.json not found — create one to capture server config"
        exit 1
      fi
      echo ".CFConfig.json found at ${FILE} ✓"
---

## Overview

ColdFusion exposes two automation paths for server configuration:

| Approach | When to use |
|---|---|
| **CF Admin API** (`cfide.adminapi.*`) | Programmatic config changes at runtime from CFML |
| **CFConfig** (`.CFConfig.json`) | Version-controlled config file, applied via CommandBox |

Both let you manage datasources, mail servers, scheduled tasks, and JVM settings
without ever clicking through the admin UI — essential for CI/CD pipelines.

---

## 1. CF Admin API — programmatic config

The Admin API is a set of CFCs under `cfide.adminapi`. Always authenticate first.

```cfml
<!--- admin_api_demo.cfm --->
<cfscript>
  // Authenticate
  adminSvc = createObject("component", "cfide.adminapi.administrator");
  adminSvc.login("admin");   // password set at CF install time

  // ── List datasources ──────────────────────────────────────────
  dsSvc   = createObject("component", "cfide.adminapi.datasource");
  sources = dsSvc.getDatasources();
  writeDump(sources);

  // ── Add a new datasource programmatically ─────────────────────
  newDs = {
    name:         "reporting_db",
    driver:       "H2",
    host:         "",
    port:         0,
    database:     "/opt/coldfusion2025/cfusion/db/reporting",
    username:     "sa",
    password:     "",
    description:  "Reporting datasource"
  };
  // dsSvc.setH2(argumentCollection=newDs);   // uncomment to actually create

  // ── JVM memory settings ───────────────────────────────────────
  runtimeSvc = createObject("component", "cfide.adminapi.runtime");
  jvmArgs    = runtimeSvc.getJVMArgs();
  writeOutput("<br>JVM args: " & jvmArgs);
</cfscript>
```

Test it:
```bash
curl -s http://localhost:8500/admin_api_demo.cfm | head -20
```

---

## 2. List and verify datasources via Admin API

```cfml
<cfscript>
  adminSvc = createObject("component", "cfide.adminapi.administrator");
  adminSvc.login("admin");

  dsSvc   = createObject("component", "cfide.adminapi.datasource");
  sources = dsSvc.getDatasources();

  cfheader(name="Content-Type", value="application/json");
  result = {};
  for (ds in sources) {
    result[ds.name] = { driver: ds.driver, connected: dsSvc.verifyDatasource(ds.name) };
  }
  writeOutput(serializeJSON(result));
</cfscript>
```

---

## 3. CFConfig — version-controlled server config

CommandBox's CFConfig format lets you declare your entire CF server configuration
as a JSON file that lives in version control.

Create `/home/laborant/.CFConfig.json`:

```json
{
  "adminPassword": "admin",
  "datasources": {
    "training_db": {
      "driver": "H2",
      "database": "/opt/coldfusion2025/cfusion/db/training",
      "username": "sa",
      "password": "",
      "description": "Help Desk training database"
    }
  },
  "mailServers": [
    {
      "smtp": "localhost",
      "port": 25,
      "username": "",
      "password": ""
    }
  ],
  "jvmArgs": "-Xms512m -Xmx1024m -XX:+UseG1GC"
}
```

Apply it with CommandBox:

```bash
# Apply .CFConfig.json to the running Adobe CF instance
box cfconfig import to=/opt/coldfusion2025/cfusion/ toFormat=adobe2025

# Export current server state to a file (capture what's running)
box cfconfig export to=.CFConfig.json toFormat=adobe2025 from=/opt/coldfusion2025/cfusion/
```

---

## 4. Apply config across both VMs

Use `scp` + `cfconfig import` to keep `cf-dev` and `cf-prod` in sync:

```bash
# From cf-dev — push config to cf-prod and apply
scp ~/.CFConfig.json laborant@cf-prod:~/.CFConfig.json
ssh laborant@cf-prod \
  "box cfconfig import to=/opt/coldfusion2025/cfusion/ toFormat=adobe2025"

# Restart CF on prod to pick up JVM changes
ssh laborant@cf-prod "sudo systemctl restart cf-server"
curl -sf http://cf-prod:8500/index.cfm && echo "cf-prod back online"
```

---

## Key takeaways

| Concept | Detail |
|---|---|
| Authenticate | `cfide.adminapi.administrator.login("admin")` |
| List datasources | `cfide.adminapi.datasource.getDatasources()` |
| Verify datasource | `cfide.adminapi.datasource.verifyDatasource(name)` |
| JVM args | `cfide.adminapi.runtime.getJVMArgs()` |
| CFConfig file | `.CFConfig.json` — JSON representation of CF server state |
| Apply CFConfig | `box cfconfig import to=... toFormat=adobe2025` |
| Export CFConfig | `box cfconfig export to=... from=...` |

