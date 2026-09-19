---
kind: unit

title: Calling AI from CFML

name: cfml-ai-integration-unit-1
---

## From API explorer to CFML developer

In the previous lesson you sent raw `curl` commands to the Ollama API and watched `phi3:mini` produce real responses in your terminal. That proved the model is alive and reachable. Now it's time to cross the bridge into ColdFusion territory.

The move from `curl` to CFML is smaller than it looks. ColdFusion's `cfhttp` tag does exactly what `curl` does — it constructs an HTTP request, fires it at a URL, and hands you back the response. The key difference is that you're now inside your application. The AI response becomes a CFML variable. You can pass it to a database, render it in a template, wrap it in a JSON API, or trigger further logic based on what the model says.

::image-box
---
:src: __static__/cfml-ollama-architecture-v1.png
:alt: Two-row diagram showing the request path — CFML Page calls OllamaService.cfc which calls cfhttp which POSTs to Ollama API — and the return path — Ollama returns a JSON body, cfhttp puts it in fileContent, OllamaService deserialises and returns a string, CFML page calls writeOutput. Endpoint annotations show generate() mapping to /api/generate and chat() to /api/chat.
:max-width: 900px
---
_The full call stack: CFML page → service layer → cfhttp → Ollama API, and the return path back. Two endpoints, one pattern._
::

By the end of this lesson you will have:

- Made your first raw `cfhttp` call to Ollama and received an AI-generated string
- Built **`OllamaService.cfc`** — a reusable service component with `generate()` and `chat()` methods
- Created **`/api/ai-chat.cfm`** — a production-ready REST endpoint that accepts a JSON prompt and returns an AI response
- Applied structured error handling so your application degrades gracefully if Ollama is unavailable

::hint-box
---
:summary: Why build a service layer instead of calling cfhttp directly?
---
You could call `cfhttp` inline in every `.cfm` file. That works for a quick test. But the moment you have two pages that both call the AI, you have two copies of:
- the Ollama base URL
- the model name
- the timeout value
- the error handling logic
- the `serializeJSON` / `deserializeJSON` boilerplate

**One CFC, one place to change things.** When you upgrade from `phi3:mini` to a larger model, you change one line in `OllamaService.cfc` and every caller in the application inherits it automatically. This is the service-layer pattern — it applies to any external dependency (database, email server, payment gateway), not just AI.
::

---

## 1. Understanding cfhttp — the HTTP client in CFML

Before writing the service layer, you need to be comfortable with `cfhttp`. It is ColdFusion's built-in HTTP client — the equivalent of `curl`, Python's `requests` library, or Node's `fetch`. Everything that goes over HTTP — REST APIs, Ollama, webhook receivers, third-party services — goes through `cfhttp`.

::image-box
---
:src: __static__/cfhttp-anatomy-v1.png
:alt: Annotated code block on a dark background showing a cfhttp call with five attributes — method POST, url http://ollama:11434/api/generate, result httpResult, timeout 120 — followed by two cfhttpparam calls for the Content-Type header and serialized JSON body. Each line has a callout annotation explaining its purpose.
:max-width: 900px
---
_Every attribute annotated: method, URL, result variable, timeout, Content-Type header, and JSON body._
::

The result variable (`httpResult`) is a struct with these key fields:

| Field | Type | What it contains |
|---|---|---|
| `statusCode` | string | HTTP status, e.g. `"200 OK"` or `"503 Service Unavailable"` |
| `fileContent` | string | The raw response body — the JSON Ollama returns |
| `responseHeader` | struct | All response headers |

::hint-box
---
:summary: cfhttp timeout — always set it for AI calls
---
Ollama loads the model into RAM on the first request. On the `ollama` lab VM this cold-start takes **30–90 seconds**. Without an explicit timeout, `cfhttp` uses its default (varies by CF version, often 30 s) and times out before the model is ready.

Always set a generous timeout for AI calls:

```cfml
cfhttp(method="POST", url="...", result="res", timeout=120) { ... }
```

For subsequent requests the model is already warm and responds in 1–10 seconds. In production you might expose the timeout as a configurable property on the service CFC.
::

