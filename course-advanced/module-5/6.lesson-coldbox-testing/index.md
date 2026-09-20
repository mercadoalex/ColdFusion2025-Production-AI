---
kind: lesson

title: Testing ColdBox Apps with TestBox & MockBox

description: |
  Write unit and integration tests for ColdBox handlers and services
  using TestBox BDD specs and MockBox for dependency mocking.

name: coldbox-testing-testbox
slug: coldbox-testing-testbox

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- testbox
- testing

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  coldbox-testing-132cd670: {}

tasks:
  init_wait_for_cf:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 300
    run: |
      until nc -z 127.0.0.1 8500 2>/dev/null; do
        echo "Waiting for ColdFusion on port 8500..."
        sleep 5
      done
      sleep 10
      echo "ColdFusion is up ✓"

  verify_testbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/testbox" ]; then
        echo "TestBox not installed — run: box install testbox"
        exit 1
      fi
      echo "TestBox installed ✓"

  verify_test_spec_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_testbox_installed
    run: |
      SPEC=$(find /home/laborant/app/tests -name "*Spec.cfc" -o -name "*Test.cfc" 2>/dev/null | head -1)
      if [ -z "$SPEC" ]; then
        echo "No TestBox spec found in tests/"
        exit 1
      fi
      echo "Test spec found: $SPEC ✓"

  verify_tests_pass:
    machine: cf-dev
    user: laborant
    needs:
      - verify_test_spec_exists
    run: |
      RESULT=$(curl -s "http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs")
      if echo "$RESULT" | grep -qi "failures.*[1-9]\|errors.*[1-9]"; then
        echo "TestBox tests have failures or errors"
        exit 1
      fi
      echo "All tests pass ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_tests_pass
    run: |
      echo "TestBox testing lesson complete ✓"
---
