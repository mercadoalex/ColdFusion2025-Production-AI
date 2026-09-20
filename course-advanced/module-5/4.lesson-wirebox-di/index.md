---
kind: lesson

title: Dependency Injection with WireBox

description: |
  Use WireBox — ColdBox's built-in IoC container — to inject services
  into handlers, manage singletons, and decouple your application layers.

name: coldbox-wirebox-di
slug: coldbox-wirebox-di

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- wirebox
- dependency-injection

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  wirebox-di-49397f1b: {}

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

  verify_service_exists:
    machine: cf-dev
    user: laborant
    run: |
      SVC=$(find /home/laborant/app/models -name "*.cfc" 2>/dev/null | head -1)
      if [ -z "$SVC" ]; then
        echo "No model/service CFC found in models/"
        exit 1
      fi
      echo "Service found: $SVC ✓"

  verify_injection_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_service_exists
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" 2>/dev/null | head -1)
      if ! grep -qi "inject\|wirebox\|getInstance" "$HANDLER" 2>/dev/null; then
        echo "No WireBox injection found in handler"
        exit 1
      fi
      echo "WireBox injection found ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_injection_used
    run: |
      echo "WireBox DI lesson complete ✓"
---