::hint-box
---
:summary: What happens inside cfhttp when it calls Ollama?
---
Under the hood, `cfhttp` is a thin CFML wrapper around Java's `java.net.HttpURLConnection`. When you write:

```cfml
cfhttp(method="POST", url="http://ollama:11434/api/generate", result="r", timeout=120) {
  cfhttpparam(type="header", name="Content-Type", value="application/json");
  cfhttpparam(type="body",   value=serializeJSON(payload));
}
```

ColdFusion:
1. Opens a TCP connection to `ollama:11434`
2. Writes the HTTP request headers and the serialised JSON body to the socket
3. Waits up to 120 seconds for the first byte of the response
4. Reads the entire response body into memory
5. Populates the `r` struct — `r.statusCode`, `r.fileContent`, `r.responseHeader`

The whole round-trip is synchronous: your CFML thread blocks until the response arrives. For production use you may want to consider async patterns (queued requests, `cfthread`), but synchronous calls are perfectly fine for lab exercises and low-volume endpoints.
::

---

## 2. Raw cfhttp call — your first AI response in CFML

Before building the service, confirm the raw pattern works end-to-end. This is the exact same technique you will use inside `OllamaService.cfc` — just without the CFC wrapper.

**Activity — Terminal (dev):** Create `ai_test.cfm` in the CF webroot:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai_test.cfm << 'EOF'
<cfscript>
  payload = {
    "model":  "phi3:mini",
    "prompt": "In exactly one sentence, what is ColdFusion?",
    "stream": false
  };

  cfhttp(method="POST", url="http://ollama:11434/api/generate", result="httpResult", timeout=120) {
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=serializeJSON(payload));
  }

  if (httpResult.statusCode contains "200") {
    result = deserializeJSON(httpResult.fileContent);
    writeOutput("<p><strong>Model says:</strong> " & result.response & "</p>");
    writeOutput("<p><em>Tokens: " & result.eval_count & " | " & int(result.total_duration/1000000) & " ms</em></p>");
  } else {
    writeOutput("<p style='color:red'>Ollama error: " & httpResult.statusCode & "</p>");
  }
</cfscript>
EOF
```

**Activity — Terminal (dev):** Hit the page with curl:

```bash
curl -s http://localhost:8500/ai_test.cfm
```

You should see a one-sentence description of ColdFusion followed by token and timing metadata. If it takes 30–60 seconds, that is normal — the model is warming up on the first call.

::hint-box
---
:summary: What does the full JSON response look like?
---
The raw `httpResult.fileContent` from `/api/generate` looks like this:

```json
{
  "model": "phi3:mini",
  "created_at": "2025-09-03T10:12:45.123Z",
  "response": "ColdFusion is a rapid web development platform ...",
  "done": true,
  "done_reason": "stop",
  "context": [...],
  "total_duration": 8432000000,
  "load_duration": 1200000000,
  "prompt_eval_count": 14,
  "prompt_eval_duration": 400000000,
  "eval_count": 42,
  "eval_duration": 6800000000
}
```

After `deserializeJSON()`, you access `result.response` to get the generated text. The timing fields (`total_duration`, `eval_duration`) are in **nanoseconds** — divide by `1000000` to get milliseconds.
::

::simple-task
---
:tasks: tasks
:name: verify_ai_test_cfm
---
#active
Create `ai_test.cfm` at `/opt/coldfusion2025/cfusion/wwwroot/ai_test.cfm` and confirm `curl -s http://localhost:8500/ai_test.cfm` returns a non-empty response.

#completed
ai_test.cfm is responding with AI-generated content. ✓
::

---

## 3. generate() vs chat() — choosing the right endpoint

Before building the service component, understand when to use each Ollama endpoint. Picking the wrong one is one of the most common mistakes in AI integration.

