---
kind: challenge

title: 'Automate CF Administration with the Admin API and CFConfig'

description: |
  Use the CF Admin API to list and verify datasources from a CFML script,
  then export the server configuration to a CFConfig JSON file — the two
  automation paths covered in the lesson, applied back-to-back.

categories:
  - programming

tagz:
  - coldfusion
  - admin-api
  - cfconfig
  - devops

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-devops-3039c6bb

tasks:
  admin_api_script_exists:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "admin_challenge.cfm not found at ${FILE}"
        exit 1
      fi
      if ! grep -qi "cfide.adminapi\|adminapi" "${FILE}"; then
        echo "admin_challenge.cfm does not use cfide.adminapi"
        exit 1
      fi
      echo "admin_challenge.cfm found and uses cfide.adminapi ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm"
      echo "It must use createObject('component','cfide.adminapi.administrator') and call login()."

  datasource_json_returned:
    machine: cf-dev
    user: laborant
    needs:
      - admin_api_script_exists
    run: |
      BODY=$(curl -s --max-time 30 http://localhost:8500/admin_challenge.cfm 2>/dev/null)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,dict) and len(d)>0" 2>/dev/null; then
        echo "admin_challenge.cfm did not return a non-empty JSON object"
        echo "Response was: ${BODY}"
        exit 1
      fi
      echo "admin_challenge.cfm returned a valid JSON datasource list ✓"
    hintcheck: |
      echo "Your admin_challenge.cfm should call dsSvc.getDatasources() and return the results with:"
      echo "  cfheader(name='Content-Type', value='application/json');"
      echo "  writeOutput(serializeJSON(result));"
      echo "Test manually: curl -s http://localhost:8500/admin_challenge.cfm | python3 -m json.tool"

  cfconfig_exported:
    machine: cf-dev
    user: laborant
    needs:
      - datasource_json_returned
    run: |
      FILE=$(find /home/laborant -name ".CFConfig.json" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo ".CFConfig.json not found under /home/laborant/"
        echo "Run: box cfconfig export to=/home/laborant/.CFConfig.json toFormat=adobe2025 from=/opt/coldfusion2025/cfusion/"
        exit 1
      fi
      if ! python3 -c "import json; json.load(open('${FILE}'))" 2>/dev/null; then
        echo ".CFConfig.json exists but is not valid JSON"
        exit 1
      fi
      echo ".CFConfig.json found and valid at ${FILE} ✓"
    hintcheck: |
      echo "Export the server config with CommandBox:"
      echo "  box cfconfig export \\"
      echo "    to=/home/laborant/.CFConfig.json \\"
      echo "    toFormat=adobe2025 \\"
      echo "    from=/opt/coldfusion2025/cfusion/"
---

## Automate CF Administration with the Admin API and CFConfig

Work through three tasks that cover both automation paths from the lesson: the CF Admin API for runtime inspection, and CFConfig for config-as-code export.

All commands run on the **Terminal (dev)** tab.

---

### Task 1 — Create admin_challenge.cfm using the CF Admin API

Create `/opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm` that authenticates with the Admin API, calls `getDatasources()`, verifies each one, and returns the result as JSON:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm << 'EOF'
<cfscript>
  // Authenticate with the CF Admin API
  adminSvc = createObject("component", "cfide.adminapi.administrator");
  adminSvc.login("admin");

  // Get all configured datasources
  dsSvc   = createObject("component", "cfide.adminapi.datasource");
  sources = dsSvc.getDatasources();

  // Build a JSON-friendly result struct
  cfheader(name="Content-Type", value="application/json");
  result = {};
  for (ds in sources) {
    result[ds.name] = {
      driver:    ds.driver ?: "unknown",
      connected: dsSvc.verifyDatasource(ds.name)
    };
  }
  writeOutput(serializeJSON(result));
</cfscript>
EOF
```

::simple-task
---
:tasks: tasks
:name: admin_api_script_exists
---
#active
Create `/opt/coldfusion2025/cfusion/wwwroot/admin_challenge.cfm` that uses `cfide.adminapi.administrator` and calls `login()`.

#completed
admin_challenge.cfm found and uses cfide.adminapi. ✓
::

---

### Task 2 — Confirm it returns a valid JSON datasource list

Hit the page with curl and confirm you get back a non-empty JSON object:

```bash
curl -s http://localhost:8500/admin_challenge.cfm | python3 -m json.tool
```

Expected output — one key per configured datasource:

```json
{
    "training_db": {
        "driver": "H2",
        "connected": true
    }
}
```

If you see a ColdFusion error page instead of JSON, check that `adminSvc.login("admin")` uses the correct CF Admin password and that `cfide.adminapi.datasource` is accessible.

::simple-task
---
:tasks: tasks
:name: datasource_json_returned
---
#active
Confirm `http://localhost:8500/admin_challenge.cfm` returns a non-empty JSON object with datasource names as keys.

#completed
admin_challenge.cfm returned a valid JSON datasource list. ✓
::

---

### Task 3 — Export the server config with CFConfig

Use the CommandBox `cfconfig` module to snapshot the current CF server configuration into a portable JSON file:

```bash
box cfconfig export \
  to=/home/laborant/.CFConfig.json \
  toFormat=adobe2025 \
  from=/opt/coldfusion2025/cfusion/

# Inspect what was exported
cat /home/laborant/.CFConfig.json | python3 -m json.tool | head -30
```

This file captures datasources, mail servers, JVM args, scheduled tasks, and security settings. Commit it to git and you have your entire server configuration under version control.

::simple-task
---
:tasks: tasks
:name: cfconfig_exported
---
#active
Run `box cfconfig export` and confirm `/home/laborant/.CFConfig.json` exists and contains valid JSON.

#completed
.CFConfig.json found and valid. ✓
::
