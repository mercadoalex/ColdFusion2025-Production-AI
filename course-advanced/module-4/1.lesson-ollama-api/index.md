---
kind: lesson

title: Introduction to Ollama and Local LLMs
description: |
  Learn how to run large language models locally using Ollama. Explore the
  Ollama REST API, generate text completions, and understand how to integrate
  a local AI node into a multi-VM ColdFusion environment.

name: intro-ollama-local-llms
slug: intro-ollama-local-llms

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- ollama
- llm

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_ollama_running:
    machine: ollama
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags)
      if [ "${STATUS}" != "200" ]; then
        echo "Ollama API not responding (HTTP ${STATUS}). Is ollama.service running?"
        exit 1
      fi
      echo "Ollama API is up ✓"

  verify_phi3_present:
    machine: ollama
    user: laborant
    needs:
      - verify_ollama_running
    run: |
      MODELS=$(curl -s http://localhost:11434/api/tags)
      if ! echo "${MODELS}" | python3 -c "import sys,json; d=json.load(sys.stdin); names=[m['name'] for m in d['models']]; assert any('phi3' in n for n in names)" 2>/dev/null; then
        echo "phi3:mini not found in Ollama model list"
        exit 1
      fi
      echo "phi3:mini is available ✓"

  verify_completion:
    machine: ollama
    user: laborant
    needs:
      - verify_phi3_present
    run: |
      RESPONSE=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Reply with only the word PONG","stream":false}')
      if ! echo "${RESPONSE}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "Ollama completion returned empty response"
        exit 1
      fi
      echo "Completion works ✓"

  verify_reachable_from_dev:
    machine: cf-dev
    user: laborant
    needs:
      - verify_completion
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://ollama:11434/api/tags)
      if [ "${STATUS}" != "200" ]; then
        echo "Cannot reach Ollama from cf-dev at http://ollama:11434 (HTTP ${STATUS})"
        exit 1
      fi
      echo "Ollama is reachable from cf-dev ✓"
---

## Overview

Your environment has three VMs on a shared private network:

| VM | Role | Key port |
|---|---|---|
| `cf-dev` | Adobe ColdFusion 2025 dev server | 8500 |
| `cf-prod` | Adobe ColdFusion 2025 prod server | 8500 |
| `ollama` | Local LLM node (phi3:mini) | 11434 |

All three VMs can reach each other by hostname. From `cf-dev` you call Ollama at
`http://ollama:11434` — no API key, no cloud dependency.

---

## 1. What is Ollama?

Ollama is an open-source tool that serves large language models (LLMs) via a
simple HTTP API. It handles model downloading, GPU/CPU inference, and request
queuing. The API is intentionally similar to OpenAI's, which makes it easy to
swap in local models.

The model running in your environment is **phi3:mini** — Microsoft's 3.8B
parameter model, optimised for instruction following and reasoning. It runs
entirely on CPU in ~2.3 GB of RAM.

---

## 2. Explore the Ollama API

Open the **Terminal (ollama)** tab and try these commands:

```bash
# List available models
curl -s http://localhost:11434/api/tags | python3 -m json.tool

# Check server info
curl -s http://localhost:11434/api/version

# Generate a completion (streaming disabled for clean output)
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "In one sentence, what is ColdFusion?",
    "stream": false
  }' | python3 -m json.tool
```

The key fields in the response:
- `response` — the generated text
- `done` — `true` when generation is complete
- `eval_count` — number of tokens generated
- `total_duration` — nanoseconds taken

---

## 3. The generate endpoint

```
POST http://ollama:11434/api/generate
Content-Type: application/json
```

```json
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
| Field | Default | Effect |
|---|---|---|
| `temperature` | 0.8 | Higher = more creative; lower = more deterministic |
| `num_predict` | -1 (unlimited) | Max tokens to generate |
| `top_p` | 0.9 | Nucleus sampling cutoff |

---

## 4. The chat endpoint (preferred for conversation)

```bash
curl -s http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "stream": false,
    "messages": [
      {"role": "system",  "content": "You are a helpful IT support assistant."},
      {"role": "user",    "content": "My printer is not responding. What should I check first?"}
    ]
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'])"
```

The `chat` endpoint maintains conversational context via the `messages` array —
each `role` is `system`, `user`, or `assistant`.

---

## 5. Reach Ollama from cf-dev

Switch to the **Terminal (dev)** tab:

```bash
# Ollama is reachable by VM hostname on the shared network
curl -s http://ollama:11434/api/tags | python3 -m json.tool

# Quick completion from the ColdFusion VM
curl -s http://ollama:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"Say hello in Spanish","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

This is the URL you will use in ColdFusion: `http://ollama:11434`.

---

## Key takeaways

| Concept | Detail |
|---|---|
| Model | `phi3:mini` — 3.8B params, runs on CPU |
| List models | `GET /api/tags` |
| Generate text | `POST /api/generate` with `"stream": false` |
| Chat | `POST /api/chat` with `messages` array |
| URL from cf-dev | `http://ollama:11434` |
| No auth needed | Local network, no API key required |

