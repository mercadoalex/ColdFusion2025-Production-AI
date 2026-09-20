---
kind: unit

title: What is ColdBox? MVC Architecture & Why Frameworks

name: coldbox-intro-mvc-unit-1
---

## The problem with raw CFML pages

As ColdFusion applications grow, raw `.cfm` pages accumulate business logic, SQL queries, HTML, validation, and session management all in a single file. The result is untestable, inconsistent, and impossible to hand off to another developer.

**MVC** (Model-View-Controller) separates those concerns into three clear layers:

| Layer | Responsibility | ColdBox equivalent |
|---|---|---|
| **Model** | Business logic, data access | CFCs in `models/` |
| **View** | HTML rendering | Templates in `views/` |
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
:summary: "I've heard of FW/1 — how does it compare to ColdBox?"
---
**FW/1 (Framework One)** is a lightweight, convention-over-configuration alternative. It's simpler to learn and well-suited for smaller projects.

**ColdBox** is the full-featured option: built-in DI, testing framework, CBORM, REST extensions, a module system, and a large ecosystem. It is the industry standard for enterprise CFML development in 2025.

For this course we use ColdBox because it is what you will encounter in production projects, and because its patterns (handlers, WireBox, TestBox) align closely with how modern Java frameworks like Spring work.
::

---

## The ColdBox application structure

After scaffolding a ColdBox app, the folder layout looks like this:

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
│   ├── main/
│   │   └── index.cfm        ← View template for Main.index action
│   └── layouts/
│       └── Main.cfm         ← HTML shell (header/footer wrapper)
├── tests/
│   └── specs/               ← TestBox BDD specs
└── modules/                 ← Optional third-party modules
```

---

## The ColdBox request lifecycle

Understanding the lifecycle tells you exactly where to put each type of code:

```
1. HTTP request arrives at the server
2. Application.cfc.onRequestStart() — auth, security checks
3. Router.cfc matches the URL → handler + action name
4. Interceptors run (preHandler, preAction, etc.)
5. Handler action executes — calls models, builds the event data
6. View template renders using data set by the handler
7. Layout wraps the view in the HTML shell
8. Final response sent to the browser
```

Key properties in `Application.cfc`:

```cfml
component extends="coldbox.system.Bootstrap" {
  this.name        = "MyApp";
  COLDBOX_APP_ROOT = getDirectoryFromPath(getMetaData(this).path);
  COLDBOX_APP_KEY  = "MyApp";
  COLDBOX_CONFIG   = "config.Coldbox";

  void function onApplicationStart() {
    super.onApplicationStart();  // hands control to ColdBox
  }
}
```

---

## Install ColdBox

ColdBox runs on the **Lucee** server (port 8888) via CommandBox — not on Adobe ColdFusion (port 8500). All Module 5 activities use the **Lucee (dev)** tab in your browser and the **Terminal (dev)** tab for commands.

**Activity — Terminal (dev):** Navigate to the app directory and install ColdBox via CommandBox:

> ⚠️ **Important:** run these commands one at a time and wait for each to finish before running the next.

**Step 1 of 3 — go to the app directory:**

```bash
cd /home/laborant/app
```

**Step 2 of 3 — install ColdBox from ForgeBox:**

```bash
box install coldbox
```

This downloads ColdBox from [ForgeBox](https://forgebox.io) — the CFML package registry — and installs it into `/home/laborant/app/coldbox/`. It may take 15–30 seconds.

**Expected output:**

```
Installing package coldbox
√ | Installing ColdBox MVC Platform (6.x.x)
√ | ColdBox MVC Platform installed successfully.
```

**Step 3 of 3 — verify the installation:**

```bash
ls /home/laborant/app/coldbox/system/
```

**Expected output** — you should see a list of directories including:

```
Bootstrap.cfc   async/   cache/   core/   events/   ioc/   logging/   web/
```

If `Bootstrap.cfc` is in the list, ColdBox is installed correctly. The task below will turn green automatically.

::simple-task
---
:tasks: tasks
:name: verify_coldbox_installed
---
#active
Runs automatically — verifies `/home/laborant/app/coldbox/system/Bootstrap.cfc` exists.

#completed
ColdBox installed. ✓
::

---

## Key concepts reference

| Concept | ColdBox equivalent |
|---|---|
| Controller | Handler CFC in `handlers/` |
| Action | A public function inside a handler |
| Route | URL pattern → handler + action in `Router.cfc` |
| View | `.cfm` template in `views/<handler>/` |
| Model / Service | CFC in `models/` — injected via WireBox |
| DI container | WireBox — manages object lifecycle (singleton / transient) |
| Testing | TestBox — BDD-style specs in `tests/specs/` |
| Package manager | CommandBox + ForgeBox — `box install <package>` |

---

When the task above is green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once ColdBox is installed.

#completed
ColdBox intro lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Simplicity is the ultimate sophistication."*
> — Leonardo da Vinci

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-intro-c174c787
---
::
