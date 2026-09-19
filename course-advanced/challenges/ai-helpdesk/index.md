---
kind: challenge

title: 'AI-Powered Ticket Classifier'

description: |
  Build an AI endpoint that classifies a help desk ticket into a department
  (IT, HR, Finance, Facilities) based on its title and description.

categories:
  - programming

tagz:
  - coldfusion
  - ai
  - helpdesk
  - database

difficulty: hard

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  classifier_endpoint:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:8500/api/ai-classify.cfm?ticket_id=1")
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-classify.cfm?ticket_id=1 returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-classify.cfm accessible ✓"

  classification_returned:
    machine: cf-dev
    user: laborant
    needs:
      - classifier_endpoint
    run: |
      BODY=$(curl -s "http://localhost:8500/api/ai-classify.cfm?ticket_id=1")
      if ! echo "${BODY}" | python3 -c "
import sys,json
d = json.load(sys.stdin)
assert 'department' in d, 'department field missing'
assert d['department'] in ['IT','HR','Finance','Facilities','Other'], 'unexpected dept value'
" 2>/dev/null; then
        echo "ai-classify.cfm did not return a valid department classification"
        exit 1
      fi
      echo "Department classification returned ✓"

  batch_classify_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - classification_returned
    run: |
      BODY=$(curl -s http://localhost:8500/api/ai-classify-batch.cfm)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d.get('results',[]), list) and len(d['results']) > 0" 2>/dev/null; then
        echo "ai-classify-batch.cfm did not return a non-empty results array"
        exit 1
      fi
      echo "Batch classification returned results ✓"
---

## AI-Powered Ticket Classifier

### Part 1 — `/api/ai-classify.cfm?ticket_id=N`

Build an endpoint that:
1. Fetches the ticket from `hd_tickets` by `ticket_id`
2. Sends a system prompt instructing the model to classify into: IT, HR, Finance, Facilities, or Other
3. Returns JSON: `{"ticket_id":N,"title":"...","department":"IT","confidence":"high"}`

### Part 2 — `/api/ai-classify-batch.cfm`

Build a batch endpoint that:
1. Fetches the first 5 open tickets
2. Classifies each one (you may call Ollama once per ticket)
3. Returns `{"results": [{"ticket_id":1,"department":"IT"}, ...]}`

### Hint — system prompt for classification

```
You are an IT support classifier. Given a ticket title and description,
classify it into exactly one of: IT, HR, Finance, Facilities, Other.
Respond in JSON only: {"department":"IT","confidence":"high"}
```

::simple-task
---
:tasks: tasks
:name: classifier_endpoint
---
#active
Create `/api/ai-classify.cfm` — GET with `?ticket_id=1` returns HTTP 200.

#completed
ai-classify.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: classification_returned
---
#active
Confirm the response JSON contains a `department` field with value IT, HR, Finance, Facilities, or Other.

#completed
Department classification returned. ✓
::

::simple-task
---
:tasks: tasks
:name: batch_classify_endpoint
---
#active
Create `/api/ai-classify-batch.cfm` that returns `{"results": [...]}` with at least one classified ticket.

#completed
Batch classification returned results. ✓
::
