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
  name: cf-training-advanced-7442b9e0

challenges:
  solid-principles-6a4f2c91: {}

tasks:
  init_wait_for_cf:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 120
    run: |
      until curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/ | grep -q "200\|302"; do
        echo "Waiting for ColdFusion on port 8500..."
        sleep 5
      done
      echo "ColdFusion is up ✓"

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
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/solid/demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "solid/demo.cfm not accessible (HTTP ${STATUS})"
        exit 1
      fi
      BODY=$(curl -s http://localhost:8500/solid/demo.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "solid/demo.cfm returned a ColdFusion error"
        exit 1
      fi
      echo "solid/demo.cfm runs cleanly ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_solid_page
    run: |
      echo "SOLID principles lesson complete — course done! ✓"
---
