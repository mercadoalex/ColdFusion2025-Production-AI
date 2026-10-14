---
kind: challenge

title: 'Query phi3:mini and Connect it to ColdFusion'

description: |
  Call the Ollama API directly from the terminal, extract the response field,
  connect from cf-dev across the private network, and wire Ollama into
  ColdFusion using the native cfai tag via the OpenAI-compatible /v1 layer.

categories:
  - programming

tagz:
  - coldfusion
  - ollama
  - ai
  - llm

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  generate_to_file:
    machine: ollama
    user: laborant
    run: |
      RESP=$(curl -s --max-time 120 http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Name three industries that use ColdFusion. Be concise.","stream":false}')
      TEXT=$(echo "${RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" 2>/dev/null)
      if [ -z "${TEXT}" ]; then
        echo "phi3:mini did not return a non-empty response"
        exit 1
      fi
      echo "${TEXT}" > /tmp/ollama_challenge.txt
      echo "phi3:mini response written to /tmp/ollama_challenge.txt ✓"
    hintcheck: |
      echo "Send a POST to http://localhost:11434/api/generate with phi3:mini and extract the 'response' field using Python. Save to /tmp/ollama_challenge.txt"

  chat_with_system_prompt:
    machine: ollama
    user: laborant
    needs:
      - generate_to_file
    run: |
      RESP=$(curl -s --max-time 120 http://localhost:11434/api/chat \
        -H "Content-Type: application/json" \
        -d '{
          "model":  "phi3:mini",
          "stream": false,
          "messages": [
            {"role": "system", "content": "You are a helpful assistant. Answer in one sentence only."},
            {"role": "user",   "content": "What port does ColdFusion run on by default?"}
          ]
        }')
      TEXT=$(echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'])" 2>/dev/null)
      if [ -z "${TEXT}" ]; then
        echo "Chat endpoint did not return a non-empty response"
        exit 1
      fi
      echo "${TEXT}" > /tmp/ollama_chat_challenge.txt
      echo "Chat response saved to /tmp/ollama_chat_challenge.txt ✓"
    hintcheck: |
      echo "POST to /api/chat with a 'messages' array containing a system role and a user role. Extract d['message']['content']."

  v1_layer_active:
    machine: ollama
    user: laborant
    needs:
      - chat_with_system_prompt
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/v1/models)
      if [ "${STATUS}" != "200" ]; then
        echo "Ollama /v1 OpenAI-compatible layer not responding (HTTP ${STATUS})"
        exit 1
      fi
      echo "Ollama /v1 layer is active ✓"
    hintcheck: |
      echo "Check http://localhost:11434/v1/models — it should return HTTP 200 with a JSON model list."

  cfai_calls_ollama:
    machine: cf-dev
    user: laborant
    needs:
      - v1_layer_active
    run: |
      FILE=$(find /opt/coldfusion2025/cfusion/wwwroot -name "cfai_challenge.cfm" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "cfai_challenge.cfm not found under CF wwwroot"
        exit 1
      fi
      if ! grep -qi "cfai\|aiChat" "${FILE}"; then
        echo "cfai_challenge.cfm does not use cfai tag or aiChat() function"
        exit 1
      fi
      echo "cfai_challenge.cfm found and uses cfai ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/cfai_challenge.cfm using <cfai> or aiChat() with serviceName='ollama-local'."
---

## Query phi3:mini and Connect it to ColdFusion

Work through four tasks that build on each other — by the end you will have called Ollama at every level of the stack: raw terminal, chat endpoint, OpenAI-compatible layer, and the native ColdFusion `cfai` tag.

### Task 1 — Generate a completion and save it to a file

On the **Terminal (ollama)** tab, send a prompt to `/api/generate`, extract the `response` field, and save it to `/tmp/ollama_challenge.txt`.

```bash
RESP=$(curl -s --max-time 120 http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"Name three industries that use ColdFusion. Be concise.","stream":false}')
echo "${RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" \
  | tee /tmp/ollama_challenge.txt
```

::simple-task
---
:tasks: tasks
:name: generate_to_file
---
#active
Send a prompt to `/api/generate`, extract the `response` field, and save the output to `/tmp/ollama_challenge.txt`.

#completed
phi3:mini responded and output saved to file. ✓
::

---

### Task 2 — Use the chat endpoint with a system prompt

Still on **Terminal (ollama)**, call `/api/chat` with a `system` message that constrains the model to one-sentence answers, then save the response to `/tmp/ollama_chat_challenge.txt`.

```bash
RESP=$(curl -s --max-time 120 http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model":  "phi3:mini",
    "stream": false,
    "messages": [
      {"role": "system", "content": "You are a helpful assistant. Answer in one sentence only."},
      {"role": "user",   "content": "What port does ColdFusion run on by default?"}
    ]
  }')
echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'])" \
  | tee /tmp/ollama_chat_challenge.txt
```

::simple-task
---
:tasks: tasks
:name: chat_with_system_prompt
---
#active
Call `/api/chat` with a system prompt and save the `message.content` response to `/tmp/ollama_chat_challenge.txt`.

#completed
Chat endpoint responded with system-prompt-shaped output. ✓
::

---

### Task 3 — Confirm the OpenAI-compatible layer is active

Still on **Terminal (ollama)**, verify the `/v1` endpoint responds. This is the URL you will use to register Ollama in the CF Administrator.

```bash
curl -s http://localhost:11434/v1/models | python3 -m json.tool
```

You should see a `data` array listing `phi3:mini`. If you get a 404, check `ollama --version` — the `/v1` layer requires 0.1.24+.

::simple-task
---
:tasks: tasks
:name: v1_layer_active
---
#active
Confirm `http://localhost:11434/v1/models` returns HTTP 200.

#completed
Ollama /v1 OpenAI-compatible layer is active. ✓
::

---

### Task 4 — Call Ollama from ColdFusion using cfai

In the CF Administrator on **cf-dev** (`http://localhost:8500/CFIDE/administrator/`), register Ollama as an AI Service:

| Field | Value |
|---|---|
| Name | `ollama-local` |
| Provider type | `OpenAI (Compatible)` |
| Base URL | `http://ollama:11434/v1` |
| API Key | `ollama` |
| Default model | `phi3:mini` |

Then create `/opt/coldfusion2025/cfusion/wwwroot/cfai_challenge.cfm`:

```cfml
<cfai action="chat"
      serviceName="ollama-local"
      prompt="In one sentence, what makes ColdFusion good for rapid development?"
      result="aiResult" />

<cfoutput>
  <p><strong>Model:</strong> #aiResult.model#</p>
  <p><strong>Response:</strong> #aiResult.text#</p>
</cfoutput>
```

Open `http://localhost:8500/cfai_challenge.cfm` in the browser and confirm a response appears.

::simple-task
---
:tasks: tasks
:name: cfai_calls_ollama
---
#active
Create `cfai_challenge.cfm` under the CF wwwroot that uses `<cfai>` or `aiChat()` with `serviceName="ollama-local"`.

#completed
cfai_challenge.cfm found and uses the cfai tag. ✓
::
