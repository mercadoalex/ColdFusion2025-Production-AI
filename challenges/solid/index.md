---
kind: challenge

title: 'Apply SOLID Principles in ColdFusion'

description: |
  Apply the five SOLID design principles to a ColdFusion application using
  CFCs, interfaces, and WireBox dependency injection. Create TicketNotifier.cfc
  (SRP), an INotifier.cfc interface (OCP/LSP), and a demo page that wires them
  together cleanly.

categories:
  - programming

tagz:
  - coldfusion
  - cfml
  - solid
  - oop
  - wirebox

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_srp_cfc:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/solid/TicketNotifier.cfc"
      if [ ! -f "${FILE}" ]; then
        echo "TicketNotifier.cfc not found at /opt/coldfusion2025/cfusion/wwwroot/solid/"
        exit 1
      fi
      echo "TicketNotifier.cfc exists ✓"

  verify_ocp_interface:
    machine: cf-dev
    user: laborant
    needs:
      - verify_srp_cfc
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/solid/INotifier.cfc"
      if [ ! -f "${FILE}" ]; then
        echo "INotifier.cfc interface not found"
        exit 1
      fi
      if ! grep -qi "interface" "${FILE}" 2>/dev/null; then
        echo "INotifier.cfc does not appear to be an interface"
        exit 1
      fi
      echo "INotifier.cfc interface exists ✓"

  verify_solid_page:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ocp_interface
    run: |
      BODY=$(curl -s http://localhost:8500/solid/demo.cfm)
      if [ -z "${BODY}" ] || echo "${BODY}" | grep -qi "error\|exception"; then
        echo "solid/demo.cfm is not accessible or returned a ColdFusion error"
        exit 1
      fi
      echo "solid/demo.cfm runs cleanly ✓"
---

## Apply SOLID Principles in ColdFusion

Apply the five SOLID design principles to a real ColdFusion application.
Work in `/opt/coldfusion2025/cfusion/wwwroot/solid/`.

---

### Task 1 — Single Responsibility: TicketNotifier.cfc

Create `TicketNotifier.cfc` with a single responsibility — sending notifications.
It must not contain query logic or business rules.

```bash
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/solid
```

::simple-task
---
:tasks: tasks
:name: verify_srp_cfc
---
#active
Create `/opt/coldfusion2025/cfusion/wwwroot/solid/TicketNotifier.cfc`

#completed
TicketNotifier.cfc exists. ✓
::

---

### Task 2 — Open/Closed: INotifier.cfc interface

Create `INotifier.cfc` as a ColdFusion interface so that new notifier types
can be added without modifying existing code.

```coldfusion
<cfinterface>
  <cffunction name="sendResolved" returntype="void" access="public">
    <cfargument name="ticketId" type="numeric" required="true">
  </cffunction>
</cfinterface>
```

::simple-task
---
:tasks: tasks
:name: verify_ocp_interface
---
#active
Create `/opt/coldfusion2025/cfusion/wwwroot/solid/INotifier.cfc` as a `<cfinterface>`

#completed
INotifier.cfc interface exists. ✓
::

---

### Task 3 — Wire it together: demo.cfm

Create `solid/demo.cfm` that instantiates `TicketNotifier.cfc` and renders a
page without errors — proving the SOLID components work together.

::simple-task
---
:tasks: tasks
:name: verify_solid_page
---
#active
Create `/opt/coldfusion2025/cfusion/wwwroot/solid/demo.cfm` — must return a page with no ColdFusion errors.

#completed
solid/demo.cfm runs cleanly. ✓
::
