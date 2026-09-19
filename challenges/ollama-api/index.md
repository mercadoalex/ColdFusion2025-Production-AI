---
kind: challenge

title: 'Explore the Ollama API and Query phi3:mini'

description: |
  Verify that phi3:mini is running on the ollama VM, send completions and
  chat requests, and confirm the model is reachable from cf-dev.

categories:
  - programming

tagz:
  - coldfusion
  - ollama
  - ai
  - llm

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  ollama_responds:
    machine: ollama
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags)
      if [ "${STATUS}" != "200" ]; then
        echo "Ollama API not responding on port 11434"
        exit 1
      fi
      echo "Ollama API is up ✓"

  phi3_generates:
    machine: ollama
    user: laborant
    needs:
      - ollama_responds
    run: |
      RESP=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Reply with the single word: READY","stream":false}')
      if ! echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','').strip()) > 0" 2>/dev/null; then
        echo "phi3:mini did not return a response"
        exit 1
      fi
      echo "phi3:mini generated a response ✓"

  reachable_from_cf_dev:
    machine: cf-dev
    user: laborant
    needs:
      - phi3_generates
    run: |
      RESP=$(curl -s http://ollama:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Reply with the single word: CONNECTED","stream":false}')
      if ! echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','').strip()) > 0" 2>/dev/null; then
        echo "Cannot generate from cf-dev via http://ollama:11434"
        exit 1
      fi
      echo "phi3:mini reachable from cf-dev ✓"
---

## Explore the Ollama API and Query phi3:mini

### Tasks

1. **Verify Ollama is running** on the `ollama` VM — check `http://localhost:11434/api/tags`

2. **Generate a completion** — send a prompt to `/api/generate` with `"stream": false` and confirm a non-empty response

3. **Verify reachability from cf-dev** — from the **Terminal (dev)** tab, call `http://ollama:11434/api/generate`

### Useful commands

```bash
# On Terminal (ollama):
curl -s http://localhost:11434/api/tags | python3 -m json.tool
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"What is 2+2?","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"

# On Terminal (dev):
curl -s http://ollama:11434/api/tags
```

::simple-task
---
:tasks: tasks
:name: ollama_responds
---
#active
Confirm Ollama API is up on the ollama VM.

#completed
Ollama API is up. ✓
::

::simple-task
---
:tasks: tasks
:name: phi3_generates
---
#active
Generate a completion from phi3:mini and receive a non-empty response.

#completed
phi3:mini generated a response. ✓
::

::simple-task
---
:tasks: tasks
:name: reachable_from_cf_dev
---
#active
Call `http://ollama:11434/api/generate` from the cf-dev Terminal tab.

#completed
phi3:mini reachable from cf-dev. ✓
::
