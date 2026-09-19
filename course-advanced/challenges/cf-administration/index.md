---
kind: challenge

title: 'Automate Datasource Creation with the CF Admin API'

description: |
  Use the CF Admin API to programmatically list datasources, verify connectivity,
  and export the server configuration to a CFConfig JSON file.

categories:
  - programming

tagz:
  - coldfusion
  - admin-api
  - cfconfig

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  admin_api_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/admin_challenge.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "admin_challenge.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "admin_challenge.cfm accessible ✓"

  datasource_listed:
    machine: cf-dev
    user: laborant
    needs:
      - admin_api_page
    run: |
      BODY=$(curl -s http://localhost:8500/admin_challenge.cfm)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d) > 0" 2>/dev/null; then
        echo "admin_challenge.cfm did not return a non-empty JSON object"
        exit 1
      fi
      echo "Datasource list returned ✓"

  cfconfig_exported:
    machine: cf-dev
    user: laborant
    needs:
      - datasource_listed
    run: |
      FILE=$(find /home/laborant -name ".CFConfig.json" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo ".CFConfig.json not found — run: box cfconfig export"
        exit 1
      fi
      echo ".CFConfig.json found at ${FILE} ✓"
---

## Automate Datasource Creation with the CF Admin API

### Part 1 — List datasources (admin_challenge.cfm)

Create `/opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm` that:
1. Authenticates with the CF Admin API using `cfide.adminapi.administrator`
2. Calls `getDatasources()` on the datasource service
3. For each datasource, calls `verifyDatasource()` and includes the result
4. Returns the results as JSON

### Part 2 — Export server config

Run the following to export the CF server config:
```bash
box cfconfig export to=/home/laborant/.CFConfig.json toFormat=adobe2025 from=/opt/coldfusion2025/cfusion/
```

::simple-task
---
:tasks: tasks
:name: admin_api_page
---
#active
Create `admin_challenge.cfm` that returns HTTP 200.

#completed
admin_challenge.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: datasource_listed
---
#active
Return a non-empty JSON object from `admin_challenge.cfm` with datasource names as keys.

#completed
Datasource list returned. ✓
::

::simple-task
---
:tasks: tasks
:name: cfconfig_exported
---
#active
Export the server config to `/home/laborant/.CFConfig.json` using the `box cfconfig export` command.

#completed
.CFConfig.json found. ✓
::
