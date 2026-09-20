---
kind: unit

title: SOLID Principles in ColdFusion

name: solid-principles-coldfusion-unit-1
---

## Why SOLID matters in ColdFusion

SOLID is a set of five design principles for object-oriented code, coined by Robert C. Martin (Uncle Bob). Applied consistently, they produce CFCs that are:

- **Easier to test** — each class has one job, so tests are small and focused
- **Easier to extend** — new behaviour is added without editing existing code
- **Easier to hand off** — another developer can read and understand a class without reading its entire dependency tree

::hint-box
---
:summary: Where did SOLID come from — and why does it still matter in 2025?
---
Robert C. Martin introduced SOLID in the early 2000s, drawing on earlier work by Bertrand Meyer (Open/Closed, 1988) and Barbara Liskov (Liskov Substitution, 1987). The acronym was popularised in his 2003 book *Agile Software Development*.

The five principles are not ColdFusion-specific or even object-oriented-specific — they are heuristics for managing change in software systems. Code that violates them tends to develop **"rigidity"** (one change breaks many things), **"fragility"** (it breaks in unexpected places), and **"immobility"** (you cannot reuse parts of it in other projects).

In 2025 they remain the most widely referenced design vocabulary in professional software teams. Knowing them lets you participate in code review discussions, understand architectural decisions, and write code that your future self will thank you for.

**What ColdFusion supports well:**

CFCs give you inheritance, interfaces, abstract components, final classes/methods, and covariance (since the 2021 release) — all the building blocks SOLID needs. Dependency injection works naturally: you can pass CFC instances into `init()` methods, and WireBox (the standard CFML DI container) makes it even easier. SRP is the easiest to adopt — just split fat CFCs into focused ones. OCP and DIP work well via abstract base classes and interfaces that CFCs implement.
::

| Principle | One-line definition |
|---|---|
| **S** — Single Responsibility | A class should have one reason to change |
| **O** — Open/Closed | Open for extension, closed for modification |
| **L** — Liskov Substitution | Subtypes must be substitutable for their base types |
| **I** — Interface Segregation | No client should depend on methods it does not use |
| **D** — Dependency Inversion | Depend on abstractions, not concretions |

---

## S — Single Responsibility Principle

> *A class should have one, and only one, reason to change.*

### The violation

```cfml
// TicketService.cfc — does everything: business logic + email + logging
component {
  function resolveTicket(ticketId) {
    // 1. update database
    queryExecute("UPDATE tickets SET status='resolved' WHERE id=:id",
                 {id:{value:ticketId, cfsqltype:"cf_sql_integer"}});
    // 2. send email notification
    cfmail(to="user@example.com", from="help@company.com",
           subject="Ticket resolved", type="text") {
      writeOutput("Your ticket #" & ticketId & " has been resolved.");
    }
    // 3. write audit log
    fileAppend("/logs/audit.log",
               now() & " ticket " & ticketId & " resolved" & chr(10));
  }
}
```

Three reasons to change: the database schema changes, the email template changes, or the log format changes. Any change risks breaking the other two.

### The fix — split into focused CFCs

```cfml
// TicketRepository.cfc — only knows about data
component {
  function resolve(ticketId) {
    queryExecute("UPDATE tickets SET status='resolved' WHERE id=:id",
                 {id:{value:ticketId, cfsqltype:"cf_sql_integer"}});
  }
}

// TicketNotifier.cfc — only knows about notifications
component {
  function sendResolved(ticketId, userEmail) {
    cfmail(to=userEmail, from="help@company.com",
           subject="Ticket ##" & ticketId & " resolved", type="text") {
      writeOutput("Your ticket has been resolved. Thank you.");
    }
  }
}

// AuditLogger.cfc — only knows about logging
component {
  function log(message) {
    fileAppend("/logs/audit.log", now() & " " & message & chr(10));
  }
}

// TicketService.cfc — orchestrates, owns the use case
component {
  function init(repo, notifier, logger) {
    variables.repo     = repo;
    variables.notifier = notifier;
    variables.logger   = logger;
    return this;
  }
  function resolveTicket(ticketId, userEmail) {
    variables.repo.resolve(ticketId);
    variables.notifier.sendResolved(ticketId, userEmail);
    variables.logger.log("ticket " & ticketId & " resolved");
  }
}
```

