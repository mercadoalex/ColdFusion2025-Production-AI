---
kind: challenge

title: 'Scaffold and Run a ColdBox Application'

description: |
  Use CommandBox to scaffold a ColdBox application, start the server,
  and verify the default route responds correctly.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - commandbox

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  app_cfc_extends_coldbox:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/home/laborant/app/Application.cfc"
      if [ ! -f "${FILE}" ]; then
        echo "Application.cfc not found"
        exit 1
      fi
      if ! grep -qi "coldbox.system.Bootstrap\|Bootstrap" "${FILE}"; then
        echo "Application.cfc does not extend coldbox.system.Bootstrap"
        exit 1
      fi
      echo "Application.cfc extends ColdBox Bootstrap ✓"

  router_configured:
    machine: cf-dev
    user: laborant
    needs:
      - app_cfc_extends_coldbox
    run: |
      FILE="/home/laborant/app/config/Router.cfc"
      if [ ! -f "${FILE}" ]; then
        echo "config/Router.cfc not found"
        exit 1
      fi
      if ! grep -qi "route\|resources" "${FILE}"; then
        echo "Router.cfc does not define any routes"
        exit 1
      fi
      echo "Router.cfc has routes configured ✓"

  app_responds:
    machine: cf-dev
    user: laborant
    needs:
      - router_configured
    run: |
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
      if [ "$CODE" != "200" ]; then
        echo "App not responding on port 8888 (got $CODE) — run: box server start port=8888"
        exit 1
      fi
      echo "App responding on port 8888 ✓"
---

## Scaffold and Run a ColdBox Application

### Steps

1. **Scaffold the app** (if not already done):
   ```bash
   cd /home/laborant/app
   box coldbox create app name=HelpDeskApp skeleton=AdvancedScript directory=. --force
   ```

2. **Start the server**:
   ```bash
   box server start name=helpdesk port=8888 rewritesEnable=true
   ```

3. **Verify** the default route returns HTTP 200:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8888/
   ```

::simple-task
---
:tasks: tasks
:name: app_cfc_extends_coldbox
---
#active
Confirm `Application.cfc` extends `coldbox.system.Bootstrap`.

#completed
Application.cfc extends ColdBox Bootstrap. ✓
::

::simple-task
---
:tasks: tasks
:name: router_configured
---
#active
Confirm `config/Router.cfc` defines at least one route.

#completed
Router.cfc has routes configured. ✓
::

::simple-task
---
:tasks: tasks
:name: app_responds
---
#active
Start the CommandBox server and confirm `http://localhost:8888/` returns HTTP 200.

#completed
App responding on port 8888. ✓
::
