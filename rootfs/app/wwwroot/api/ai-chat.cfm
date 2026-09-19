<!---
  /api/ai-chat.cfm
  POST { "prompt": "...", "system": "..." }  → { "response": "...", "model": "phi3:mini" }
  GET                                        → health check { "status": "ok", "model": "phi3:mini" }
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  method = cgi.REQUEST_METHOD;

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

  try {
    reply = svc.chat(messages);
  } catch (any e) {
    cfheader(statuscode="503", statustext="Service Unavailable");
    writeOutput(serializeJSON({ "error": "AI service unavailable: " & e.message }));
    abort;
  }

  writeOutput(serializeJSON({
    "response": reply,
    "model":    "phi3:mini",
    "prompt":   prompt
  }));
</cfscript>
