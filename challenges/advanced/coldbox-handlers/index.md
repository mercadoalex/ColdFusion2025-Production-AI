---
kind: challenge

title: 'Build a ColdBox Handler with Resource Routing'

description: |
  Create a ColdBox handler with at least two actions, configure resource
  routing, and verify a route resolves to the correct action.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - routing

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  handler_with_actions:
    machine: cf-dev
    user: laborant
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" \
                     ! -name "Main.cfc" 2>/dev/null | head -1)
      if [ -z "${HANDLER}" ]; then
        echo "No custom handler CFC found (other than Main.cfc)"
        exit 1
      fi
      ACTION_COUNT=$(grep -ci "any function\|void function\|string function\|query function" "${HANDLER}" 2>/dev/null || echo 0)
      if [ "${ACTION_COUNT}" -lt 2 ]; then
        echo "Handler has fewer than 2 actions"
        exit 1
      fi
      echo "Handler with ${ACTION_COUNT} actions found ✓"

  resource_route_defined:
    machine: cf-dev
    user: laborant
    needs:
      - handler_with_actions
    run: |
      FILE="/home/laborant/app/config/Router.cfc"
      if ! grep -qi "resources\b" "${FILE}" 2>/dev/null; then
        echo "Router.cfc does not define a resources() route"
        exit 1
      fi
      echo "resources() route found in Router.cfc ✓"

  route_responds:
    machine: cf-dev
    user: laborant
    needs:
      - resource_route_defined
    run: |
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
      if [ "$CODE" != "200" ]; then
        echo "Default route not responding (got $CODE)"
        exit 1
      fi
      echo "Default route responds with 200 ✓"
---

## Build a ColdBox Handler with Resource Routing

### Requirements

1. Create a handler (e.g., `handlers/Tickets.cfc`) with at least **2 action functions** (e.g., `index` and `show`)

2. Add a `resources()` route in `config/Router.cfc` pointing to your handler

3. Create a corresponding view in `views/<handlerName>/index.cfm`

4. Restart the server and verify the default route still returns 200

::simple-task
---
:tasks: tasks
:name: handler_with_actions
---
#active
Create a handler CFC (not Main.cfc) with at least 2 action functions.

#completed
Handler with 2+ actions found. ✓
::

::simple-task
---
:tasks: tasks
:name: resource_route_defined
---
#active
Add a `resources()` route to `config/Router.cfc`.

#completed
resources() route found. ✓
::

::simple-task
---
:tasks: tasks
:name: route_responds
---
#active
Confirm the default route at `http://localhost:8888/` returns HTTP 200.

#completed
Default route responds with 200. ✓
::
