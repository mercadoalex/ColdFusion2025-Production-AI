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

ColdBox is the most widely adopted CFML MVC framework. It provides routing, dependency injection (WireBox), view rendering, RESTful conventions, and a testing harness (TestBox) — all in one cohesive packag
::hint-box
---
:summary: The full story of MVC — origin, evolution, and where it lives today
---
**Where it came from**

MVC was invented in **1979** by Trygve Reenskaug at Xerox PARC while designing the Smalltalk-80 programming environment. The idea was simple but radical: a graphical application should not mix "what the data is" with "how it looks" or "how the user interacts with it." Those three things change for different reasons — business logic rarely changes; UI changes constantly — so they should live in separate places.

**The original three roles:**

| Role | Original Smalltalk meaning | Web equivalent |
|---|---|---|
| **Model** | The domain objects and data | Database + business logic CFCs |
| **View** | What the user sees | HTML templates |
| **Controller** | Responds to user input, updates Model and View | Handler that processes HTTP requests |

**How it spread**

In the 1990s, Java's **Struts** framework (2000) brought MVC to server-side web development and became the dominant enterprise pattern for nearly a decade. Ruby on Rails (2004) made it mainstream for rapid web development, and its conventions ("convention over configuration") influenced every framework that came after — including ColdBox.

Today MVC (or a close relative) is the default architecture in:
- **Java** — Spring MVC, Jakarta EE
- **Python** — Django (MTV variant), Flask
- **PHP** — Laravel, Symfony
- **JavaScript** — Angular (component-based MVC)
- **Ruby** — Rails
- **CFML** — ColdBox, FW/1

**The variants that evolved from MVC**

As applications grew more complex, developers adapted MVC:

| Pattern | How it differs | Where you see it |
|---|---|---|
| **MVP** (Model-View-Presenter) | Presenter handles all UI logic; View is completely passive | Android, WinForms |
| **MVVM** (Model-View-ViewModel) | ViewModel exposes data bindings; View reacts automatically | Vue.js, Angular, WPF, SwiftUI |
| **MVA** (Model-View-Adapter) | Adapter decouples Model and View completely | Some desktop frameworks |

**MVVM** is the most important variant to know in 2025. It's what drives every modern JavaScript front-end framework. The key idea: the **ViewModel** is a JavaScript object that the **View** (HTML template) binds to directly — change the data, the UI updates automatically, no manual DOM manipulation. This is how Vue, React (one-way binding), and Angular work.

**MVC in ColdBox terms**

ColdBox implements classic server-side MVC with one pragmatic adjustment: the "Controller" is called a **Handler**, and it handles both routing and action dispatch. The `Router.cfc` maps URLs to handler + action pairs, keeping routing concerns separate from business logic — a clean extension of the original pattern Reenskaug described in 1979.
::

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

::image-box
---
:src: __static__/coldbox-request-lifecycle-v1.png
:alt: Vertical flowchart of the eight-step ColdBox request lifecycle — HTTP Request, Application.cfc onRequestStart, Router.cfc URL matching, Interceptors, Handler Action, View Template, Layout, HTTP Response — each step in a numbered box with a colour-coded left border progressing from blue to green
:max-width: 620px
---
_Every ColdBox request passes through all eight stages in order — knowing this tells you exactly where to put each piece of code._
::

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