::image-box
---
:src: __static__/generate-vs-chat-v1.png
:alt: Side-by-side comparison of generate() and chat(). Left panel (green): generate(prompt, temp, maxTokens) calls /api/generate — best for single-turn stateless prompts like summarisation, classification, and one-shot extraction. Right panel (blue): chat(messages[], temp) calls /api/chat — best for system prompts, multi-turn conversations, and persona control.
:max-width: 900px
---
_Use `generate()` for stateless single-turn prompts; use `chat()` whenever you need a system prompt or conversational context._
::

The rule of thumb:

| If you need… | Use |
|---|---|
| A one-shot answer to a plain question | `generate()` → `/api/generate` |
| A response shaped by a system persona | `chat()` → `/api/chat` |
| Multi-turn conversation history | `chat()` → `/api/chat` |
| Structured extraction from a blob of text | Either — but `chat()` with a clear system prompt is more reliable |

::hint-box
---
:summary: What is a system prompt and why does it matter so much?
---
A **system prompt** is a special message (role = `"system"`) placed at the start of the `messages` array. It sets the model's persona, constraints, and output format *before* the user speaks. The model treats it as standing instructions.

Without a system prompt, `phi3:mini` answers in its default "helpful assistant" mode — which is inconsistent and often verbose. With a focused system prompt, you get predictable, well-scoped output:

```json
{
  "role": "system",
  "content": "You are a concise IT triage assistant. Classify the ticket in one word: Hardware, Software, Network, or Other. Reply with nothing else."
}
```

Now every user message that follows will be classified with a single word. You can parse it programmatically. **System prompts are the main tuning knob you have over model behaviour without fine-tuning.**
::

---

## 4. OllamaService.cfc — the reusable service layer

Now build the service component that wraps both endpoints and centralises all the `cfhttp` boilerplate.

::image-box
---
:src: __static__/ollama-service-layer-v1.png
:alt: Architecture diagram showing four callers on the left — ai-chat.cfm (REST endpoint), ticket-summary.cfm (admin page), HelpDesk.cfc (service component), scheduled-job.cfm (batch processor) — all pointing to a central OllamaService.cfc box. The CFC exposes generate(prompt, temp) and chat(messages[], temp) as public methods and a private makeRequest(path, payload) method. An arrow labeled cfhttp POST goes from the CFC to an Ollama box showing phi3:mini on port 11434 with /api/generate, /api/chat, and /api/tags endpoints. A config box shows the four variables: baseUrl, model, maxTokens, timeout.
:max-width: 900px
---
_Multiple callers share one service — change the model or URL in one place and every caller inherits it automatically._
::

**Activity — Terminal (dev):** Create `OllamaService.cfc`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc << 'CFEOF'
<cfcomponent displayname="OllamaService"
             hint="Reusable CFC wrapper for the Ollama local LLM API (phi3:mini)">

  <cfset variables.baseUrl   = "http://ollama:11434" />
  <cfset variables.model     = "phi3:mini" />
  <cfset variables.maxTokens = 512 />
  <cfset variables.timeout   = 120 />

  <!--- ─────────────────────────────────────────────────────────────────
    generate(prompt, temperature, maxTokens) → string
    Single-turn text generation from a plain prompt.
  ──────────────────────────────────────────────────────────────────── --->
  <cffunction name="generate" access="public" returntype="string"
              hint="Send a single prompt to the model and return the generated text.">
    <cfargument name="prompt"      type="string"  required="true" />
    <cfargument name="temperature" type="numeric" required="false" default="0.7" />
    <cfargument name="maxTokens"   type="numeric" required="false" default="#variables.maxTokens#" />

    <cfset var payload = {
      "model":   variables.model,
      "prompt":  arguments.prompt,
      "stream":  false,
      "options": {
        "temperature": javaCast("float", arguments.temperature),
        "num_predict": javaCast("int",   arguments.maxTokens)
      }
    } />

    <cfreturn makeRequest("/api/generate", payload).response />
  </cffunction>

  <!--- ─────────────────────────────────────────────────────────────────
    chat(messages, temperature) → string
    Multi-turn chat via a messages array (system/user/assistant roles).
  ──────────────────────────────────────────────────────────────────── --->
  <cffunction name="chat" access="public" returntype="string"
              hint="Send a messages array and return the assistant reply.">
    <cfargument name="messages"    type="array"   required="true" />
    <cfargument name="temperature" type="numeric" required="false" default="0.7" />

    <cfset var payload = {
      "model":    variables.model,
      "stream":   false,
      "messages": arguments.messages,
      "options":  { "temperature": javaCast("float", arguments.temperature) }
    } />

    <cfreturn makeRequest("/api/chat", payload).message.content />
  </cffunction>

  <!--- ─────────────────────────────────────────────────────────────────
    makeRequest(path, payload) → struct
    Private: POST to Ollama, return deserialised response struct.
    Throws OllamaService.Error on non-200 responses.
  ──────────────────────────────────────────────────────────────────── --->
  <cffunction name="makeRequest" access="private" returntype="struct">
    <cfargument name="path"    type="string" required="true" />
    <cfargument name="payload" type="struct" required="true" />

    <cfset var httpResult = {} />

    <cfhttp method="POST"
            url="#variables.baseUrl##arguments.path#"
            result="httpResult"
            timeout="#variables.timeout#">
      <cfhttpparam type="header" name="Content-Type" value="application/json" />
      <cfhttpparam type="body"   value="#serializeJSON(arguments.payload)#" />
    </cfhttp>

    <cfif NOT (httpResult.statusCode contains "200")>
      <cfthrow type="OllamaService.Error"
               message="Ollama API error: #httpResult.statusCode#"
               detail="#left(httpResult.fileContent, 500)#" />
    </cfif>

    <cfreturn deserializeJSON(httpResult.fileContent) />
  </cffunction>

