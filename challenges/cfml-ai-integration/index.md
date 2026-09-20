---
kind: challenge

title: 'Build an AI Text Summariser in ColdFusion'

name: cfml-ai-integration-c3d196db
slug: cfml-ai-integration-c3d196db

description: |
  Create a reusable OllamaService.cfc and a REST endpoint that accepts
  a block of text and returns a concise AI-generated summary.

categories:
  - programming

tagz:
  - coldfusion
  - cfml
  - ai
  - ollama

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  ollama_service_exists:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc ]; then
        echo "OllamaService.cfc not found"
        exit 1
      fi
      if ! grep -qi "function generate\|function chat" \
           /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc; then
        echo "OllamaService.cfc does not have generate() or chat() methods"
        exit 1
      fi
      echo "OllamaService.cfc with methods found ✓"

  summariser_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - ollama_service_exists
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/api/summarise.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/summarise.cfm returned HTTP ${STATUS}"
        exit 1
      fi
      echo "summarise.cfm accessible ✓"

  summarise_returns_summary:
    machine: cf-dev
    user: laborant
    needs:
      - summariser_endpoint
    run: |
      BODY=$(curl -s -X POST http://localhost:8500/api/summarise.cfm \
              -H "Content-Type: application/json" \
              -d '{"text":"ColdFusion is a rapid web application development platform that allows developers to build database-driven web applications quickly. It uses CFML, a tag and script based language that compiles to Java bytecode and runs on the JVM."}')
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('summary','').strip()) > 10" 2>/dev/null; then
        echo "summarise.cfm did not return a non-empty summary field"
        exit 1
      fi
      echo "Summariser returned a summary ✓"
---

## Build an AI Text Summariser

### Requirements

1. **OllamaService.cfc** at `/opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc`
   - Must have `generate()` or `chat()` methods that call `http://ollama:11434`

2. **`/api/summarise.cfm`** REST endpoint:
   - `GET` → health check, returns `{"status":"ok"}`
   - `POST` with `{"text":"..."}` → calls OllamaService, returns `{"summary":"..."}`

### Example request

```bash
curl -s -X POST http://localhost:8500/api/summarise.cfm \
  -H "Content-Type: application/json" \
  -d '{"text":"Your long text here..."}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['summary'])"
```

::simple-task
---
:tasks: tasks
:name: ollama_service_exists
---
#active
Create `OllamaService.cfc` with `generate()` or `chat()` methods.

#completed
OllamaService.cfc with methods found. ✓
::

::simple-task
---
:tasks: tasks
:name: summariser_endpoint
---
#active
Create `/api/summarise.cfm` — GET returns HTTP 200.

#completed
summarise.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: summarise_returns_summary
---
#active
POST with a `text` field — response JSON must have a non-empty `summary` field.

#completed
Summariser returned a summary. ✓
::
