---
kind: lesson

title: AI-Powered Help Desk
description: |
  Build a real AI feature on top of the Help Desk application. Use
  OllamaService.cfc to auto-triage new tickets, suggest resolutions
  for open tickets, and generate a summary report — all powered by
  phi3:mini running locally on the ollama VM.

name: ai-helpdesk
slug: ai-helpdesk

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- helpdesk
- database

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_triage_endpoint:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:8500/api/ai-triage.cfm?ticket_id=1")
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-triage.cfm?ticket_id=1 returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-triage.cfm accessible ✓"

  verify_triage_json:
    machine: cf-dev
    user: laborant
    needs:
      - verify_triage_endpoint
    run: |
      BODY=$(curl -s "http://localhost:8500/api/ai-triage.cfm?ticket_id=1")
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'suggested_priority' in d and 'resolution' in d" 2>/dev/null; then
        echo "ai-triage.cfm response missing 'suggested_priority' or 'resolution' fields"
        exit 1
      fi
      echo "Triage fields present ✓"

  verify_summary_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - verify_triage_json
    run: |
      BODY=$(curl -s "http://localhost:8500/api/ai-summary.cfm")
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'summary' in d" 2>/dev/null; then
        echo "ai-summary.cfm response missing 'summary' field"
        exit 1
      fi
      echo "AI summary generated ✓"
---

## Overview

You now have all the pieces:
- A live Help Desk database (`hd_tickets`, `hd_users`, `hd_comments`)
- A REST API layer (`/api/tickets.cfm`)
- A local LLM accessible at `http://ollama:11434`
- `OllamaService.cfc` for calling Ollama from CFML

This lesson wires them together to build two AI features:
1. **Auto-triage** — analyse a ticket's title/description and suggest a priority + resolution steps
2. **Summary report** — generate a plain-English summary of all open tickets

---

## 1. Auto-triage endpoint

Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-triage.cfm`:

```cfml
<!---
  /api/ai-triage.cfm?ticket_id=N
  Returns AI-suggested priority and resolution steps for a ticket.
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  // Validate ticket_id
  ticketId = structKeyExists(url, "ticket_id") ? val(url.ticket_id) : 0;
  if (ticketId LTE 0) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "ticket_id is required" }));
    abort;
  }

  // Fetch ticket from the database
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

  // Build the AI prompt
  systemPrompt = "You are an IT support triage assistant. Analyse support tickets
and respond in valid JSON only, with exactly two fields:
  suggested_priority: one of low, medium, high, or critical
  resolution: a 2-3 step actionable resolution guide (plain text, no markdown)
Do not include any text outside the JSON object.";

  userPrompt = "Ticket title: #q.title#
Department: #q.department#
Description: #q.description#";

  // Call Ollama
  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": userPrompt   }
  ];

  aiRaw = svc.chat(messages);

  // Parse the JSON the model returned (it may wrap it in a code fence)
  aiRaw = reReplace(aiRaw, "```json\s*|\s*```", "", "ALL");
  aiRaw = trim(aiRaw);

  if (isJSON(aiRaw)) {
    triage = deserializeJSON(aiRaw);
  } else {
    // Fallback if model didn't return clean JSON
    triage = { "suggested_priority": q.priority, "resolution": aiRaw };
  }

  writeOutput(serializeJSON({
    "ticket_id":          ticketId,
    "title":              q.title,
    "current_priority":   q.priority,
    "suggested_priority": triage.suggested_priority ?: q.priority,
    "resolution":         triage.resolution         ?: "See AI response",
    "ai_raw":             aiRaw
  }));
</cfscript>
```

Test it:
```bash
curl -s "http://localhost:8500/api/ai-triage.cfm?ticket_id=2" | python3 -m json.tool
```

---

## 2. Ticket summary report

Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-summary.cfm`:

```cfml
<!---
  /api/ai-summary.cfm
  Returns an AI-generated plain-English summary of all open tickets.
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  // Fetch open tickets
  q = queryExecute(
    "SELECT t.id, t.title, t.priority, d.name AS department
     FROM   hd_tickets t
     JOIN   hd_users   u ON u.id = t.user_id
     JOIN   hd_departments d ON d.id = u.department_id
     WHERE  t.status = 'open'
     ORDER  BY CASE t.priority
                 WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                 WHEN 'medium'   THEN 3 ELSE 4 END",
    {}, { datasource: "training_db" }
  );

  if (q.recordCount == 0) {
    writeOutput(serializeJSON({ "summary": "No open tickets at this time.", "count": 0 }));
    abort;
  }

  // Format tickets as a numbered list for the prompt
  ticketList = "";
  for (i = 1; i LTE q.recordCount; i++) {
    ticketList &= i & ". [#q.priority[i]#] #q.title[i]# (Dept: #q.department[i]#)" & chr(10);
  }

  systemPrompt = "You are an IT manager assistant. Write a concise 3-4 sentence
executive summary of the open support tickets listed below. Highlight the most
urgent items and any patterns you notice. Plain text only, no bullet points.";

  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": "Open tickets:#chr(10)##ticketList#" }
  ];

  summary = svc.chat(messages, 0.5);  // lower temperature for factual summary

  writeOutput(serializeJSON({
    "count":   q.recordCount,
    "summary": trim(summary)
  }));
</cfscript>
```

Test it:
```bash
curl -s http://localhost:8500/api/ai-summary.cfm \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['summary'])"
```

---

## 3. Displaying results in a CFML page

You can consume either endpoint from any `.cfm` page using `<cfhttp>`:

```cfml
<cfscript>
  // Get AI triage for ticket 3
  cfhttp(method="GET",
         url="http://localhost:8500/api/ai-triage.cfm?ticket_id=3",
         result="res");
  triage = deserializeJSON(res.fileContent);
</cfscript>

<cfoutput>
  <h3>#triage.title#</h3>
  <p><strong>AI suggested priority:</strong> #triage.suggested_priority#</p>
  <p><strong>Resolution steps:</strong><br>#triage.resolution#</p>
</cfoutput>
```

---

## 4. Extend it yourself

Try these modifications as practice:

**A. Auto-update the priority** — after triage, update `hd_tickets.priority` in the database if the AI suggested a different value:
```cfml
if (triage.suggested_priority != q.priority) {
  queryExecute(
    "UPDATE hd_tickets SET priority = :p WHERE id = :id",
    { p: { value: triage.suggested_priority, cfsqltype: "cf_sql_varchar" },
      id: { value: ticketId, cfsqltype: "cf_sql_integer" } },
    { datasource: "training_db" }
  );
}
```

**B. AI comment** — post the resolution steps as a comment on the ticket using the `hd_comments` table.

**C. Department filter** — add a `?department=IT` URL param to `ai-summary.cfm` to summarise only one department's tickets.

---

## Key takeaways

| Feature | Implementation |
|---|---|
| AI triage | Read ticket → build prompt → call `svc.chat()` → parse JSON response |
| AI summary | Query multiple rows → format as text list → call `svc.chat()` |
| Clean JSON from LLM | Strip code fences with `reReplace()`, check `isJSON()`, provide fallback |
| Temperature control | `svc.chat(messages, 0.5)` — lower for factual summaries |
| DB + AI together | Standard `queryExecute` for data, `OllamaService.cfc` for AI |

