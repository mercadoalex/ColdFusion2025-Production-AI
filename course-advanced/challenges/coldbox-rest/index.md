---
kind: challenge

title: 'Build a REST API with ColdBox renderData()'

description: |
  Create a ColdBox REST API handler that returns JSON using renderData(),
  supports GET (list) and GET/:id (single), and returns proper HTTP status codes.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - rest
  - api

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  render_data_used:
    machine: cf-dev
    user: laborant
    run: |
      HANDLER=$(grep -rl "renderData" /home/laborant/app/handlers/ 2>/dev/null | head -1)
      if [ -z "${HANDLER}" ]; then
        echo "No renderData() call found in any handler"
        exit 1
      fi
      echo "renderData() found in ${HANDLER} ✓"

  api_list_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - render_data_used
    run: |
      BODY=$(curl -s http://localhost:8888/api/tickets 2>/dev/null)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, list)" 2>/dev/null; then
        echo "/api/tickets did not return a JSON array"
        exit 1
      fi
      echo "/api/tickets returns JSON array ✓"

  proper_status_codes:
    machine: cf-dev
    user: laborant
    needs:
      - api_list_endpoint
    run: |
      # 404 for non-existent ticket
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/api/tickets/99999)
      if [ "${CODE}" != "404" ]; then
        echo "/api/tickets/99999 returned ${CODE} instead of 404"
        exit 1
      fi
      echo "Non-existent resource returns 404 ✓"
---

## Build a REST API with ColdBox renderData()

### Requirements

1. Create `handlers/api/Tickets.cfc` with:
   - `index()` action — returns all tickets as a JSON array (HTTP 200)
   - `show()` action — returns one ticket by ID, or JSON error with HTTP 404

2. Add a prefixed resource route in `Router.cfc`:
   ```cfml
   prefix(pattern="/api") {
     resources(resource="tickets", handler="api.Tickets");
   }
   ```

3. Test:
   ```bash
   curl -s http://localhost:8888/api/tickets | python3 -m json.tool
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8888/api/tickets/99999
   ```

::simple-task
---
:tasks: tasks
:name: render_data_used
---
#active
Create a handler that calls `event.renderData(type="json", ...)`.

#completed
renderData() found in handler. ✓
::

::simple-task
---
:tasks: tasks
:name: api_list_endpoint
---
#active
Make `GET /api/tickets` return a valid JSON array.

#completed
/api/tickets returns JSON array. ✓
::

::simple-task
---
:tasks: tasks
:name: proper_status_codes
---
#active
Return HTTP 404 when a ticket ID does not exist.

#completed
Non-existent resource returns 404. ✓
::
