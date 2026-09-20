---
kind: unit

title: What is ColdBox? MVC Architecture & Why Frameworks

name: coldbox-intro-mvc-unit-1
---

## The problem with raw CFML pages

As ColdFusion applications grow, raw `.cfm` pages accumulate business logic, SQL queries, HTML, validation, and session management in a single file. The result is untestable, inconsistent, and difficult to hand off to another developer.

**MVC** (Model-View-Controller) separates those concerns:

| Layer | Responsibility | ColdBox equivalent |
|---|---|---|
| **Model** | Business logic, data access | CFCs in `models/` |
| **View** | HTML rendering | Layouts and views in `views/` |
| **Controller** | Request routing, orchestration | Handlers in `handlers/` |

ColdBox is the most widely adopted CFML MVC framework. It provides routing, dependency injection (WireBox), view rendering, RESTful conventions, and a testing harness (TestBox) — all in one cohesive package.

::image-box
---
:src: __static__/coldbox-mvc-overview-v1.png
:alt: MVC diagram showing a browser request entering ColdBox's Router.cfc, which maps the URL to a specific handler and action. The handler calls a model service (injected via WireBox), which accesses the database, and the handler returns data to a view template. The view renders HTML and sends it back to the browser.
:max-width: 900px
---
_ColdBox request lifecycle: URL → Router → Handler → Model → View → Response._
::

---

## When to use ColdBox vs raw CFML

| Scenario | Recommendation |
|---|---|
| Quick one-off script or prototype | Raw CFML `.cfm` is fine |
| Small app (1–5 templates) | Raw CFML is adequate |
| Team project, multiple developers | Use ColdBox |
| Application with tests | Use ColdBox + TestBox |
| REST API with resource conventions | Use ColdBox |
| Long-term maintained application | Use ColdBox |

::hint-box
---
:summary: "I've heard of FW/1 and Lucee-MVC — how do they compare?"
---
**FW/1 (Framework One)** is a lightweight, convention-over-configuration alternative. It's simpler to learn and well-suited for smaller projects.

**ColdBox** is the full-featured option: built-in DI, testing framework, CBORM, REST extensions, a module system, and a large ecosystem. It is the industry standard for enterprise CFML development in 2025.

For this course we use ColdBox because it is what you will encounter in production projects, and because its patterns (handlers, WireBox, TestBox) align with how modern Java frameworks like Spring work.
::

---

## The ColdBox application structure

After scaffolding a ColdBox app, the folder layout is:

```
myapp/
├── Application.cfc          ← Extends coldbox.system.Bootstrap
├── config/
│   ├── Coldbox.cfc          ← App settings, interceptors, modules
│   └── Router.cfc           ← URL routing rules
├── handlers/
│   └── Main.cfc             ← Default handler (controller)
├── models/                  ← Service CFCs and entities
├── views/
│   ├── main/                ← View templates for Main handler
│   │   └── index.cfm
│   └── layouts/
│       └── Main.cfm         ← HTML shell (header/footer)
├── tests/
│   └── specs/               ← TestBox BDD specs
└── modules/                 ← Optional third-party modules
```

**Activity:** In the **Terminal (dev)** tab, install ColdBox into the Lucee app directory:

```bash
cd /home/laborant/app

# Install ColdBox from ForgeBox (CommandBox package manager)
box install coldbox

# Verify installation
ls -la coldbox/
```

::simple-task
---
:tasks: tasks
:name: verify_coldbox_installed
---
#active
Run `box install coldbox` in `/home/laborant/app` — confirm the `coldbox/` directory appears.

#completed
ColdBox installed. ✓
::

---

## The ColdBox request lifecycle

Understanding the request lifecycle helps you know where to put code:

```
1. HTTP request arrives
2. Application.cfc.onRequestStart() — security checks, auth
3. Router.cfc matches URL → handler + action
4. Handler interceptors run (preHandler, etc.)
5. Handler action executes — calls models, sets data
6. View renders with the data set by the handler
7. Layout wraps the view in the page shell
8. Response sent to browser
```

Key lifecycle methods in `Application.cfc`:

```cfml
component extends="coldbox.system.Bootstrap" {
  this.name         = "MyApp";
  COLDBOX_APP_ROOT  = getDirectoryFromPath(getMetaData(this).path);
  COLDBOX_APP_KEY   = "MyApp";
  COLDBOX_CONFIG    = "config.Coldbox";

  void function onApplicationStart() {
    super.onApplicationStart();  // initialise ColdBox
  }
}
```

---

## Key concepts reference

| Concept | ColdBox equivalent |
|---|---|
| Controller | Handler CFC in `handlers/` |
| Action | A public function inside a handler |
| Route | URL pattern → handler + action mapping in `Router.cfc` |
| View | `.cfm` template in `views/<handler>/` |
| Model / Service | CFC in `models/` — injected via WireBox |
| DI container | WireBox — manages singletons and transients |
| Testing | TestBox — BDD-style specs in `tests/specs/` |

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
ColdBox intro lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-intro-c174c787
---
::
