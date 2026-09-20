---
kind: unit

title: Handlers, Actions & Routing

name: coldbox-handlers-routing-unit-1
---

## Handlers are ColdBox's controllers

A **handler** is a CFC that groups related actions. Each public function in a handler is an **action** — a piece of logic that responds to a request. The **Router** maps incoming URLs to handler/action pairs.

::image-box
---
:src: __static__/coldbox-handler-action-routing-v1.png
:alt: Three-column diagram — left column shows URL patterns (/tickets, /tickets/1, POST /tickets), centre column shows Router.cfc mapping those URLs to handler actions, right column shows the Tickets.cfc handler with index(), show(id), and create() action functions. Arrows connect each URL to its matching action.
:max-width: 900px
---
_URL → Router → Handler action — the core request dispatch mechanism in ColdBox._
::

---

## 1. Create a handler

**Activity:** In the **Terminal (dev)** tab, use CommandBox to generate a handler:

```bash
cd /home/laborant/app

# Generate the Tickets handler with common CRUD actions
box coldbox create handler \
  name=Tickets \
  actions=index,show,new,create,edit,update,delete \
  --open
```

Or create it manually at `/home/laborant/app/handlers/Tickets.cfc`:

```bash
tee /home/laborant/app/handlers/Tickets.cfc << 'EOF'
component extends="coldbox.system.EventHandler" {

  // ── List all tickets ─────────────────────────────────────────────
  any function index(event, rc, prc) {
    prc.tickets = queryExecute(
      "SELECT id, title, priority, status FROM hd_tickets ORDER BY id DESC",
      {}, { datasource: "training_db" }
    );
    event.setView("tickets/index");
  }

  // ── Show single ticket ────────────────────────────────────────────
  any function show(event, rc, prc) {
    var id = val(rc.id ?: 0);
    if (id <= 0) {
      relocate("tickets");
      return;
    }
    prc.ticket = queryExecute(
      "SELECT * FROM hd_tickets WHERE id = :id",
      { id: { value: id, cfsqltype: "cf_sql_integer" } },
      { datasource: "training_db" }
    );
    event.setView("tickets/show");
  }

}
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_handler_exists
---
#active
Create at least one handler CFC under `/home/laborant/app/handlers/`.

#completed
Handler found. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_handler_action
---
#active
Confirm the handler CFC contains at least one `function` (action).

#completed
Handler action found. ✓
::

---

## 2. Add routes to Router.cfc

Open `/home/laborant/app/config/Router.cfc` and add a resource route:

```cfml
component extends="coldbox.system.web.routing.RequestRouter" {
  function configure() {
    // ── Default route ─────────────────────────────────────────────
    route("/").to("main.index");

    // ── RESTful resource routes for tickets ───────────────────────
    // Generates: GET /tickets           → Tickets.index
    //            GET /tickets/:id       → Tickets.show
    //            GET /tickets/new       → Tickets.new
    //            POST /tickets          → Tickets.create
    //            GET /tickets/:id/edit  → Tickets.edit
    //            PUT/PATCH /tickets/:id → Tickets.update
    //            DELETE /tickets/:id    → Tickets.delete
    resources(resource="tickets", handler="Tickets");
  }
}
```

**Activity:** Restart the server to pick up routing changes:

```bash
cd /home/laborant/app
box server restart
sleep 5
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8888/
```

::hint-box
---
:summary: resources() vs route() — when to use each
---
- `resources(resource="tickets", handler="Tickets")` generates the seven standard REST routes automatically — use this for any resource-based feature.
- `route("/path").to("handler.action")` is for custom, one-off routes — health checks, redirects, non-standard paths.

Prefer `resources()` for any CRUD resource — it keeps routing consistent and self-documenting.
::

::simple-task
---
:tasks: tasks
:name: verify_route_responds
---
#active
Restart the server and confirm the default route `http://localhost:8888/` returns HTTP 200.

#completed
Route responds with 200. ✓
::

---

## 3. Create a view for the tickets handler

Views live in `views/<handlerName>/` and use the `.cfm` extension. The `prc` (private request collection) struct is available in every view.

**Activity:** Create the view:

```bash
mkdir -p /home/laborant/app/views/tickets

tee /home/laborant/app/views/tickets/index.cfm << 'EOF'
<cfoutput>
<h2>Help Desk Tickets</h2>

<cfif prc.tickets.recordCount EQ 0>
  <p>No tickets found.</p>
<cfelse>
  <table border="1" cellpadding="5">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Priority</th>
      <th>Status</th>
    </tr>
    <cfloop query="prc.tickets">
      <tr>
        <td><a href="/tickets/#prc.tickets.id#">#prc.tickets.id#</a></td>
        <td>#htmlEditFormat(prc.tickets.title)#</td>
        <td>#prc.tickets.priority#</td>
        <td>#prc.tickets.status#</td>
      </tr>
    </cfloop>
  </table>
</cfif>
</cfoutput>
EOF
```

Test it:

```bash
curl -s http://localhost:8888/tickets | grep -o "<td>[^<]*</td>" | head -10
```

---

## 4. URL parameters in rc

When a route like `/tickets/:id` matches, the `:id` segment is automatically available in `rc.id`:

```cfml
any function show(event, rc, prc) {
  var id = val(rc.id ?: 0);  // rc.id comes from the URL
  if (!id) { relocate("tickets"); return; }
  prc.ticket = /* ... query ... */;
  event.setView("tickets/show");
}
```

For form submissions, `rc` also contains all form fields:

```cfml
any function create(event, rc, prc) {
  // rc.title, rc.description, rc.priority from the POST body
  queryExecute(
    "INSERT INTO hd_tickets (title, description, priority) VALUES (:t, :d, :p)",
    { t: { value: rc.title,       cfsqltype: "cf_sql_varchar" },
      d: { value: rc.description, cfsqltype: "cf_sql_varchar" },
      p: { value: rc.priority,    cfsqltype: "cf_sql_varchar" } },
    { datasource: "training_db" }
  );
  relocate("tickets");
}
```

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Handler | CFC in `handlers/` extending `coldbox.system.EventHandler` |
| Action | Public function inside a handler |
| Generate handler | `box coldbox create handler name=Tickets actions=index,show` |
| Resource routes | `resources(resource="tickets", handler="Tickets")` in `Router.cfc` |
| URL params | `rc.id` — from URL segment `:id` |
| Form fields | `rc.fieldName` — auto-merged from POST body |
| Set view | `event.setView("folder/viewName")` |
| Redirect | `relocate("event.handler")` |

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
Handlers & routing lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"A place for everything, and everything in its place."*
> — Benjamin Franklin

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-handlers-e49109ab
---
::
