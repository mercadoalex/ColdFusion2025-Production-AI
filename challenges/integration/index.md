---
kind: challenge

title: 'Consume a REST API and Send an Email Notification'

description: |
  Fetch data from a public REST API using cfhttp, process the results,
  and send an HTML email notification summarising the data.

categories:
  - programming

tagz:
  - coldfusion
  - cfhttp
  - cfmail
  - integration

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  integration_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/integration_challenge.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "integration_challenge.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "integration_challenge.cfm accessible ✓"

  cfhttp_data_fetched:
    machine: cf-dev
    user: laborant
    needs:
      - integration_page
    run: |
      BODY=$(curl -s http://localhost:8500/integration_challenge.cfm)
      if echo "${BODY}" | grep -qi "error\|exception\|cfhttp.*failed"; then
        echo "integration_challenge.cfm is throwing an error"
        exit 1
      fi
      if ! echo "${BODY}" | grep -qiE "[a-zA-Z]{3,}"; then
        echo "Page output appears empty"
        exit 1
      fi
      echo "cfhttp data fetched and displayed ✓"

  email_sent:
    machine: cf-dev
    user: laborant
    needs:
      - cfhttp_data_fetched
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/integration_challenge.cfm"
      if ! grep -qi "cfmail\|cfmailparam" "${FILE}" 2>/dev/null; then
        echo "No cfmail call found in integration_challenge.cfm"
        exit 1
      fi
      echo "cfmail call found ✓"
---

## Consume a REST API and Send an Email Notification

Create `/opt/coldfusion2025/cfusion/wwwroot/integration_challenge.cfm` that:

1. Uses `cfhttp` to fetch data from `https://jsonplaceholder.typicode.com/todos?userId=1`
2. Processes the response — extract the first 5 incomplete todos
3. Displays the todos on screen
4. Sends an HTML `cfmail` notification to `manager@training.dev` listing the todos

::simple-task
---
:tasks: tasks
:name: integration_page
---
#active
Create `integration_challenge.cfm` that returns HTTP 200.

#completed
integration_challenge.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: cfhttp_data_fetched
---
#active
Fetch and display data from the public API using `cfhttp`.

#completed
cfhttp data fetched and displayed. ✓
::

::simple-task
---
:tasks: tasks
:name: email_sent
---
#active
Add a `cfmail` call to send an HTML notification email.

#completed
cfmail call found. ✓
::
