---
kind: unit

title: Introduction to Ollama and Local LLMs

name: intro-ollama-local-llms-unit-1
---

## AI and the SDLC — why this module exists

Software development has changed more in the last two years than in the previous ten. AI is no longer a research topic or a specialised toolchain — it is present at every stage of the software development lifecycle, and that presence is accelerating.

**Where AI has already landed in the SDLC:**

| Stage | What AI is doing today |
|---|---|
| **Planning** | Generating user stories, estimating effort, flagging scope risks |
| **Design** | Producing architecture options, writing API specs from requirements |
| **Development** | Code completion, test generation, code review, refactoring suggestions |
| **Testing** | Generating test cases, identifying edge cases, analysing coverage gaps |
| **Deployment** | Writing pipeline YAML, diagnosing failed builds, generating rollback plans |
| **Operations** | Log summarisation, anomaly explanation, incident triage |
| **Documentation** | Writing inline docs, changelogs, runbooks from code |

The question for any development team today is not *"should we use AI?"* — it is *"where in our workflow does AI add the most leverage, and how do we integrate it safely?"*

For ColdFusion teams, the answer increasingly involves AI-powered features inside the application itself: ticket triage, document summarisation, intelligent search, conversational interfaces. That is what this module teaches.

---

### How Adobe is integrating AI into ColdFusion

Adobe did not wait for the ecosystem to catch up. ColdFusion 2025 ships with native AI capabilities built directly into the language — no third-party SDK, no separate service layer required.

**What Adobe shipped in ColdFusion 2025:**

- **`<cfai>` / `aiChat()` tag and function** — send a prompt to a configured AI provider and receive a response in one line of CFML. Supports OpenAI, Azure OpenAI, and any OpenAI-compatible endpoint (which includes Ollama).
- **AI Services in the CF Administrator** — configure AI provider connections (API key, base URL, model) centrally, then reference them by name from code — the same pattern as datasources.
- **`aiImage()`** — generate or analyse images via a configured vision model.
- **`aiEmbedding()`** — produce vector embeddings from text, enabling semantic search and retrieval-augmented generation (RAG) patterns directly in CFML.
- **`aiExtract()`** — structured data extraction from unstructured text, returning typed CFML structs.

::hint-box
---
:summary: Why this module uses cfhttp + Ollama instead of the native cfai tag
---
The native `cfai` tag is the right choice for production Adobe ColdFusion deployments. This module deliberately goes one level lower — calling the Ollama HTTP API directly with `cfhttp` — for two reasons:

1. **Understanding before abstraction.** Knowing what happens under the hood (an HTTP POST to `/api/generate`, a JSON response with a `response` field) makes you a better user of the high-level tag. When something breaks, you'll know exactly where to look.
2. **Portability.** The `cfhttp` pattern works on Lucee as well as Adobe CF, on self-hosted Ollama, on any OpenAI-compatible endpoint, and in air-gapped environments. The same `OllamaService.cfc` you build in this module can be dropped into any CFML codebase.

Once you've completed this module, mapping what you built to the `cfai` tag takes minutes — you'll recognise every parameter.
::

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

**Activity — Terminal (ollama):** Run these three commands to confirm the API is alive, check the version, and get your first AI response.

```bash
# Step 1 — list available models (phi3:mini should appear)
curl -s http://localhost:11434/api/tags | python3 -m json.tool

# Step 2 — check the server version
curl -s http://localhost:11434/api/version | tee /tmp/ollama_version.txt

# Step 3 — generate a single completion (waits for full response — allow up to 2 min)
RESPONSE=$(curl -s --max-time 120 http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"In one sentence, what is ColdFusion?","stream":false}')
echo "$RESPONSE" | python3 -m json.tool
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
Runs automatically — turns green once the Ollama API on port 11434 responds to requests.

#completed
Ollama API is up and responding. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_phi3_present
---
#active
Runs automatically — turns green once phi3:mini appears in the Ollama model list.

#completed
phi3:mini is loaded and available. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_api_explored
---
#active
In the **Terminal (ollama)** tab, run Step 2 above (`curl .../api/version | tee /tmp/ollama_version.txt`). The version response confirms the API is reachable and working.

#completed
Ollama API version confirmed. ✓
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

> ⏱️ **phi3:mini runs on CPU — the first response after a cold start can take 30–90 seconds.** The `--max-time 120` flag tells curl to wait up to 2 minutes before giving up.

```bash
RESPONSE=$(curl -s --max-time 120 http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"List three use cases for ColdFusion in enterprise","stream":false}')
echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" | tee /tmp/ollama_completion.txt
```

**Expected output** — you will see something like this (the exact wording varies, but it should be three coherent enterprise use cases):

```
1. E-commerce Platform: ColdFusion can be utilized to create a robust
e-commerce platform where users can browse products, add them to their
cart, and make secure payments...

2. Customer Relationship Management (CRM) System: ColdFusion can be used
to develop a CRM system that allows businesses to manage their customer
interactions, track sales, and analyze customer data...

