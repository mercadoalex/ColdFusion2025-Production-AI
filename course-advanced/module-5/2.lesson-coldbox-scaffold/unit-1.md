---
kind: unit

title: Project Scaffolding with CommandBox

name: coldbox-scaffold-commandbox-unit-1
---

## From zero to running ColdBox app in one command

CommandBox includes a ColdBox app scaffolder that generates a full, working project structure in seconds. This is the recommended starting point for any new ColdBox application.

::image-box
---
:src: __static__/coldbox-scaffold-structure-v1.png
:alt: File tree showing the scaffolded ColdBox app structure — Application.cfc, config/Coldbox.cfc, config/Router.cfc, handlers/Main.cfc, views/main/index.cfm, views/layouts/Main.cfm, models/, tests/specs/, and modules/ directories, with the terminal showing the "box coldbox create app" command that generated them
:max-width: 860px
---
_One command creates the full ColdBox project skeleton — everything you need to start building._
::

---

## 1. Scaffold a new ColdBox application

**Activity:** In the **Terminal (dev)** tab:

```bash
cd /home/laborant/app

# Create a full ColdBox app named "HelpDeskApp"
box coldbox create app \
  name=HelpDeskApp \
  skeleton=AdvancedScript \
  directory=/home/laborant/app \
  --force

# Verify the scaffold
ls -la
```

The `AdvancedScript` skeleton creates a cfscript-first, REST-ready structure. Alternatively:

| Skeleton | Description |
|---|---|
| `Default` | Basic HTML app with tag syntax |
| `AdvancedScript` | Script-first, REST-ready, recommended |
| `rest` | Minimal REST API scaffold |
| `Modern` | ColdBox 7+ conventions |

After scaffolding, inspect the key files:

```bash
cat /home/laborant/app/Application.cfc
cat /home/laborant/app/config/Coldbox.cfc
cat /home/laborant/app/config/Router.cfc
cat /home/laborant/app/handlers/Main.cfc
```

::simple-task
---
:tasks: tasks
:name: verify_coldbox_app
---
#active
Run `box coldbox create app` in `/home/laborant/app` — confirm `Application.cfc` extends ColdBox.

#completed
ColdBox app scaffolded. ✓
::

---

## 2. Start the app with CommandBox

```bash
cd /home/laborant/app

# Start Lucee server (CommandBox manages it)
box server start \
  name=helpdesk \
  port=8888 \
  rewritesEnable=true \
  --debug

# Check the server status
box server status
```

Once started, verify in the **Terminal (dev)** tab:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8888/
# Expected: 200
```

::hint-box
---
:summary: URL rewrites — why are they required?
---
ColdBox uses clean URLs like `/tickets/1` instead of `/index.cfm?event=tickets.show&id=1`. Clean URLs require the web server to rewrite all requests to `index.cfm`. CommandBox automatically configures URL rewrites via its embedded Undertow web server when `rewritesEnable=true`.

Without rewrites enabled, ColdBox routes won't resolve and you'll get 404 errors for any handler action.
::

::simple-task
---
:tasks: tasks
:name: verify_app_running
---
#active
Start the CommandBox server and confirm `http://localhost:8888/` returns HTTP 200.

#completed
App running on port 8888. ✓
::

---

## 3. Understanding the generated files

### Application.cfc — the bootstrap

```cfml
component extends="coldbox.system.Bootstrap" {
  // ColdBox configuration
  COLDBOX_APP_ROOT   = getDirectoryFromPath(getMetaData(this).path);
  COLDBOX_APP_KEY    = "HelpDeskApp";
  COLDBOX_CONFIG     = "config.Coldbox";

  this.name          = "HelpDeskApp";
  this.sessionTimeout = createTimeSpan(0, 0, 30, 0);
}
```

### config/Coldbox.cfc — application settings

```cfml
component {
  function configure() {
    coldbox = {
      appName:          "HelpDeskApp",
      defaultEvent:     "main.index",
      defaultLayout:    "Main.cfm",
      customErrorTemplate: "/views/errors/Error.cfm"
    };

    // Interceptors, module settings, etc.
    interceptors = [];
  }
}
```

### config/Router.cfc — URL routing

```cfml
component extends="coldbox.system.web.routing.RequestRouter" {
  function configure() {
    // Default route — /anything/else → Main.index
    route("/").to("main.index");

    // RESTful resource route — generates all CRUD routes automatically
    // resources(resource="tickets", handler="Tickets");
  }
}
```

---

## 4. The default handler and view

### handlers/Main.cfc

```cfml
component extends="coldbox.system.EventHandler" {
  // Default action
  any function index(event, rc, prc) {
    prc.welcomeMessage = "Welcome to ColdBox!";
    event.setView("main/index");
  }
}
```

### views/main/index.cfm

```cfml
<cfoutput>
  <h1>#prc.welcomeMessage#</h1>
  <p>Your ColdBox app is running.</p>
</cfoutput>
```

::hint-box
---
:summary: What are event, rc, and prc?
---
Every ColdBox handler action receives three arguments:

- `event` — the request context object; set views, redirects, response type
- `rc` — the **request collection** — all URL/form data merged into one struct
- `prc` — the **private request collection** — data set by the handler for the view (not accessible to the user directly)

Think of `rc` as the incoming data (form fields, URL params) and `prc` as the outgoing data (prepared for the view).
::

---

## Key concepts reference

| Concept | Command / File |
|---|---|
| Scaffold app | `box coldbox create app name=MyApp skeleton=AdvancedScript` |
| Start server | `box server start port=8888 rewritesEnable=true` |
| Stop server | `box server stop` |
| App bootstrap | `Application.cfc extends="coldbox.system.Bootstrap"` |
| App settings | `config/Coldbox.cfc` |
| URL routing | `config/Router.cfc` |
| Handler | `handlers/Main.cfc extends="coldbox.system.EventHandler"` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
App is scaffolded and running on port 8888 — hit **Check** to complete the lesson.

#completed
ColdBox scaffold lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.coldbox-scaffold-3a91a6cf
---
::
