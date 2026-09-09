---
kind: lesson

title: Dependency Injection with WireBox

description: |
  Use WireBox — ColdBox's built-in IoC container — to inject services
  into handlers, manage singletons, and decouple your application layers.

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  verify_service_exists:
    machine: dev-machine
    user: laborant
    run: |
      SVC=$(find /home/laborant/app/models -name "*.cfc" 2>/dev/null | head -1)
      if [ -z "$SVC" ]; then
        echo "No model/service CFC found in models/"
        exit 1
      fi
      echo "Service found: $SVC"

  verify_injection_used:
    machine: dev-machine
    user: laborant
    needs:
      - verify_service_exists
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" 2>/dev/null | head -1)
      if ! grep -qi "inject\|wirebox\|getInstance" "$HANDLER" 2>/dev/null; then
        echo "No WireBox injection found in handler"
        exit 1
      fi
      echo "WireBox injection found"
---