3. Content Management System (CMS): ColdFusion can be used to build a CMS
that allows businesses to manage and publish content without the need for
technical expertise...
```

If you see three numbered items printed in plain text — no JSON, no error — the model is working correctly.

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
RESPONSE=$(curl -s --max-time 120 http://localhost:11434/api/chat \
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
  }')
echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'])" | tee /tmp/ollama_chat.txt
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

# Step 2 — send a prompt from cf-dev to the ollama VM (allow up to 2 min for CPU inference)
RESPONSE=$(curl -s --max-time 120 http://ollama:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"Say hello in one word","stream":false}')
echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" | tee /tmp/ollama_from_dev.txt
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

## 6. Using the native cfai tag with Ollama

You have been calling Ollama directly with `cfhttp`. ColdFusion 2025 ships a higher-level abstraction — the `cfai` tag and `aiChat()` function — that wraps exactly the same HTTP calls behind a configured service name. Because Ollama exposes an OpenAI-compatible API at `/v1`, you can point CF's AI Services at the lab VM and use the native tag with no code changes to Ollama itself.

### Step 1 — Verify Ollama's OpenAI-compatible layer is active

Run this on the **Terminal (ollama)** tab:

```bash
curl -s http://localhost:11434/v1/models | python3 -m json.tool
```

You should see a JSON object with a `data` array listing `phi3:mini`. If it returns a 404, your Ollama version predates the `/v1` layer — upgrade with `ollama --version` and check against 0.1.24+.

### Step 2 — Register Ollama as an AI Service in the CF Administrator

Open the CF Administrator on `cf-dev` at **http://localhost:8500/CFIDE/administrator/** and navigate to **AI Services → Add Provider**.

::image-box
---
:src: __static__/cf-admin-ai-service-ollama-v1.png
:alt: ColdFusion 2025 Administrator showing the AI Services configuration screen with a new provider form. Fields filled in: Name "ollama-local", Provider type "OpenAI (Compatible)", Base URL "http://ollama:11434/v1", API Key "ollama", Default model "phi3:mini". A green Test Connection button is visible at the bottom.
:max-width: 860px
---
_Registering Ollama as an OpenAI-compatible AI Service in the CF Administrator. The API key value is arbitrary — Ollama ignores it but CF requires a non-empty string._
::

Fill in the fields:

| Field | Value | Notes |
|---|---|---|
| **Name** | `ollama-local` | This becomes the `serviceName` in your CFML |
| **Provider type** | `OpenAI (Compatible)` | Not "OpenAI" — that hardcodes the OpenAI base URL |
| **Base URL** | `http://ollama:11434/v1` | The `/v1` prefix is required |
| **API Key** | `ollama` | Ollama ignores this — any non-empty string works |
| **Default model** | `phi3:mini` | Must match a pulled model name |

Click **Test Connection** — it should return a green success response.

### Step 3 — Call Ollama with cfai

Once the service is registered, a prompt that previously required 10+ lines of `cfhttp` code becomes one tag:

**Tag syntax:**

```cfml
<cfai action="chat"
      serviceName="ollama-local"
      prompt="In two sentences, what is ColdFusion used for in enterprise?"
      result="aiResult" />

<cfoutput>#aiResult.text#</cfoutput>
```

**Script syntax:**

```cfml
aiResult = aiChat(
    serviceName = "ollama-local",
    prompt      = "In two sentences, what is ColdFusion used for in enterprise?"
);
writeOutput( aiResult.text );
```

The `aiResult` struct contains:

| Key | Type | Content |
|---|---|---|
| `text` | string | The model's response |
| `model` | string | Model name used (`phi3:mini`) |
| `usage.promptTokens` | integer | Tokens consumed by the prompt |
| `usage.completionTokens` | integer | Tokens in the response |

::hint-box
---
:summary: cfai vs cfhttp — when to use which
---
| | `cfai` / `aiChat()` | `cfhttp` to Ollama |
|---|---|---|
| **Requires** | Adobe CF 2025+ | Any CFML engine (Lucee, CF 2018+) |
| **Config location** | CF Administrator | Code / environment variables |
| **Switching providers** | Change `serviceName` | Change base URL string |
| **Access to raw response** | Limited | Full JSON — every field |
| **Best for** | Production CF 2025 apps | Portability, Lucee, custom endpoints |

Use `cfai` when you are building on Adobe CF 2025 and want the simplest possible integration. Use `cfhttp` when you need portability, raw response access, or are running on Lucee.
::

::image-box
---
:src: __static__/cfai-tag-output-ollama-v1.png
:alt: ColdFusion browser output showing the result of a cfai chat call — the aiResult.text field printed to the page containing phi3:mini's two-sentence answer about ColdFusion enterprise use cases
:max-width: 860px
---
_`cfai` output in the browser — same phi3:mini response, one tag instead of ten lines._
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
| OpenAI-compatible layer | `http://ollama:11434/v1` — required for `cfai` |
| No auth needed | Local network — any non-empty string works as API key |
| Temperature | 0.0–1.0; lower = more deterministic |
| Native CF tag | `cfai action="chat" serviceName="ollama-local"` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all four Ollama tasks above are verified.

#completed
Ollama API lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"The question is not whether machines can think. The question is whether men can."*
> — B.F. Skinner

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.ollama-api-b6f93461
---
::
