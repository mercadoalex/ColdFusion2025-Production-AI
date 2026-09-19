---
kind: unit

title: Dependency Injection with WireBox

name: coldbox-wirebox-di-unit-1
---

## The problem DI solves

Without dependency injection, a handler that needs a ticket service creates it directly:

```cfml
// Tightly coupled — handler creates its own dependency
any function index(event, rc, prc) {
  var ticketService = createObject("component", "models.TicketService").init();
  prc.tickets = ticketService.getAll();
}
```

Problems: the handler is hard to test (you can't swap the service with a mock), the service is created on every request (no singleton), and the coupling makes refactoring risky.

**Dependency Injection** inverts this: the container creates the service and *injects* it into the handler. The handler declares what it needs; WireBox provides it.

::image-box
---
:src: __static__/wirebox-di-diagram-v1.png
:alt: Diagram showing WireBox at the centre as an IoC container — on the left, Tickets.cfc handler declares property inject="TicketService", and WireBox creates a singleton TicketService and injects it into the handler. On the right, a test spec injects a mock TicketService instead, showing how DI enables testability.
:max-width: 860px
---
_WireBox injects dependencies — handlers declare what they need, the container provides it._
::

---

## 1. Create a service model

Services live in `models/`. They are singleton CFCs that encapsulate business logic and data access.

**Activity:** Create `/home/laborant/app/models/TicketService.cfc`:

```bash
mkdir -p /home/laborant/app/models

tee /home/laborant/app/models/TicketService.cfc << 'EOF'
/**
 * TicketService
 * Encapsulates all business logic for Help Desk tickets.
 * WireBox manages this as a singleton.
 */
component accessors="true" singleton {

  // ── getAll: return all open tickets ──────────────────────────────
  query function getAll() {
    return queryExecute(
      "SELECT id, title, priority, status, created_at
       FROM   hd_tickets
       ORDER  BY created_at DESC",
      {}, { datasource: "training_db" }
    );
  }

  // ── getById: return one ticket ────────────────────────────────────
  query function getById(required numeric id) {
    return queryExecute(
      "SELECT * FROM hd_tickets WHERE id = :id",
      { id: { value: arguments.id, cfsqltype: "cf_sql_integer" } },
      { datasource: "training_db" }
    );
  }

  // ── create: insert a new ticket ───────────────────────────────────
  numeric function create(required struct data) {
    queryExecute(
      "INSERT INTO hd_tickets (title, description, priority, status, user_id)
       VALUES (:title, :description, :priority, 'open', 1)",
      {
        title:       { value: arguments.data.title,       cfsqltype: "cf_sql_varchar" },
        description: { value: arguments.data.description, cfsqltype: "cf_sql_varchar" },
        priority:    { value: arguments.data.priority,    cfsqltype: "cf_sql_varchar" }
      },
      { datasource: "training_db", result: "newTicket" }
    );
    return newTicket.generatedKey;
  }

}
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_service_exists
---
#active
Create at least one model/service CFC under `/home/laborant/app/models/`.

#completed
Service found. ✓
::

---

## 2. Inject the service into a handler

WireBox injection uses the `inject` property attribute:

**Activity:** Update `/home/laborant/app/handlers/Tickets.cfc` to use injection:

```bash
tee /home/laborant/app/handlers/Tickets.cfc << 'EOF'
component extends="coldbox.system.EventHandler" {

  // ── WireBox injects a singleton TicketService ──────────────────────
  property name="ticketService" inject="TicketService";

  // ── index: list all tickets ────────────────────────────────────────
  any function index(event, rc, prc) {
    prc.tickets = ticketService.getAll();
    event.setView("tickets/index");
  }

  // ── show: display one ticket ───────────────────────────────────────
  any function show(event, rc, prc) {
    var id = val(rc.id ?: 0);
    if (!id) { relocate("tickets"); return; }
    prc.ticket = ticketService.getById(id);
    event.setView("tickets/show");
  }

  // ── create: insert a new ticket ────────────────────────────────────
  any function create(event, rc, prc) {
    var data = {
      title:       rc.title       ?: "",
      description: rc.description ?: "",
      priority:    rc.priority    ?: "medium"
    };
    var newId = ticketService.create(data);
    relocate("tickets.show", { id: newId });
  }

}
EOF
```

::hint-box
---
:summary: How WireBox resolves inject="TicketService"
---
WireBox looks for the value in this order:
1. A component mapping named `TicketService` defined in `config/WireBox.cfc`
2. A CFC at `models/TicketService.cfc` — this is the **convention-based discovery** path

For most use cases, you only need to name your CFC correctly and place it in `models/` — no explicit WireBox configuration needed.
::

::simple-task
---
:tasks: tasks
:name: verify_injection_used
---
#active
Add a `property name="..." inject="..."` declaration to a handler CFC, or use `getInstance()` or `wirebox.getInstance()`.

#completed
WireBox injection found. ✓
::

---

## 3. Singleton scope — one instance for all requests

The `singleton` annotation in `TicketService.cfc` tells WireBox to create the service once and reuse the same instance for every request. This is important for:

- Performance — no object creation overhead per request
- Shared state — e.g., a cache held in `variables` scope

```cfml
component accessors="true" singleton {
  // variables.cache is shared across all requests
  variables.cache = {};

  query function getAll() {
    if (!structIsEmpty(variables.cache)) {
      return variables.cache.tickets;
    }
    variables.cache.tickets = queryExecute("...", ...);
    return variables.cache.tickets;
  }
}
```

::hint-box
---
:summary: Singleton safety — thread collisions
---
Singletons are shared across all concurrent requests. If your service modifies `variables` scope data, use `<cflock>` to prevent race conditions:

```cfml
cflock(name="TicketServiceCache", type="exclusive", timeout=5) {
  variables.cache.tickets = queryExecute("...", ...);
}
```

Read-only operations on `variables` scope are generally safe without locking.
::

---

## 4. Transient vs Singleton

| Scope | Annotation | Lifecycle | When to use |
|---|---|---|---|
| **Singleton** | `singleton` | One instance, lives forever | Stateless services, repositories, caches |
| **Transient** | (default) | New instance per `getInstance()` | Objects that carry per-request state |

---

## Key concepts reference

| Concept | Syntax |
|---|---|
| Declare injection | `property name="svc" inject="ServiceName";` in handler |
| Singleton service | `component singleton { ... }` |
| Get instance manually | `getInstance("TicketService")` |
| Convention path | `models/TicketService.cfc` → injected as `"TicketService"` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Service model exists and is injected into a handler — hit **Check** to complete.

#completed
WireBox DI lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.wirebox-di-49397f1b
---
::
