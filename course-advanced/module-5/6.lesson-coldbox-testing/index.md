---
kind: lesson

title: Testing ColdBox Apps with TestBox & MockBox

description: |
  Write unit and integration tests for ColdBox handlers and services
  using TestBox BDD specs and MockBox for dependency mocking.

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  verify_testbox_installed:
    machine: dev-machine
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/testbox" ]; then
        echo "TestBox not installed — run: box install testbox"
        exit 1
      fi
      echo "TestBox installed"

  verify_test_spec_exists:
    machine: dev-machine
    user: laborant
    needs:
      - verify_testbox_installed
    run: |
      SPEC=$(find /home/laborant/app/tests -name "*Spec.cfc" -o -name "*Test.cfc" 2>/dev/null | head -1)
      if [ -z "$SPEC" ]; then
        echo "No TestBox spec found in tests/"
        exit 1
      fi
      echo "Test spec found: $SPEC"

  verify_tests_pass:
    machine: dev-machine
    user: laborant
    needs:
      - verify_test_spec_exists
    run: |
      RESULT=$(curl -s "http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs")
      if echo "$RESULT" | grep -qi "failures.*[1-9]\|errors.*[1-9]"; then
        echo "TestBox tests have failures or errors"
        exit 1
      fi
      echo "All tests pass"
---
