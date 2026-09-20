---
kind: unit

title: Building REST APIs with ColdBox

name: coldbox-rest-api-unit-1
---

## REST APIs with MVC structure

Raw CFML `.cfm` files can serve JSON, but they have no routing conventions, no input validation layer, no consistent response format, and no way to enforce HTTP verb semantics. ColdBox's `renderData()` and resource routing give you all of that with minimal boilerplate.

::image-box
---
:src: __static__/coldbox-rest-flow-v1.png
:alt: Request flow diagram — a client sends GET /api/tickets with Accept: application/json. ColdBox Router maps it to Tickets.index. The handler calls TicketService.getAll(), formats the query as an array of structs, and calls event.renderData(type="json", data=tickets). ColdBox automatically serialises the data and sends the response with Content-Type: application/json.
:max-width: 900px
---
_ColdBox REST flow: router → handler → renderData(type="json") → automatic serialisation._
::

---

## 1. renderData() — the ColdBox JSON response method

`event.renderData()` serialises data to JSON (or XML, text, HTML) and sets the appropriate `Content-Type` header automatically.

```cfml
any function index(event, rc, prc) {
  var tickets = ticketService.getAll();

  // Serialise the query to a JSON array
  event.renderData(
    type = "json",
    data = queryToArray(tickets),  // convert CF query to array of structs
    statusCode = 200
  );
}
```

Helper function `queryToArray()`:

```cfml
private array function queryToArray(required query q) {
  var result = [];
  for (var row in arguments.q) {
    arrayAppend(result, duplicate(row));
  }
  return result;
}
```

---

## 2. Add REST routes

In `config/Router.cfc`, namespace the API routes under `/api`:

```cfml
component extends="coldbox.system.web.routing.RequestRouter" {
  function configure() {
    route("/").to("main.index");

    // ── REST API namespace ─────────────────────────────────────────
    prefix(pattern="/api") {
      resources(resource="tickets", handler="api.Tickets");
    }
  }
}
```

---

## 3. Build the API handler

**Activity:** Create `/home/laborant/app/handlers/api/Tickets.cfc`:

```bash
mkdir -p /home/laborant/app/handlers/api

tee /home/laborant/app/handlers/api/Tickets.cfc << 'EOF'
component extends="coldbox.system.EventHandler" {

  property name="ticketService" inject="TicketService";

  // ── GET /api/tickets ──────────────────────────────────────────────
  any function index(event, rc, prc) {
    event.renderData(
      type       = "json",
      data       = queryToArray(ticketService.getAll()),
      statusCode = 200
    );
  }

  // ── GET /api/tickets/:id ───────────────────────────────────────────
  any function show(event, rc, prc) {
    var id = val(rc.id ?: 0);
    var ticket = ticketService.getById(id);
    if (!ticket.recordCount) {
      event.renderData(
        type       = "json",
        data       = { "error": "Ticket not found" },
        statusCode = 404
      );
      return;
    }
    event.renderData(
      type       = "json",
      data       = queryToArray(ticket)[1],
      statusCode = 200
    );
  }

  // ── POST /api/tickets ──────────────────────────────────────────────
  any function create(event, rc, prc) {
    var data = {
      title:       rc.title       ?: "",
      description: rc.description ?: "",
      priority:    rc.priority    ?: "medium"
    };
    if (!len(trim(data.title))) {
      event.renderData(
        type       = "json",
        data       = { "error": "title is required" },
        statusCode = 400
      );
      return;
    }
    var newId = ticketService.create(data);
    event.renderData(
      type       = "json",
      data       = { "id": newId, "created": true },
      statusCode = 201
    );
  }

  // ── Private helper ─────────────────────────────────────────────────
  private array function queryToArray(required query q) {
    var result = [];
    for (var row in arguments.q) { arrayAppend(result, duplicate(row)); }
    return result;
  }

}
EOF
```

**Test it:**

```bash
# Restart to pick up new handler
box server restart
sleep 5

# List tickets
curl -s http://localhost:8888/api/tickets | python3 -m json.tool

# Get one ticket
curl -s http://localhost:8888/api/tickets/1 | python3 -m json.tool

# Create a ticket
curl -s -X POST http://localhost:8888/api/tickets \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "title=Test+ticket&description=Created+via+API&priority=low" \
  | python3 -m json.tool
```

::simple-task
---
:tasks: tasks
:name: verify_api_handler
---
#active
Create a handler that uses `event.renderData()` to return JSON.

#completed
API handler with renderData found. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_api_responds
---
#active
Confirm `GET http://localhost:8888/api/tickets` returns valid JSON.

#completed
API returns valid JSON. ✓
::

---

## 4. HTTP verb enforcement

ColdBox `resources()` already restricts handlers to the correct HTTP verb per route. For custom routes, use the `method` argument:

```cfml
// Only accepts GET requests
route("/api/health")
  .to("api.Health.index")
  .withMethod("GET");

// Multiple verbs
route("/api/tickets/:id/close")
  .to("api.Tickets.close")
  .withMethod("POST,PATCH");
```

::hint-box
---
:summary: CORS headers for browser clients
---
If a browser-based frontend (React, Vue) calls your ColdBox API from a different origin, you'll need CORS headers. Add an interceptor or use the cbSecurity module, or add headers in a `preProcess()` interceptor:

```cfml
function preProcess(event, interceptData, rc, prc) {
  event.setHTTPHeader(name="Access-Control-Allow-Origin", value="*");
  event.setHTTPHeader(name="Access-Control-Allow-Methods", value="GET,POST,PUT,DELETE,OPTIONS");
}
```
::

---

## Key concepts reference

| Concept | Syntax |
|---|---|
| JSON response | `event.renderData(type="json", data=myArray, statusCode=200)` |
| 404 response | `event.renderData(type="json", data={error:"..."}, statusCode=404)` |
| Resource routes | `resources(resource="tickets", handler="api.Tickets")` |
| API namespace | `prefix(pattern="/api") { resources(...) }` in Router.cfc |
| Verb enforcement | `.withMethod("POST")` on route definition |

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
ColdBox REST API lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"A good API is not just easy to use, it's hard to misuse."*
> — Joshua Bloch

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-rest-b4e57e76
---
::
