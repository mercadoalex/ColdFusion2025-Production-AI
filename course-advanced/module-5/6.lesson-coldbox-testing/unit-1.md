---
kind: unit

title: Testing ColdBox Apps with TestBox & MockBox

name: coldbox-testing-testbox-unit-1
---

## Why test ColdFusion?

Untested ColdFusion code is a liability. A change to `TicketService.getAll()` can silently break the API handler, the Solr indexer, and the AI triage endpoint simultaneously — and you won't know until a user reports it. Automated tests catch regressions before they reach production.

TestBox is ColdBox's built-in testing framework. It supports:

- **BDD-style specs** — `describe/it/expect` syntax familiar from JavaScript testing
- **xUnit-style specs** — traditional `setUp/test*` pattern
- **MockBox** — mock objects and stub return values for unit testing in isolation

::image-box
---
:src: __static__/testbox-results-v1.png
:alt: TestBox HTML results page showing a test run for TicketServiceTest.cfc — green checkmarks for all four tests (getAll returns query, getById returns single row, create inserts row, create returns new id), with a summary showing 4 passed, 0 failed, 0 errors, and the execution time
:max-width: 860px
---
_TestBox results page — green is passing, red is failing, each test is labelled with its description._
::

---

## 1. Install TestBox

**Activity:**

```bash
cd /home/laborant/app

# Install TestBox from ForgeBox
box install testbox

# Verify installation
ls testbox/
```

::simple-task
---
:tasks: tasks
:name: verify_testbox_installed
---
#active
Run `box install testbox` in `/home/laborant/app` — confirm the `testbox/` directory appears.

#completed
TestBox installed. ✓
::

---

## 2. Write your first BDD spec

BDD specs use `describe()` to group related tests and `it()` to describe individual behaviours. `expect()` is the assertion method.

**Activity:** Create `/home/laborant/app/tests/specs/TicketServiceTest.cfc`:

```bash
mkdir -p /home/laborant/app/tests/specs

tee /home/laborant/app/tests/specs/TicketServiceTest.cfc << 'EOF'
component extends="testbox.system.BaseSpec" {

  function run() {
    describe("TicketService", function() {

      beforeEach(function() {
        // Get a fresh instance before each test
        variables.svc = new models.TicketService();
      });

      describe("getAll()", function() {

        it("returns a query object", function() {
          var result = variables.svc.getAll();
          expect(result).toBeTypeOf("query");
        });

        it("returns at least one row when tickets exist", function() {
          var result = variables.svc.getAll();
          expect(result.recordCount).toBeGTE(1);
        });

      });

      describe("getById()", function() {

        it("returns a query with one row for a valid id", function() {
          var result = variables.svc.getById(1);
          expect(result.recordCount).toBe(1);
        });

        it("returns an empty query for an invalid id", function() {
          var result = variables.svc.getById(99999);
          expect(result.recordCount).toBe(0);
        });

      });

      describe("create()", function() {

        it("inserts a ticket and returns a numeric id", function() {
          var data = {
            title:       "Test ticket from TestBox",
            description: "Automated test",
            priority:    "low"
          };
          var newId = variables.svc.create(data);
          expect(newId).toBeNumeric();
          expect(newId).toBeGT(0);
        });

      });

    });
  }

}
EOF
```

---

## 3. Run the tests

**Activity:**

```bash
# Run tests via the TestBox text runner
curl -s "http://localhost:8888/testbox/system/runners/TextRunner.cfm?directory=tests/specs"
```

Or open the HTML runner in your browser via the **Lucee Dev Server** tab:
```
http://localhost:8888/testbox/system/runners/HtmlRunner.cfm?directory=tests/specs
```

::simple-task
---
:tasks: tasks
:name: verify_test_spec_exists
---
#active
Create at least one TestBox spec file (`*Spec.cfc` or `*Test.cfc`) under `tests/`.

#completed
Test spec found. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_tests_pass
---
#active
Run the TestBox runner and confirm all tests pass (no failures or errors in the output).

#completed
All tests pass. ✓
::

---

## 4. MockBox — isolating dependencies in unit tests

MockBox creates mock objects that stub method return values, letting you test handlers without hitting the database.

```cfml
component extends="coldbox.system.testing.BaseTestCase" {

  function run() {
    describe("Tickets handler", function() {

      it("index action renders the tickets view", function() {
        // ── Create a mock TicketService ──────────────────────────────
        var mockService = createMock("models.TicketService");

        // Stub getAll() to return a fake query
        var fakeTickets = queryNew("id,title,priority", "integer,varchar,varchar");
        queryAddRow(fakeTickets, { id: 1, title: "Fake ticket", priority: "low" });
        mockService.$("getAll", fakeTickets);

        // ── Execute the handler action ───────────────────────────────
        var event = execute(event="tickets.index", renderResults=true);

        // ── Assert ───────────────────────────────────────────────────
        expect(event.getCurrentView()).toBe("tickets/index");
        expect(event.getPrivateValue("tickets").recordCount).toBe(1);
      });

    });
  }

}
```

::hint-box
---
:summary: Unit tests vs integration tests in TestBox
---
- **Unit tests** — test one CFC in isolation with mocked dependencies. Fast, no DB required.
- **Integration tests** — test the full ColdBox request pipeline with a real DB. Slower, but catch wiring issues.

Start with unit tests for models/services. Add integration tests for critical API endpoints. Use the `BaseSpec` for unit tests and `BaseTestCase` for integration tests.
::

---

## 5. CommandBox test runner

Run tests from the terminal without a browser:

```bash
# Run all specs and print results
box testbox run \
  directory=tests/specs \
  verbose=true

# Run with exit code (for CI pipelines — exits non-zero on failures)
box testbox run directory=tests/specs && echo "Tests passed" || echo "Tests FAILED"
```

---

## Key concepts reference

| Concept | TestBox syntax |
|---|---|
| Spec file | `component extends="testbox.system.BaseSpec"` |
| Test suite | `describe("name", function() { ... })` |
| Test case | `it("should ...", function() { ... })` |
| Assertion | `expect(value).toBe(expected)` |
| Before each | `beforeEach(function() { ... })` |
| Create mock | `createMock("models.TicketService")` |
| Stub method | `mockObj.$("methodName", returnValue)` |
| CLI runner | `box testbox run directory=tests/specs` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all previous tasks pass.

#completed
TestBox testing lesson complete. ✓ You've finished the advanced course!
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-testing-132cd670
---
::
