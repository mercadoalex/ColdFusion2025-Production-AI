---
kind: challenge

title: 'WireBox DI — Inject a Service into a Handler'

description: |
  Create a singleton service in models/, inject it into a handler using
  WireBox, and verify the injection works by hitting a handler action.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - wirebox

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  singleton_service_exists:
    machine: cf-dev
    user: laborant
    run: |
      SVC=$(find /home/laborant/app/models -name "*.cfc" 2>/dev/null | head -1)
      if [ -z "${SVC}" ]; then
        echo "No service CFC found in models/"
        exit 1
      fi
      if ! grep -qi "singleton" "${SVC}"; then
        echo "Service CFC is not annotated as singleton"
        exit 1
      fi
      echo "Singleton service found: ${SVC} ✓"

  injection_declared:
    machine: cf-dev
    user: laborant
    needs:
      - singleton_service_exists
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" \
                     ! -name "Main.cfc" 2>/dev/null | head -1)
      if ! grep -qi "inject=" "${HANDLER}" 2>/dev/null; then
        echo "No inject= property found in handler"
        exit 1
      fi
      echo "WireBox injection declared in handler ✓"

  injected_service_used:
    machine: cf-dev
    user: laborant
    needs:
      - injection_declared
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" \
                     ! -name "Main.cfc" 2>/dev/null | head -1)
      # Check the handler actually calls the injected property
      INJECT_NAME=$(grep -oi "name=\"[^\"]*\"" "${HANDLER}" | head -1 | tr -d '"' | sed 's/name=//')
      if [ -z "${INJECT_NAME}" ]; then
        echo "Could not determine injected property name"
        exit 1
      fi
      if ! grep -qi "${INJECT_NAME}\." "${HANDLER}"; then
        echo "Injected property '${INJECT_NAME}' is declared but never called"
        exit 1
      fi
      echo "Injected service '${INJECT_NAME}' is called in handler ✓"
---

## WireBox DI — Inject a Service into a Handler

### Requirements

1. Create `models/TicketService.cfc` (or similar) annotated with `singleton`
   - Include at least one public method (e.g., `getAll()`)

2. Declare the injection in a handler using:
   ```cfml
   property name="ticketService" inject="TicketService";
   ```

3. Call the injected service in at least one handler action

::simple-task
---
:tasks: tasks
:name: singleton_service_exists
---
#active
Create a singleton CFC in `models/`.

#completed
Singleton service found. ✓
::

::simple-task
---
:tasks: tasks
:name: injection_declared
---
#active
Add `property name="..." inject="..."` to a handler CFC.

#completed
WireBox injection declared. ✓
::

::simple-task
---
:tasks: tasks
:name: injected_service_used
---
#active
Call a method on the injected property inside a handler action.

#completed
Injected service is called in handler. ✓
::
