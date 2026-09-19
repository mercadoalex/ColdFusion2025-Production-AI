<!---
  OllamaService.cfc
  Reusable ColdFusion component for calling the Ollama local LLM API.
  The Ollama node is on the shared network at http://ollama:11434.

  Usage:
    svc    = createObject("component", "OllamaService");
    text   = svc.generate("What is ColdFusion?");
    reply  = svc.chat([
               {role:"system", content:"You are helpful."},
               {role:"user",   content:"Say hello!"}
             ]);
--->
<cfcomponent displayname="OllamaService"
             hint="CFC wrapper for the Ollama local LLM API (phi3:mini)">

  <cfset variables.baseUrl   = "http://ollama:11434" />
  <cfset variables.model     = "phi3:mini" />
  <cfset variables.maxTokens = 512 />
  <cfset variables.timeout   = 120 />

  <!--- ── generate ─────────────────────────────────────────────────────── --->
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

  <!--- ── chat ─────────────────────────────────────────────────────────── --->
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

    <cfset var result = makeRequest("/api/chat", payload) />
    <cfreturn result.message.content />
  </cffunction>

  <!--- ── models ───────────────────────────────────────────────────────── --->
  <cffunction name="models" access="public" returntype="array"
    hint="Returns list of model names available on the Ollama node.">

    <cfset var httpResult = {} />
    <cfhttp method="GET" url="#variables.baseUrl#/api/tags"
            result="httpResult" timeout="#variables.timeout#" />

    <cfif NOT (httpResult.statusCode contains "200")>
      <cfthrow type="OllamaService.Error"
               message="Cannot reach Ollama: #httpResult.statusCode#" />
    </cfif>

    <cfset var data = deserializeJSON(httpResult.fileContent) />
    <cfreturn data.models />
  </cffunction>

  <!--- ── makeRequest ──────────────────────────────────────────────────── --->
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
