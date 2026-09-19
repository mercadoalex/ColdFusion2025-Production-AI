<!---
  /api/ai-triage.cfm
  GET ?ticket_id=N
  Returns AI-suggested priority and resolution steps for an open ticket.
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  ticketId = structKeyExists(url, "ticket_id") ? val(url.ticket_id) : 0;
  if (ticketId LTE 0) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "ticket_id is required" }));
    abort;
  }

  q = queryExecute(
    "SELECT t.title, t.description, t.priority, d.name AS department
     FROM   hd_tickets t
     JOIN   hd_users   u ON u.id = t.user_id
     JOIN   hd_departments d ON d.id = u.department_id
     WHERE  t.id = :id AND t.status != 'closed'",
    { id: { value: ticketId, cfsqltype: "cf_sql_integer" } },
    { datasource: "training_db" }
  );

  if (q.recordCount == 0) {
    cfheader(statuscode="404", statustext="Not Found");
    writeOutput(serializeJSON({ "error": "Ticket not found or already closed" }));
    abort;
  }

  systemPrompt = "You are an IT support triage assistant. Analyse support tickets and respond in valid JSON only, with exactly two fields: suggested_priority (one of: low, medium, high, critical) and resolution (2-3 step actionable resolution guide, plain text). Do not include any text outside the JSON object.";

  userPrompt = "Ticket title: " & q.title
             & chr(10) & "Department: " & q.department
             & chr(10) & "Description: " & q.description;

  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": userPrompt   }
  ];

  try {
    aiRaw = svc.chat(messages, 0.3);
    // Strip markdown code fences if the model added them
    aiRaw = reReplace(aiRaw, "```json\s*|\s*```", "", "ALL");
    aiRaw = trim(aiRaw);

    if (isJSON(aiRaw)) {
      triage = deserializeJSON(aiRaw);
    } else {
      triage = { "suggested_priority": q.priority, "resolution": aiRaw };
    }
  } catch (any e) {
    triage = { "suggested_priority": q.priority, "resolution": "AI triage unavailable: " & e.message };
  }

  writeOutput(serializeJSON({
    "ticket_id":          ticketId,
    "title":              q.title,
    "current_priority":   q.priority,
    "suggested_priority": triage.suggested_priority ?: q.priority,
    "resolution":         triage.resolution         ?: "",
    "ai_raw":             aiRaw ?: ""
  }));
</cfscript>
