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


::image-box
---
:src: __static__/ollama-ai-logo-v2.png
:alt: Ollama logo
:max-width: 320px
---
::


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

::hint-box
---
:summary: The story behind Phi-3 Mini — small model, big ambition
---
Released in April 2024, Phi-3 Mini was designed to prove that a small model fitting on a phone could rival much larger models like GPT-3.5 and Mixtral 8x7B — not by being bigger, but by being trained on far better data.

The key insight, inspired by how children learn language (simple words, high-quality input), was to focus on **data quality over quantity**. Instead of scraping the entire internet, Microsoft curated a carefully filtered dataset of textbooks and synthetic exercises. The result: 3.8B parameters punching well above their weight class.
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


::image-box
---
:src: __static__/ollama-generate-response-v1.png
:alt: Terminal output of curl /api/generate — JSON response from phi3:mini answering "In one sentence, what is ColdFusion?"
:max-width: 860px
---
_The full JSON response from `/api/generate` — the `response` field contains the model's answer._
::


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
Ollama API is up and responding. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_phi3_present
---
#active
In the **Terminal (ollama)** tab, check the output of the previous command and confirm `phi3:mini` appears in the `models` list.

#completed
phi3:mini is loaded and available. ✓
::

---

## 3. The generate endpoint — single prompt

Use `/api/generate` for single-turn prompts where you don't need conversational context.

> ⚠️ **Reference only — do not paste this into the terminal.** The block below shows the request structure. The runnable `curl` command is in the Activity section below.

| Field | Value | Notes |
|---|---|---|
| Method | `POST` | |
| URL | `http://ollama:11434/api/generate` | Use `localhost` when running on the ollama VM itself |
| `model` | `phi3:mini` | Must match a pulled model name |
| `prompt` | your question | Plain string |
| `stream` | `false` | Wait for full response before returning |
| `options.temperature` | `0.7` | 0.0 = deterministic, 1.0 = creative |
| `options.num_predict` | `200` | Max tokens to generate (`-1` = unlimited) |

Key `options`:

| Option | Default | Effect |
|---|---|---|
| `temperature` | 0.8 | Higher = more creative; lower = more deterministic |
| `num_predict` | -1 (unlimited) | Max tokens to generate |
| `top_p` | 0.9 | Nucleus sampling threshold |

**Activity — Terminal (ollama):** Send a real completion request and read the plain-text response.

The purpose of this activity is to confirm that:
1. The `/api/generate` endpoint accepts a prompt
2. `phi3:mini` produces a non-empty, coherent answer
3. You can extract just the `response` field from the JSON using Python

Switch to the **Terminal (ollama)** tab and run:

```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"List three use cases for ColdFusion in enterprise","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

You should see three bullet points (or a numbered list) describing enterprise ColdFusion use cases printed directly to the terminal — no JSON wrapper, just the model's answer.

::hint-box
---
:summary: Why pipe through Python instead of reading raw JSON?
---
The raw response from `/api/generate` contains many fields (`model`, `created_at`, `done`, `eval_count`, etc.) that are noisy when you just want to read the answer. The one-liner `python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"` extracts only the `response` string — the same pattern you'll use in ColdFusion when calling `deserializeJSON()` on the HTTP response body.
::

::simple-task
---
:tasks: tasks
:name: verify_completion
---
#active
In the **Terminal (ollama)** tab, run the curl command above and confirm a non-empty response with ColdFusion use cases is printed to the terminal.

#completed
Completion verified — phi3:mini returned a response. ✓
::

::image-box
---
:src: __static__/ollama-completion-response-v1.png
:alt: Terminal output showing phi3:mini listing three enterprise ColdFusion use cases in plain text
:max-width: 860px
---
_phi3:mini answering a real question — no cloud, no API key, no internet._
::

::hint-box
---
:summary: How is AI inference possible with no internet connection?
---
This feels like magic, but the explanation is straightforward once you understand what a language model actually is.

**A model is just a very large file of numbers.** When you run `ollama pull phi3:mini`, Ollama downloads a ~2.3 GB file called a *model weight checkpoint*. This file encodes everything the model learned during training — billions of mathematical relationships between words, concepts, and patterns — compressed into floating-point numbers.

When you send a prompt, Ollama loads those numbers into RAM and runs a mathematical operation called *inference*: it multiplies your input through layer after layer of the weight matrix, producing a probability distribution over the next token, then the next, until it generates a complete response. **No network call is made.** The entire computation happens on the `ollama` VM's CPU.

Think of it like a calculator: once you have the program, you don't need to phone anyone to do arithmetic. The knowledge is baked into the weights.

**This is why local AI matters:**
- **Air-gapped environments** — hospitals, banks, government systems that cannot send data outside their network
- **Data privacy** — prompts never leave your infrastructure
- **Zero latency variance** — no cloud rate limits, no API outages
- **Cost predictability** — no per-token billing, ever

The trade-off is hardware: phi3:mini needs ~2.3 GB RAM and is noticeably slower than a cloud GPU. For production workloads you'd size the VM appropriately — but the architecture is identical.
::

---

## 4. The chat endpoint — preferred for system prompts

`/api/chat` maintains a conversation via a `messages` array. Each message has a `role` (`system`, `user`, or `assistant`). This is the endpoint you'll use for most real features.

**Activity — Terminal (ollama):** Use the chat endpoint with a system prompt to get a context-aware answer.

The purpose of this activity is to confirm that:
1. The `/api/chat` endpoint accepts a `messages` array with `system` + `user` roles
2. The system prompt shapes the model's persona and response style
3. You can extract the answer from `d['message']['content']`

Run the following in the **Terminal (ollama)** tab:

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

You should see a response similar to this:

```
1. Confirm the printer's status lights are on and no error messages are displayed.

2. Check if the printer is properly connected to the computer or if it's on a network.

3. Ensure the printer has enough paper, ink, and toner.

4. Verify the printer is set as the default printer in Windows settings.

5. Restart both the computer and the printer.

6. Check the network connection if the printer is networked.

7. Update or reinstall printer drivers.

8. Run the built-in Windows printer troubleshooter.

9. Check if the problem persists after reconnecting the printer.

10. If all else fails, consult the printer's manual or support for further instructions.
```

::simple-task
---
:tasks: tasks
:name: verify_chat_endpoint
---
#active
In the **Terminal (ollama)** tab, run the `/api/chat` curl command above and confirm a non-empty IT support response is printed to the terminal.

#completed
Chat endpoint verified — system prompt shaping works. ✓
::

---

## 5. Reach Ollama from cf-dev

**Activity — Terminal (dev):** Verify network connectivity from the ColdFusion VM to the Ollama VM, then send a real prompt across the private network.

The purpose of this activity is to confirm that:
1. The `ollama` hostname resolves correctly from `cf-dev`
2. HTTP traffic on port `11434` is allowed on the private network
3. `cf-dev` can receive a model response — proving the full path works end-to-end

Switch to the **Terminal (dev)** tab and run both commands:

```bash
# Step 1 — verify connectivity (should print 200)
curl -s -o /dev/null -w "%{http_code}\n" http://ollama:11434/api/tags

# Step 2 — send a prompt from cf-dev to the ollama VM
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
In the **Terminal (dev)** tab, run `curl -s -o /dev/null -w "%{http_code}\n" http://ollama:11434/api/tags` — confirm it prints `200`.

#completed
Ollama is reachable from cf-dev. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_cf_dev_prompt
---
#active
In the **Terminal (dev)** tab, send the generate prompt above and confirm a non-empty word is returned from `phi3:mini`.

#completed
cf-dev can send prompts to Ollama across the private network. ✓
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