Each CFC now has exactly one reason to change.

---

## O — Open/Closed Principle

> *Software entities should be open for extension but closed for modification.*

Adding a new notification channel (Slack, SMS) should not require editing existing working code.

### Using an interface

```cfml
// INotifier.cfc — the abstraction (interface)
interface {
  public void function sendResolved(required numeric ticketId,
                                    required string recipient);
}

// EmailNotifier.cfc — implements INotifier
component implements="INotifier" {
  public void function sendResolved(required numeric ticketId,
                                    required string recipient) {
    cfmail(to=recipient, from="help@company.com",
           subject="Ticket ##" & ticketId & " resolved", type="text") {
      writeOutput("Your ticket has been resolved.");
    }
  }
}

// SlackNotifier.cfc — NEW channel: no existing code touched
component implements="INotifier" {
  public void function sendResolved(required numeric ticketId,
                                    required string recipient) {
    // POST to Slack webhook
    cfhttp(method="POST", url="https://hooks.slack.com/services/...",
           result="r") {
      cfhttpparam(type="body",
        value=serializeJSON({text: "Ticket ##" & ticketId & " resolved for " & recipient}));
    }
  }
}
```

`TicketService` depends on `INotifier` — you swap implementations without touching the service.

---

## L — Liskov Substitution Principle

> *Objects of a subclass should be substitutable for objects of the superclass without altering the correctness of the program.*

If code works with the base type, it must work with any subtype too — no surprises.

```cfml
// BaseNotifier.cfc — abstract base
component {
  public void function sendResolved(required numeric ticketId,
                                    required string recipient) {
    throw(type="AbstractMethod", message="Subclasses must implement sendResolved()");
  }
  // Concrete shared behaviour — subclasses inherit this
  public string function formatSubject(required numeric ticketId) {
    return "Ticket ##" & ticketId & " resolved";
  }
}

// EmailNotifier.cfc — valid substitution
component extends="BaseNotifier" {
  public void function sendResolved(required numeric ticketId,
                                    required string recipient) {
    cfmail(to=recipient, from="help@company.com",
           subject=formatSubject(ticketId), type="text") {
      writeOutput("Your ticket has been resolved.");
    }
  }
}
```

**LSP violation to avoid:** a subclass that overrides a method and narrows its behaviour — for example, throwing an exception for inputs the base class accepts, or returning a different type. In CFML, covariance support (since CF 2021) means return types can be refined in subclasses without violating LSP.

---

## I — Interface Segregation Principle

> *No client should be forced to depend on methods it does not use.*

A fat interface with many methods forces every implementer to provide methods they do not need.

```cfml
// BAD — one fat interface
interface {
  public void function sendResolved(required numeric ticketId, required string recipient);
  public void function sendEscalation(required numeric ticketId, required string managerEmail);
  public void function sendWeeklyDigest(required string adminEmail, required array ticketIds);
}

// GOOD — three focused interfaces
interface name="IResolutionNotifier" {
  public void function sendResolved(required numeric ticketId, required string recipient);
}

interface name="IEscalationNotifier" {
  public void function sendEscalation(required numeric ticketId, required string managerEmail);
}

interface name="IDigestNotifier" {
  public void function sendWeeklyDigest(required string adminEmail, required array ticketIds);
}

// EmailNotifier only implements what it actually supports
component implements="IResolutionNotifier,IEscalationNotifier" {
  public void function sendResolved(required numeric ticketId, required string recipient) { /* ... */ }
  public void function sendEscalation(required numeric ticketId, required string managerEmail) { /* ... */ }
}
```

---

## D — Dependency Inversion Principle

> *High-level modules should not depend on low-level modules. Both should depend on abstractions.*

This is where WireBox pays off. Instead of `TicketService` constructing its own dependencies (`new EmailNotifier()`), it declares what it needs and WireBox provides them.

```cfml
// TicketService.cfc — depends on the INotifier abstraction, not EmailNotifier
component {
  // WireBox injects the correct implementation at runtime
  property name="notifier" inject="INotifier";
  property name="repo"     inject="TicketRepository";
  property name="logger"   inject="AuditLogger";

  function resolveTicket(ticketId, userEmail) {
    variables.repo.resolve(ticketId);
    variables.notifier.sendResolved(ticketId, userEmail);
    variables.logger.log("ticket " & ticketId & " resolved");
  }
}
```

