---
kind: unit

title: Calling AI from CFML

name: cfml-ai-integration-unit-1
---

## The CFML → Ollama bridge

ColdFusion's `<cfhttp>` tag can call any HTTP API — including Ollama. By wrapping those calls in a CFC service layer, you get clean, reusable AI functionality that any page or handler in your application can call.

::image-box
---
:src: __static__/cfml-ollama-architecture-v1.png
:alt: Request flow diagram — a CFML page on cf-dev calls OllamaService.cfc generate() or chat(), which uses cfhttp to POST to http://ollama:11434/api/generate or /api/chat, receives the JSON response, deserialises it, and returns the text string back to the calling page
:max-width: 860px
---
_The AI call stack: CFML page → OllamaService.cfc → cfhttp → Ollama API → JSON response → text string._
::

By the end of this lesson you will have built:

- `OllamaService.cfc` — a reusable CFC with `generate()` and `chat()` methods
- `/api/ai-chat.cfm` — a REST endpoint that accepts a JSON prompt and returns an AI response

---

## 1. Calling Ollama with cfhttp

Before building the service layer, confirm the raw `cfhttp` call works.

**Activity:** In the **Terminal (dev)** tab, create `ai_test.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai_test.cfm << 'EOF'
<cfscript>
  payload = {
    "model":  "phi3:mini",
    "prompt": "In exactly one sentence, what is ColdFusion?",
    "stream": false
  };

  cfhttp(
    method = "POST",
    url    = "http://ollama:11434/api/generate",
    result = "httpResult"
  ) {
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body",   value=serializeJSON(payload));
  }

  if (httpResult.statusCode contains "200") {
    result = deserializeJSON(httpResult.fileContent);
    writeOutput(result.response);
  } else {
    writeOutput("Ollama error: " & httpResult.statusCode);
  }
</cfscript>
EOF
```

```bash
curl -s http://localhost:8500/ai_test.cfm
```

::hint-box
---
:summary: cfhttp timeout — always set it for AI calls
---
Ollama loads the model into RAM on the first request (~10–30 seconds on cold start). Set a generous timeout to avoid cfhttp failing before the model is ready:

```cfml
cfhttp(method="POST", url="...", result="res", timeout=120) { ... }
```

For subsequent requests the model is already in memory and responds in 1–10 seconds.
::

---

## 2. OllamaService.cfc — the reusable service layer

**Activity:** Create the service component:

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
        "temperature": arguments.temperature,
        "num_predict": arguments.maxTokens
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
      "options":  { "temperature": arguments.temperature }
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

## 3. /api/ai-chat.cfm — REST endpoint

**Activity:** Create the AI chat endpoint:

```bash
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/api

sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-chat.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  method = cgi.REQUEST_METHOD;

  // GET → health check
  if (method == "GET") {
    writeOutput(serializeJSON({ "status": "ok", "model": "phi3:mini" }));
    abort;
  }

  if (method != "POST") {
    cfheader(statuscode="405", statustext="Method Not Allowed");
    writeOutput(serializeJSON({ "error": "POST required" }));
    abort;
  }

  // Parse request body
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

  svc = createObject("component", "OllamaService");
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

**Activity:** Test the endpoint:

```bash
# Health check (GET)
curl -s http://localhost:8500/api/ai-chat.cfm | python3 -m json.tool

# Ask a question (POST)
curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{"prompt":"In two sentences, what is ColdFusion used for?"}' \
  | python3 -m json.tool
```

::simple-task
---
:tasks: tasks
:name: verify_ai_endpoint
---
#active
Confirm `GET http://localhost:8500/api/ai-chat.cfm` returns HTTP 200 with a JSON body.

#completed
ai-chat.cfm is accessible. ✓
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

## 4. Error handling patterns

```cfml
// Pattern 1: catch OllamaService errors and return a fallback
try {
  reply = svc.generate(prompt);
} catch (OllamaService.Error e) {
  reply = "Sorry, the AI assistant is temporarily unavailable. Please try again.";
}

// Pattern 2: retry with exponential backoff (simple version)
maxRetries = 3;
attempt    = 1;
reply      = "";
while (attempt <= maxRetries && !len(reply)) {
  try {
    reply = svc.generate(prompt);
  } catch (OllamaService.Error e) {
    if (attempt < maxRetries) { sleep(attempt * 2000); }
    attempt++;
  }
}
```

---

## Key concepts reference

| Concept | CFML approach |
|---|---|
| HTTP client | `<cfhttp>` with `cfhttpparam type="body"` |
| POST JSON | `serializeJSON()` + `Content-Type: application/json` header |
| Parse JSON response | `deserializeJSON(httpResult.fileContent)` |
| Reusable AI service | `OllamaService.cfc` with `generate()` and `chat()` |
| Timeout | `<cfhttp timeout="120">` for model cold start |
| Error handling | `<cftry><cfcatch type="OllamaService.Error">` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
OllamaService.cfc, ai-chat.cfm, and a successful AI response — hit **Check** to complete.

#completed
CFML AI integration lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.cfml-ai-integration-001a9503
---
::
