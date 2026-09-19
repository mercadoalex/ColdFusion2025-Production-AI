---
kind: challenge

title: 'Write and Pass TestBox BDD Tests'

description: |
  Install TestBox, write a BDD spec for a service CFC, and confirm
  all tests pass with the TestBox CLI runner.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - testbox
  - testing

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  testbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/testbox" ]; then
        echo "TestBox not found — run: box install testbox"
        exit 1
      fi
      echo "TestBox installed ✓"

  spec_file_exists:
    machine: cf-dev
    user: laborant
    needs:
      - testbox_installed
    run: |
      SPEC=$(find /home/laborant/app/tests -name "*Spec.cfc" -o -name "*Test.cfc" 2>/dev/null | head -1)
      if [ -z "${SPEC}" ]; then
        echo "No TestBox spec file found under tests/"
        exit 1
      fi
      if ! grep -qi "extends.*BaseSpec\|extends.*BaseTestCase" "${SPEC}"; then
        echo "${SPEC} does not extend BaseSpec or BaseTestCase"
        exit 1
      fi
      echo "Spec file found: ${SPEC} ✓"

  all_tests_pass:
    machine: cf-dev
    user: laborant
    needs:
      - spec_file_exists
    run: |
      RESULT=$(curl -s "http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs" 2>/dev/null)
      if echo "${RESULT}" | grep -qiE "failures\s*=\s*[1-9]|errors\s*=\s*[1-9]"; then
        echo "TestBox tests have failures or errors"
        exit 1
      fi
      if ! echo "${RESULT}" | grep -qi "passed\|tests run"; then
        echo "Could not confirm tests ran — is the server running on port 8888?"
        exit 1
      fi
      echo "All TestBox tests pass ✓"
---

## Write and Pass TestBox BDD Tests

### Requirements

1. Install TestBox:
   ```bash
   cd /home/laborant/app && box install testbox
   ```

2. Create a spec file at `tests/specs/TicketServiceTest.cfc` (or similar) that:
   - Extends `testbox.system.BaseSpec`
   - Contains a `describe()` block with at least **2 `it()` tests**
   - Tests methods on a model CFC (e.g., `TicketService.getAll()`)

3. Run the tests and confirm all pass:
   ```bash
   curl -s "http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs"
   ```

### Example spec structure

```cfml
component extends="testbox.system.BaseSpec" {
  function run() {
    describe("TicketService", function() {
      it("getAll() returns a query", function() {
        var svc = new models.TicketService();
        expect(svc.getAll()).toBeTypeOf("query");
      });
      it("getById() returns 1 row for id=1", function() {
        var svc = new models.TicketService();
        expect(svc.getById(1).recordCount).toBe(1);
      });
    });
  }
}
```

::simple-task
---
:tasks: tasks
:name: testbox_installed
---
#active
Install TestBox with `box install testbox`.

#completed
TestBox installed. ✓
::

::simple-task
---
:tasks: tasks
:name: spec_file_exists
---
#active
Create a spec file extending `BaseSpec` under `tests/specs/`.

#completed
Spec file found. ✓
::

::simple-task
---
:tasks: tasks
:name: all_tests_pass
---
#active
Run the TestBox runner and confirm no failures or errors.

#completed
All TestBox tests pass. ✓
::