In `config/WireBox.cfc` you map the abstraction to the concrete implementation:

```cfml
component extends="coldbox.system.ioc.config.Binder" {
  function configure() {
    // Swap EmailNotifier for SlackNotifier by changing ONE line here
    map("INotifier").to("models.notifiers.EmailNotifier");
  }
}
```

To switch to Slack: change `EmailNotifier` to `SlackNotifier` in one place. `TicketService` is never touched.

---

## Activity — Build the SOLID demo

**Activity — Terminal (dev):** Create the working directory and all four CFCs:

> ⚠️ Run each block separately in the **Terminal (dev)** tab. Wait for the prompt to return after each one.

**Step 1 of 5 — create the directory:**

```bash
sudo mkdir -p /opt/coldfusion2025/cfusion/wwwroot/solid
```

**Step 2 of 5 — create the INotifier interface (OCP + ISP):**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/solid/INotifier.cfc << 'EOF'
<cfinterface>
  <cffunction name="sendResolved" returntype="void" access="public">
    <cfargument name="ticketId"  type="numeric" required="true">
    <cfargument name="recipient" type="string"  required="true">
  </cffunction>
</cfinterface>
EOF
```

**Step 3 of 5 — create TicketNotifier (SRP — notification only):**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/solid/TicketNotifier.cfc << 'EOF'
<cfcomponent implements="INotifier" displayname="TicketNotifier">
  <cffunction name="sendResolved" returntype="void" access="public">
    <cfargument name="ticketId"  type="numeric" required="true">
    <cfargument name="recipient" type="string"  required="true">
    <cfset var msg = "Ticket ##" & arguments.ticketId
                   & " resolved — notified " & arguments.recipient>
    <cflog file="solid_demo" text="#msg#" type="information">
  </cffunction>
</cfcomponent>
EOF
```

**Step 4 of 5 — create the demo page:**

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/solid/demo.cfm << 'EOF'
<cfscript>
  notifier = new TicketNotifier();
  notifier.sendResolved(42, "alice@example.com");
  writeOutput("<p>SOLID demo ran successfully.</p>");
  writeOutput("<p>TicketNotifier.sendResolved() called — check CF logs for output.</p>");
</cfscript>
EOF
```

**Step 5 of 5 — verify it runs:**

```bash
curl -s http://localhost:8500/solid/demo.cfm
```

**Expected output:**

```html
<p>SOLID demo ran successfully.</p>
<p>TicketNotifier.sendResolved() called — check CF logs for output.</p>
```

The task below will turn green automatically once all three files are in place and `demo.cfm` returns HTTP 200 without errors.

::simple-task
---
:tasks: tasks
:name: verify_srp_cfc
---
#active
Runs automatically — verifies `TicketNotifier.cfc` exists in the `solid/` directory.

#completed
TicketNotifier.cfc (SRP) created. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_ocp_interface
---
#active
Runs automatically — verifies `INotifier.cfc` interface exists and contains the `interface` keyword.

#completed
INotifier.cfc (OCP/ISP) created. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_solid_page
---
#active
Runs automatically — verifies `solid/demo.cfm` returns HTTP 200 without a ColdFusion error.

#completed
solid/demo.cfm runs cleanly. ✓
::

---

## Key concepts reference

| Principle | ColdFusion mechanism | Practical tip |
|---|---|---|
| **SRP** | Split fat CFCs into focused components | Start here — easiest win |
| **OCP** | `interface` + multiple `implements` | Add new channels without touching existing code |
| **LSP** | `extends` with covariant return types (CF 2021+) | Never narrow or remove behaviour in a subclass |
| **ISP** | Multiple small `interface` definitions | One interface per client need |
| **DIP** | WireBox `inject` annotation | Map abstractions to concretions in `config/WireBox.cfc` |

---

When all tasks above are green, this lesson — and the course — is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all SOLID tasks pass.

#completed
SOLID principles lesson complete. Course complete — well done! ✓
::

---

## Put It Into Practice

> *"The only way to go fast is to go well."*
> — Robert C. Martin (Uncle Bob)

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.solid-principles-6a4f2c91
---
::
