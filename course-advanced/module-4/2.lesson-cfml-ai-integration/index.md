---
kind: lesson

title: Calling AI from CFML
description: |
  Use ColdFusion's cfhttp tag to call the Ollama API from CFML code.
  Build a reusable OllamaService.cfc, handle streaming vs non-streaming
  responses, and wire up a working AI chat endpoint backed by phi3:mini.

name: cfml-ai-integration
slug: cfml-ai-integration

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- ollama
- cfhttp

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_ollama_service_exists:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc ]; then
        echo "OllamaService.cfc not found at /opt/coldfusion2025/cfusion/wwwroot/"
        exit 1
      fi
      echo "OllamaService.cfc found ✓"

  verify_ai_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ollama_service_exists
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/api/ai-chat.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-chat.cfm returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-chat.cfm is accessible ✓"

  verify_ai_response:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_endpoint
    run: |
      BODY=$(curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
              -H "Content-Type: application/json" \
              -d '{"prompt":"Reply with only the word PONG"}')
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "ai-chat.cfm POST did not return a non-empty response field"
        exit 1
      fi
      echo "AI response received ✓"
---

## Overview

ColdFusion's `<cfhttp>` tag makes HTTP calls to any API — including Ollama.
By wrapping Ollama calls in a CFC, you get a clean service layer that can be
reused from any lesson, challenge, or application page.

By the end of this lesson you will have:
- `OllamaService.cfc` — a reusable CFC for text generation and chat
- `/api/ai-chat.cfm` — a REST endpoint that proxies prompts to Ollama

---

## 1. Calling Ollama with cfhttp

`<cfhttp>` is ColdFusion's built-in HTTP client. It supports all verbs,
custom headers, and JSON bodies.

```cfml
<cfscript>
  // Build the request body
  payload = {
    "model":  "phi3:mini",
    "prompt": "What is ColdFusion used for?",
    "stream": false
  };

  // POST to Ollama (running on the ollama VM, port 11434)
  cfhttp(
    method  = "POST",
    url     = "http://ollama:11434/api/generate",
    result  = "httpResult"
  ) {
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body",   value=serializeJSON(payload));
  }

  // Parse and output the response
  if (httpResult.statusCode contains "200") {
    result = deserializeJSON(httpResult.fileContent);
    writeOutput(result.response);
  } else {
    writeOutput("Ollama error: " & httpResult.statusCode);
  }
</cfscript>
```

Try it in the **Terminal (dev)** tab:
```bash
curl -s http://localhost:8500/api/ai-chat.cfm \
  -X POST -H "Content-Type: application/json" \
  -d '{"prompt":"What year was ColdFusion released?"}' \
  | python3 -m json.tool
```

---

## 2. OllamaService.cfc — reusable service component

Create `/opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc`:

```cfml
<cfcomponent displayname="OllamaService" hint="CFC wrapper for the Ollama local LLM API">

  <cfset variables.baseUrl   = "http://ollama:11434" />
  <cfset variables.model     = "phi3:mini" />
  <cfset variables.maxTokens = 512 />

  <!--- ── generate: single prompt → text ─────────────────────────────── --->
  <cffunction name="generate" access="public" returntype="string"
    hint="Send a single prompt and return the generated text.">

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

    <cfset var result = makeRequest("/api/generate", payload) />
    <cfreturn result.response />
  </cffunction>

  <!--- ── chat: messages array → assistant reply ──────────────────────── --->
  <cffunction name="chat" access="public" returntype="string"
    hint="Send a messages array (system/user/assistant) and return the reply.">

    <cfargument name="messages"    type="array"   required="true" />
    <cfargument name="temperature" type="numeric" required="false" default="0.7" />

    <cfset var payload = {
      "model":    variables.model,
      "stream":   false,
      "messages": arguments.messages,
      "options":  { "temperature": arguments.temperature }
    } />

    <cfset var result = makeRequest("/api/chat", payload) />
    <cfreturn result.message.content />
  </cffunction>

  <!--- ── makeRequest: internal HTTP helper ───────────────────────────── --->
  <cffunction name="makeRequest" access="private" returntype="struct">
    <cfargument name="path"    type="string" required="true" />
    <cfargument name="payload" type="struct" required="true" />

    <cfset var httpResult = {} />

    <cfhttp method="POST" url="#variables.baseUrl##arguments.path#" result="httpResult">
      <cfhttpparam type="header" name="Content-Type" value="application/json" />
      <cfhttpparam type="body"   value="#serializeJSON(arguments.payload)#" />
    </cfhttp>

    <cfif NOT (httpResult.statusCode contains "200")>
      <cfthrow type="OllamaService.Error"
               message="Ollama API error: #httpResult.statusCode#"
               detail="#httpResult.fileContent#" />
    </cfif>

    <cfreturn deserializeJSON(httpResult.fileContent) />
  </cffunction>

</cfcomponent>
```

---

## 3. /api/ai-chat.cfm — REST endpoint

Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-chat.cfm`:

```cfml
<!---
  /api/ai-chat.cfm
  POST  { "prompt": "...", "system": "..." }  → { "response": "...", "model": "..." }
  GET                                         → health check
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  method = cgi.REQUEST_METHOD;

  // Health check
  if (method == "GET") {
    writeOutput(serializeJSON({ "status": "ok", "model": "phi3:mini" }));
    abort;
  }

  if (method != "POST") {
    cfheader(statuscode="405", statustext="Method Not Allowed");
    writeOutput(serializeJSON({ "error": "POST required" }));
    abort;
  }

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
         : "You are a helpful IT support assistant for Hungry Minds.";

  if (!len(prompt)) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "prompt is required" }));
    abort;
  }

  svc = createObject("component", "OllamaService");

  messages = [
    { "role": "system", "content": system },
    { "role": "user",   "content": prompt }
  ];

  reply = svc.chat(messages);

  writeOutput(serializeJSON({
    "response": reply,
    "model":    "phi3:mini",
    "prompt":   prompt
  }));
</cfscript>
```

---

## 4. Test from the terminal

```bash
# Health check
curl -s http://localhost:8500/api/ai-chat.cfm | python3 -m json.tool

# Ask a question
curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{"prompt":"What are the top 3 causes of IT support tickets?"}' \
  | python3 -m json.tool

# Use a custom system prompt
curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
  -H "Content-Type: application/json" \
  -d '{
    "system": "You are a CFML expert. Keep answers to 2 sentences.",
    "prompt": "What is a CFC?"
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

---

## 5. Error handling

Ollama can be slow to respond on the first request (model load). Set a generous
timeout in `<cfhttp>`:

```cfml
<cfhttp method="POST" url="http://ollama:11434/api/generate"
        result="httpResult" timeout="120">
  ...
</cfhttp>
```

Always wrap AI calls in `<cftry>` — the model node may be busy or restarting:

```cfml
<cftry>
  reply = svc.generate(prompt);
<cfcatch type="OllamaService.Error">
  reply = "Sorry, the AI assistant is temporarily unavailable.";
</cfcatch>
</cftry>
```

---

## Key takeaways

| Concept | ColdFusion approach |
|---|---|
| HTTP client | `<cfhttp>` with `cfhttpparam type="body"` |
| POST JSON | Serialize with `serializeJSON()`, set `Content-Type: application/json` |
| Parse response | `deserializeJSON(httpResult.fileContent)` |
| Reusable AI layer | `OllamaService.cfc` with `generate()` and `chat()` methods |
| Timeout | `<cfhttp timeout="120">` for slow first-load |
| Error handling | `<cftry>`/`<cfcatch type="OllamaService.Error">` |

