---
kind: lesson

title: Advanced ColdFusion Administration
description: |
  Master the ColdFusion Administrator console. Configure server settings,
  manage datasources, mail servers, caching, logging, and scheduled tasks.
  Understand neo-*.xml configuration files for automation.

name: advanced-cf-administration
slug: advanced-cf-administration

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- administration
- configuration

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_admin_accessible:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/index.cfm)
      if [ "${STATUS}" != "200" ] && [ "${STATUS}" != "302" ]; then
        echo "CF Admin not accessible (got ${STATUS})"
        exit 1
      fi
      echo "CF Admin is accessible (got ${STATUS})"

  verify_neo_datasource:
    machine: cf-dev
    user: laborant
    needs:
      - verify_admin_accessible
    run: |
      FILE="/opt/coldfusion2025/cfusion/lib/neo-datasource.xml"
      if [ ! -f "${FILE}" ]; then
        echo "neo-datasource.xml not found at ${FILE}"
        exit 1
      fi
      echo "neo-datasource.xml exists"

  verify_cf_log:
    machine: cf-dev
    user: laborant
    needs:
      - verify_neo_datasource
    run: |
      LOG_DIR="/opt/coldfusion2025/cfusion/logs"
      if [ ! -d "${LOG_DIR}" ]; then
        echo "ColdFusion logs directory not found at ${LOG_DIR}"
        exit 1
      fi
      COUNT=$(ls "${LOG_DIR}"/*.log 2>/dev/null | wc -l)
      echo "Found ${COUNT} log file(s) in ${LOG_DIR}"
---

## Key neo-*.xml configuration files

| File | Purpose |
|---|---|
| `neo-datasource.xml` | Datasource definitions |
| `neo-security.xml` | Admin password, RDS, sandbox |
| `neo-mail.xml` | Mail server settings |
| `neo-caching.xml` | Cache configuration |
| `neo-logging.xml` | Log levels and rotation |
| `neo-runtime.xml` | JVM and runtime settings |

## Automate datasource creation (admin API)

```cfml
<cfscript>
  adminObj = createObject("component", "cfide.adminapi.datasource");
  adminObj.login("admin123");

  dsn = {
    name:     "new_db",
    driver:   "MySQL5",
    host:     "localhost",
    port:     3306,
    database: "mydb",
    username: "dbuser",
    password: "dbpass"
  };
  adminObj.setMysql(argumentCollection=dsn);
  writeOutput("Datasource created");
</cfscript>
```

## Check server status from CFML

```cfml
<cfscript>
  monitor = createObject("java", "coldfusion.server.ServiceFactory")
              .getServerMonitorService();
  writeOutput("Active requests: " & monitor.getActiveRequestCount());
</cfscript>
```

## Tail CF logs from terminal

```bash
tail -f /opt/coldfusion2025/cfusion/logs/application.log
tail -f /opt/coldfusion2025/cfusion/logs/exception.log
```