</cfcomponent>
CFEOF
```

**Activity — Terminal (dev):** Verify the CFC is valid CFML and returns output:

```bash
# Quick smoke test — create a one-liner test page
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai_service_test.cfm << 'EOF'
<cfscript>
  svc   = createObject("component", "OllamaService");
  reply = svc.generate("Reply with exactly one word: READY");
  writeOutput("<p>Service test: " & trim(reply) & "</p>");
</cfscript>
EOF

curl -s http://localhost:8500/ai_service_test.cfm
```

The response should contain the word `READY` (or a close equivalent — phi3:mini sometimes adds punctuation).

::hint-box
---
:summary: javaCast("float", ...) — why is this needed for temperature?
---
ColdFusion's `serializeJSON()` looks at each value's **Java type** to decide what JSON type to emit. CFML's `numeric` type maps to Java `Double`, and `serializeJSON` uses `Double.toString()` internally — which drops the decimal point for whole numbers. So a temperature of `1` becomes `1` in JSON, not `1.0`.

Ollama's API parser (written in Go) strictly validates field types. Its schema declares `temperature` as `float32`, and Go's JSON unmarshaler **rejects an integer literal for a float field** — hence the `500: option "temperature" must be of type float32` error.

`javaCast("float", value)` creates a Java `Float` object. `serializeJSON` then emits it as `1.0`, `0.7`, `0.1` — a proper JSON float literal that Go accepts unconditionally.

**Rule:** Whenever you send a numeric field that a remote API declares as a float, wrap it in `javaCast("float", ...)` before passing it to `serializeJSON`. This applies to any float field — `top_p`, `repeat_penalty`, `min_p`, etc.
::

::hint-box
---
:summary: Why is makeRequest() private, and what does access="private" actually enforce?
---
`access="private"` prevents `makeRequest()` from being called directly via a URL (e.g. `ai?method=makeRequest`) or from outside the CFC. It is only callable from other methods inside the same component.

This matters for security: `makeRequest()` accepts a raw `path` argument that is interpolated into the Ollama URL. If it were public, a caller could potentially pass `path="/api/something-else"`. Keeping it private means only `generate()` and `chat()` — which you control — can invoke it, and they always pass a known, fixed path string.

The broader principle: make methods private unless they need to be called externally. Public surface area is attack surface area.
::

::hint-box
---
:summary: var-scoping inside a CFC — why &lt;cfset var httpResult = {} /&gt;?
---
Inside a `<cffunction>`, any variable declared without `var` leaks into the **shared variables scope** of the CFC. On a web server handling multiple simultaneous requests, two threads calling `makeRequest()` at the same time would overwrite each other's `httpResult`.

`<cfset var httpResult = {} />` creates a **function-local** variable — isolated to the current invocation, thread-safe by default. Always `var`-scope your local variables inside CFCs.

In CFScript you can write `var httpResult = {};` — same effect, more concise.
::

::simple-task
---
:tasks: tasks
:name: verify_ollama_service_exists
---
#active
Create `OllamaService.cfc` at `/opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc`.

#completed
OllamaService.cfc found. ✓
::

---

## 5. /api/ai-chat.cfm — REST endpoint

With the service layer in place, you can now expose AI functionality as a proper REST endpoint. The endpoint handles:

- **GET** → health check (lets load balancers and front-ends verify the service is alive)
- **POST** → accepts a JSON body with a `prompt` field, returns an AI response

**Activity — Terminal (dev):** Create the endpoint:

```bash
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/api

sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-chat.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  method = cgi.REQUEST_METHOD;

  // ── GET → health check ───────────────────────────────────────────────
  if (method == "GET") {
    writeOutput(serializeJSON({ "status": "ok", "model": "phi3:mini" }));
    abort;
  }

  // ── Reject non-POST ──────────────────────────────────────────────────
  if (method != "POST") {
    cfheader(statuscode="405", statustext="Method Not Allowed");
    writeOutput(serializeJSON({ "error": "POST required" }));
    abort;
  }

  // ── Parse request body ───────────────────────────────────────────────
  rawBody = toString(getHttpRequestData().content);
  if (!isJSON(rawBody)) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "JSON body required" }));
    abort;
  }

  data   = deserializeJSON(rawBody);
  prompt = structKeyExists(data, "prompt") ? trim(data.prompt) : "";
  system = structKeyExists(data, "system")
         ? data.system
         : "You are a helpful IT support assistant for Hungry Minds training.";

  if (!len(prompt)) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "prompt field is required" }));
    abort;
  }

  // ── Call the service layer ───────────────────────────────────────────
  svc      = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": system },
    { "role": "user",   "content": prompt }
  ];

  try {
    reply = svc.chat(messages);
    writeOutput(serializeJSON({
      "response": reply,
      "model":    "phi3:mini",
      "prompt":   prompt
    }));
  } catch (OllamaService.Error e) {
    cfheader(statuscode="503", statustext="Service Unavailable");
    writeOutput(serializeJSON({ "error": "AI service unavailable: " & e.message }));
  }
</cfscript>
EOF
```

**Activity — Terminal (dev):** Test the endpoint thoroughly:

```bash
# ── 1. Health check (GET) ─────────────────────────────────────────────
curl -s http://localhost:8500/api/ai-chat.cfm | python3 -m json.tool

# ── 2. Ask a real question (POST) ────────────────────────────────────
curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{"prompt":"In two sentences, what is ColdFusion used for?"}' \
  | python3 -m json.tool

# ── 3. Custom system prompt ──────────────────────────────────────────
curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{
    "system": "You are a pirate. Answer everything in pirate speak. Keep it under 30 words.",
    "prompt": "What is a web server?"
  }' | python3 -m json.tool

