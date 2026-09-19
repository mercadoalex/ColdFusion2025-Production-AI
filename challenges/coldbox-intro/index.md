---
kind: challenge

title: 'Explain the ColdBox MVC Pattern'

description: |
  Install ColdBox and answer questions about the MVC architecture by
  inspecting the scaffolded files and writing a summary page.

categories:
  - programming

tagz:
  - coldfusion
  - coldbox
  - mvc

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  coldbox_present:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/coldbox" ]; then
        echo "ColdBox not installed — run: box install coldbox"
        exit 1
      fi
      echo "ColdBox installed ✓"

  mvc_summary_page:
    machine: cf-dev
    user: laborant
    needs:
      - coldbox_present
    run: |
      FILE="/home/laborant/app/views/main/mvc_summary.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "mvc_summary.cfm not found at views/main/mvc_summary.cfm"
        exit 1
      fi
      if ! grep -qi "model\|view\|controller\|handler\|wirebox" "${FILE}"; then
        echo "mvc_summary.cfm does not mention key MVC concepts"
        exit 1
      fi
      echo "mvc_summary.cfm found with MVC content ✓"

  handler_action_for_summary:
    machine: cf-dev
    user: laborant
    needs:
      - mvc_summary_page
    run: |
      HANDLER="/home/laborant/app/handlers/Main.cfc"
      if ! grep -qi "mvc_summary\|mvcSummary\|mvc-summary" "${HANDLER}" 2>/dev/null; then
        echo "Main.cfc does not have an action that sets the mvc_summary view"
        exit 1
      fi
      echo "Handler action for mvc_summary found ✓"
---

## Explain the ColdBox MVC Pattern

### Requirements

1. Install ColdBox in `/home/laborant/app` using `box install coldbox`

2. Add a `mvcSummary()` action to `handlers/Main.cfc` that sets view `main/mvc_summary`

3. Create `views/main/mvc_summary.cfm` that explains the three MVC layers:
   - What the **Model** is and where it lives in ColdBox
   - What the **View** is and how it receives data from the handler
   - What the **Controller/Handler** is and how it maps to a URL

::simple-task
---
:tasks: tasks
:name: coldbox_present
---
#active
Install ColdBox with `box install coldbox`.

#completed
ColdBox installed. ✓
::

::simple-task
---
:tasks: tasks
:name: mvc_summary_page
---
#active
Create `views/main/mvc_summary.cfm` that mentions model, view, controller/handler, and WireBox.

#completed
mvc_summary.cfm found with MVC content. ✓
::

::simple-task
---
:tasks: tasks
:name: handler_action_for_summary
---
#active
Add a `mvcSummary()` action to `handlers/Main.cfc` that sets the view to `main/mvc_summary`.

#completed
Handler action for mvc_summary found. ✓
::
