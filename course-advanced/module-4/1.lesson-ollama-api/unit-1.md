---
kind: unit

title: Introduction to Ollama and Local LLMs

name: intro-ollama-local-llms-unit-1
---

## Running AI without the cloud

Most AI tutorials require an OpenAI API key, internet access, and per-token billing. This course takes a different approach: **phi3:mini** runs entirely on the `ollama` VM in your lab — no API keys, no cloud calls, no cost. The same pattern works in air-gapped environments and on-premise enterprise deployments.

::image-box
---
:src: __static__/ollama-multi-vm-network-v1.png
:alt: Three-VM network diagram — cf-dev (left) and cf-prod (centre) and ollama (right) on a shared private network. Arrows from cf-dev and cf-prod point to ollama:11434 labelled "HTTP API". The ollama VM shows the phi3:mini model (3.8B params) running in CPU inference mode. A label at the bottom reads "no internet required — fully local"
:max-width: 900px
---
_Your three-VM lab: cf-dev and cf-prod call the Ollama API at http://ollama:11434 — all traffic stays on the private network._
::

| VM | Service | Port |
|---|---|---|
| `cf-dev` | ColdFusion 2025, Lucee 7, VS Code | 8500, 8888 |
| `cf-prod` | ColdFusion 2025 | 8500 |
| `ollama` | Ollama + phi3:mini | 11434 |

---

## 1. What is Ollama?

Ollama is an open-source runtime that serves large language models (LLMs) through a simple HTTP API. It handles model loading, CPU/GPU inference, and request queuing. The API design closely mirrors OpenAI's, so if you've used ChatGPT's API, the patterns will feel familiar.

**phi3:mini** is Microsoft's 3.8-billion-parameter instruction-following model. At ~2.3 GB it fits in RAM, runs on CPU without a GPU, and is well-suited for:

- Text classification and triage
- Summarisation of short documents
- Structured JSON extraction from unstructured text
- Question answering with a system prompt

::hint-box
---
:summary: Why phi3:mini and not a bigger model?
---
Bigger models (Llama 3 70B, Mistral 7B+) produce better output but need 4–40 GB of RAM and are slow on CPU. The `ollama` lab VM has 4 GB RAM, which is tight for phi3:mini but works. In production, you'd choose the model based on quality vs resource trade-off — phi3:mini is a practical starting point that runs on standard hardware.
::

---

## 2. Explore the Ollama API

**Activity:** Open the **Terminal (ollama)** tab and explore the API:

```bash
# List available models
curl -s http://localhost:11434/api/tags | python3 -m json.tool

# Check the server version
curl -s http://localhost:11434/api/version

# Generate a single completion (non-streaming — waits for full response)
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model":  "phi3:mini",
    "prompt": "In one sentence, what is ColdFusion?",
    "stream": false
  }' | python3 -m json.tool
```

The key response fields:

| Field | Type | Meaning |
|---|---|---|
| `response` | string | The generated text |
| `done` | boolean | `true` when generation is complete |
| `eval_count` | integer | Number of tokens generated |
| `total_duration` | integer | Total time in nanoseconds |

::simple-task
---
:tasks: tasks
:name: verify_ollama_running
---
#active
In the **Terminal (ollama)** tab, run `curl -s http://localhost:11434/api/tags` and confirm it returns HTTP 200.

#completed
Ollama API is up. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_phi3_present
---
#active
Confirm `phi3:mini` appears in the model list returned by `/api/tags`.

#completed
phi3:mini is available. ✓
::

---

## 3. The generate endpoint — single prompt

Use `/api/generate` for single-turn prompts where you don't need conversational context:

```json
POST http://ollama:11434/api/generate
Content-Type: application/json

{
  "model":  "phi3:mini",
  "prompt": "Your question or instruction here",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "num_predict": 200
  }
}
```

Key `options`:

| Option | Default | Effect |
|---|---|---|
| `temperature` | 0.8 | Higher = more creative; lower = more deterministic |
| `num_predict` | -1 (unlimited) | Max tokens to generate |
| `top_p` | 0.9 | Nucleus sampling threshold |

**Activity:** Test a completion:

```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"List three use cases for ColdFusion in enterprise","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

::simple-task
---
:tasks: tasks
:name: verify_completion
---
#active
Run a completion request to Ollama from the **Terminal (ollama)** tab — confirm a non-empty response is returned.

#completed
Completion works. ✓
::

---

## 4. The chat endpoint — preferred for system prompts

`/api/chat` maintains a conversation via a `messages` array. Each message has a `role` (`system`, `user`, or `assistant`). This is the endpoint you'll use for most real features.

```bash
curl -s http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model":  "phi3:mini",
    "stream": false,
    "messages": [
      {
        "role":    "system",
        "content": "You are a helpful IT support assistant. Keep answers brief and actionable."
      },
      {
        "role":    "user",
        "content": "My printer shows offline in Windows but is physically on. What should I check?"
      }
    ]
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'])"
```

The `system` message sets the assistant's persona and constraints — always include one for consistent, predictable output.

---

## 5. Reach Ollama from cf-dev

Switch to the **Terminal (dev)** tab — all ColdFusion code will call Ollama using the hostname `ollama`:

```bash
# Verify connectivity from cf-dev
curl -s -o /dev/null -w "%{http_code}\n" http://ollama:11434/api/tags
# Expected: 200

# Quick test from the ColdFusion VM
curl -s http://ollama:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"Say hello in one word","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

This is the base URL you'll use in all ColdFusion code: **`http://ollama:11434`**.

::simple-task
---
:tasks: tasks
:name: verify_reachable_from_dev
---
#active
From the **Terminal (dev)** tab, run `curl -s -o /dev/null -w "%{http_code}\n" http://ollama:11434/api/tags` and confirm 200.

#completed
Ollama is reachable from cf-dev. ✓
::

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Model | `phi3:mini` — 3.8B params, ~2.3 GB, CPU-compatible |
| List models | `GET /api/tags` |
| Single prompt | `POST /api/generate` — `prompt` field, `stream: false` |
| Conversational | `POST /api/chat` — `messages` array with `role` + `content` |
| URL from cf-dev | `http://ollama:11434` |
| No auth needed | Local network — no API key required |
| Temperature | 0.0–1.0; lower = more deterministic |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
All four Ollama tasks are green — hit **Check** to complete the lesson.

#completed
Ollama API lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.ollama-api-b6f93461
---
::