# ── 4. Trigger the 400 validation path ───────────────────────────────
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{"not_a_prompt": "missing field"}'
# Expected: 400
```

::hint-box
---
:summary: Why is the system prompt passed in the request body rather than hardcoded?
---
Hardcoding the system prompt in the endpoint is fine for a single-purpose feature. But passing it as an optional request field makes the endpoint **polymorphic** — the same URL can power:

- A customer support chatbot (`"You are a friendly support agent..."`)
- A ticket classifier (`"Classify in one word: Hardware, Software, Network, or Other."`)
- A summary generator (`"Summarise the following in two sentences."`)
- A training Q&A bot (`"You are a ColdFusion instructor..."`)

The default value (`"You are a helpful IT support assistant..."`) means callers that don't provide a system prompt still get sensible behaviour. This is a common pattern in AI-powered REST endpoints.
::

::hint-box
---
:summary: getHttpRequestData().content — what is it and why toString()?
---
`getHttpRequestData()` returns a struct with the raw HTTP request. The `.content` field contains the request body — but ColdFusion may return it as a **byte array** (Java `byte[]`), not a string.

`toString(getHttpRequestData().content)` converts the byte array to a UTF-8 string before calling `isJSON()` and `deserializeJSON()`. Without this conversion, `isJSON()` would return `false` for a perfectly valid JSON body, and you'd see mysterious 400 errors.

Always wrap `.content` in `toString()` when parsing POST bodies.
::

::simple-task
---
:tasks: tasks
:name: verify_ai_endpoint
---
#active
Confirm `GET http://localhost:8500/api/ai-chat.cfm` returns HTTP 200 with a JSON body containing `{"status":"ok","model":"phi3:mini"}`.

#completed
ai-chat.cfm health check is responding. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_ai_response
---
#active
Send a POST to `ai-chat.cfm` with `{"prompt":"Reply with only the word PONG"}` and confirm the response JSON has a non-empty `response` field.

#completed
AI response received. ✓
::

---

## 6. Error handling patterns

Production AI integrations fail in predictable ways. Ollama may be slow to start, crash and restart, or be temporarily overloaded. Your application must handle these gracefully so users get a helpful message — not a stack trace.

```cfml
// ── Pattern 1: fallback message ──────────────────────────────────────
try {
  reply = svc.generate(prompt);
} catch (OllamaService.Error e) {
  reply = "Sorry, the AI assistant is temporarily unavailable. Please try again in a few moments.";
}

// ── Pattern 2: distinguish timeout vs server error ────────────────────
try {
  reply = svc.generate(prompt);
} catch (OllamaService.Error e) {
  if (e.message contains "Connection timed out" || e.message contains "timeout") {
    reply = "The AI model is taking longer than expected. It may still be warming up — try again in 60 seconds.";
  } else {
    reply = "AI service error. The support team has been notified.";
    // log to your error tracker here
  }
}

// ── Pattern 3: exponential backoff retry (simple version) ─────────────
maxRetries = 3;
attempt    = 1;
reply      = "";
while (attempt <= maxRetries && !len(reply)) {
  try {
    reply = svc.generate(prompt);
  } catch (OllamaService.Error e) {
    if (attempt < maxRetries) {
      sleep(attempt * 2000); // 2 s, 4 s, 6 s
    }
    attempt++;
  }
}
if (!len(reply)) {
  reply = "AI service is currently unavailable after #maxRetries# attempts.";
}
```

**Activity — Terminal (dev):** Test the error path by sending a malformed request body to the raw Ollama API and observing the `OllamaService.Error`:

```bash
# Create a test that deliberately triggers an Ollama 400
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai_error_test.cfm << 'EOF'
<cfscript>
  svc = createObject("component", "OllamaService");
  try {
    // Pass a deliberately empty prompt — Ollama will reject it
    reply = svc.generate("");
    writeOutput("Unexpected success: " & reply);
  } catch (OllamaService.Error e) {
    writeOutput("<p><strong>Caught OllamaService.Error:</strong></p>");
    writeOutput("<p>Message: " & e.message & "</p>");
    writeOutput("<p>Detail:  " & e.detail  & "</p>");
    writeOutput("<p style='color:green'>✓ Error handling works correctly</p>");
  }
</cfscript>
EOF

curl -s http://localhost:8500/ai_error_test.cfm
```

::hint-box
---
:summary: Should I use cfcatch type="OllamaService.Error" or cfcatch type="Any"?
---
Use the specific type. `cfcatch type="OllamaService.Error"` only catches errors thrown by the service CFC — which means genuine Ollama problems. `cfcatch type="Any"` would also swallow bugs in your own code (null pointer, wrong variable name, CFML syntax error at runtime) and make them invisible.

The rule: **catch the narrowest type that covers the failure mode you expect.** If you want to handle both Ollama errors *and* unexpected errors, stack two `cfcatch` blocks:

