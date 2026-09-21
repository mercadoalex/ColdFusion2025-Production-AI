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
  name: cf-training-devops-3039c6bb

challenges:
  coldbox-testing-132cd670: {}

tasks:
  verify_testbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/testbox" ]; then
        echo "TestBox not installed — run: box install testbox"
        exit 1
      fi
      echo "TestBox installed ✓"
    hintcheck: |
      echo "Install TestBox: cd /home/laborant/app && box install testbox"

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
    hintcheck: |
      echo "Create a spec: box coldbox create bdd name=MainSpec"
      echo "Spec files should be in ~/app/tests/specs/ and end in Spec.cfc or Test.cfc"

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
    hintcheck: |
      echo "Run tests manually: curl -s 'http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs'"
      echo "Fix any failures shown in the output before this task turns green."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_tests_pass
    run: |
      echo "TestBox testing lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
