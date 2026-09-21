---
kind: lesson

title: SOLID Principles in ColdFusion
description: |
  Apply the five SOLID design principles to ColdFusion applications using
  CFCs, interfaces, abstract components, and WireBox dependency injection.
  Write code that is easier to test, extend, and hand off.

name: solid-principles-coldfusion
slug: solid-principles-coldfusion

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- cfml
- solid
- oop
- wirebox

playground:
  name: cf-training-devops-3039c6bb

challenges:
  solid-principles-6a4f2c91: {}

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
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/solid/TicketNotifier.cfc"
      echo "Follow the SRP Activity in section 1."

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
    hintcheck: |
      echo "Create INotifier.cfc with: <cfinterface> ... </cfinterface>"
      echo "See the OCP Activity in section 2."

  verify_solid_page:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ocp_interface
    run: |
      BODY=$(curl -s http://localhost:8500/solid/demo.cfm)
      STATUS=$?
      if [ -z "${BODY}" ] || echo "${BODY}" | grep -qi "error\|exception"; then
        echo "solid/demo.cfm is not accessible or returned a ColdFusion error"
        exit 1
      fi
      echo "solid/demo.cfm runs cleanly ✓"
    hintcheck: |
      echo "Create solid/demo.cfm — follow the final Activity in section 5."
      echo "Check logs if it errors: tail /opt/coldfusion2025/cfusion/logs/exception.log"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_solid_page
    run: |
      echo "SOLID principles lesson complete — course done! ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