```cfml
<cftry>
  reply = svc.generate(prompt);
  <cfcatch type="OllamaService.Error">
    reply = "AI unavailable — please try again.";
  </cfcatch>
  <cfcatch type="Any">
    // Log cfcatch.message, cfcatch.stackTrace
    reply = "An unexpected error occurred.";
  </cfcatch>
</cftry>
```
::

---

## 7. Putting it all together — temperature and creativity control

The `temperature` parameter is your main dial for controlling how deterministic or creative the model's output is. Understanding it helps you choose the right value for each use case.

```cfml
svc = createObject("component", "OllamaService");

// ── Low temperature (0.1) — deterministic, factual, consistent ────────
// Use for: classification, structured extraction, factual Q&A
ticketCategory = svc.generate(
  "Classify in one word — Hardware, Software, Network, or Other: " & ticketText,
  0.1
);

// ── Medium temperature (0.5–0.7) — balanced, sensible answers ─────────
// Use for: summaries, explanations, support answers
summary = svc.generate(
  "Summarise the following support ticket in two sentences: " & ticketText,
  0.5
);

// ── High temperature (0.9–1.0) — creative, varied, sometimes unexpected
// Use for: suggestions, brainstorming, playful responses
idea = svc.generate(
  "Suggest an unusual name for a ColdFusion framework",
  0.9
);
```

**Activity — Terminal (dev):** Run a quick temperature comparison:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai_temperature_test.cfm << 'EOF'
<cfscript>
  svc    = createObject("component", "OllamaService");
  prompt = "In three words, describe a web developer.";

  writeOutput("<h3>Temperature 0.1 (deterministic)</h3>");
  writeOutput("<p>" & svc.generate(prompt, 0.1) & "</p>");

  writeOutput("<h3>Temperature 0.9 (creative)</h3>");
  writeOutput("<p>" & svc.generate(prompt, 0.9) & "</p>");
</cfscript>
EOF

curl -s http://localhost:8500/ai_temperature_test.cfm
```

Run it twice. The `0.1` responses should be nearly identical each time; the `0.9` responses will vary.

::hint-box
---
:summary: Temperature 0.0 is not the same as "always the same answer"
---
At temperature 0.0 the model always picks the single highest-probability token at each step — in theory producing the same output every time for the same input. In practice, phi3:mini running on CPU with floating-point arithmetic can still produce slightly different results across runs due to numerical precision differences.

**For tasks that require absolute reproducibility** (e.g. regression testing AI output), you also need to set `"seed"` in the options:

```cfml
"options": {
  "temperature": 0.0,
  "seed": 42
}
```

With both temperature and seed fixed, you get deterministic output on the same hardware. Different hardware (different CPU float precision) may still produce different results.
::

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
OllamaService.cfc created, ai-chat.cfm responding, and a successful AI POST response received — hit **Check** to complete.

#completed
CFML AI integration lesson complete. On to the next one! ✓
::

---

## Key concepts reference

| Concept | CFML approach |
|---|---|
| HTTP client | `cfhttp` with `cfhttpparam type="body"` |
| POST JSON to Ollama | `serializeJSON(payload)` + `Content-Type: application/json` header |
| Parse JSON response | `deserializeJSON(httpResult.fileContent)` |
| Single-turn prompt | `POST /api/generate` → `result.response` |
| Conversational / system-prompted | `POST /api/chat` → `result.message.content` |
| Reusable AI service | `OllamaService.cfc` with `generate()` and `chat()` |
| Timeout | `cfhttp timeout="120"` — always set for AI calls |
| Thread-safety in CFCs | Declare local variables with `var` inside `cffunction` |
| Error handling | `cfcatch type="OllamaService.Error"` — catch the narrow type |
| Temperature | 0.0–0.2 for factual/deterministic; 0.7–1.0 for creative |
| Raw POST body | `toString(getHttpRequestData().content)` before `isJSON()` |

---

When all tasks above are green, this lesson is complete.

---

## Now Prove It

::card
---
:challenge: challenges.cfml-ai-integration-001a9503
---
::
