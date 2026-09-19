---
kind: unit

title: AI-Powered Help Desk

name: ai-helpdesk-unit-1
---

## Wiring AI into a real application

You now have all the building blocks:

| Component | Location |
|---|---|
| Help Desk DB | `hd_tickets`, `hd_users`, `hd_comments` in `training_db` |
| REST API | `/api/tickets.cfm` |
| Local LLM | `http://ollama:11434` (phi3:mini) |
| AI service layer | `OllamaService.cfc` |

This lesson wires them together to build two production-quality AI features:

1. **Auto-triage** — analyse a ticket's description and suggest a priority + resolution steps
2. **Summary report** — generate a plain-English executive summary of all open tickets

::image-box
---
:src: __static__/ai-helpdesk-flow-v1.png
:alt: Flow diagram showing two paths — left path: browser requests /api/ai-triage.cfm?ticket_id=N, CF reads ticket from training_db, builds a JSON prompt, posts to OllamaService.cfc, which calls Ollama, receives suggested_priority and resolution JSON, and returns it to the browser. Right path: /api/ai-summary.cfm fetches all open tickets, formats them as a numbered list, sends to Ollama, and returns a plain-English summary paragraph.
:max-width: 900px
---
_Two AI endpoints: ticket triage (per-ticket priority + resolution) and summary report (all open tickets)._
::

---

## 1. AI triage endpoint

**Activity:** Create `/api/ai-triage.cfm`:

```bash
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/api

sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-triage.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  // Validate ticket_id parameter
  ticketId = structKeyExists(url, "ticket_id") ? val(url.ticket_id) : 0;
  if (ticketId LTE 0) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({ "error": "ticket_id is required" }));
    abort;
  }

  // Load the ticket from the database
  q = queryExecute(
    "SELECT t.title, t.description, t.priority,
            d.name AS department
     FROM   hd_tickets t
     JOIN   hd_users       u ON u.id = t.user_id
     JOIN   hd_departments d ON d.id = u.department_id
     WHERE  t.id = :id
     AND    t.status != 'closed'",
    { id: { value: ticketId, cfsqltype: "cf_sql_integer" } },
    { datasource: "training_db" }
  );

  if (q.recordCount == 0) {
    cfheader(statuscode="404", statustext="Not Found");
    writeOutput(serializeJSON({ "error": "Ticket not found or already closed" }));
    abort;
  }

  // Build prompts — tell the model exactly what format to return
  systemPrompt = "You are an IT support triage assistant.
Analyse the support ticket and respond in valid JSON only.
Return exactly two fields:
  suggested_priority: one of low, medium, high, or critical
  resolution: a 2-3 step actionable resolution guide (plain text, no markdown, no bullet symbols)
Do not include any text outside the JSON object.";

  userPrompt = "Ticket title: " & q.title & chr(10)
             & "Department: "   & q.department & chr(10)
             & "Description: "  & q.description;

  // Call the AI
  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": userPrompt   }
  ];

  try {
    aiRaw = svc.chat(messages);
  } catch (OllamaService.Error e) {
    cfheader(statuscode=503, statustext="Service Unavailable");
    writeOutput(serializeJSON({ "error": "AI unavailable: " & e.message }));
    abort;
  }

  // Clean up — model may wrap JSON in a markdown code fence
  aiRaw = reReplace(aiRaw, "```json\s*|\s*```", "", "ALL");
  aiRaw = trim(aiRaw);

  if (isJSON(aiRaw)) {
    triage = deserializeJSON(aiRaw);
  } else {
    // Model didn't return clean JSON — use current priority as fallback
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
EOF
```

**Test it:**

```bash
curl -s "http://localhost:8500/api/ai-triage.cfm?ticket_id=1" | python3 -m json.tool
```

::simple-task
---
:tasks: tasks
:name: verify_triage_endpoint
---
#active
Create `ai-triage.cfm` and confirm `GET /api/ai-triage.cfm?ticket_id=1` returns HTTP 200.

#completed
ai-triage.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_triage_json
---
#active
Confirm the response JSON contains both `suggested_priority` and `resolution` fields.

#completed
Triage fields present. ✓
::

---

## 2. AI summary endpoint

**Activity:** Create `/api/ai-summary.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-summary.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

  // Fetch all open tickets ordered by priority
  q = queryExecute(
    "SELECT t.id, t.title, t.priority, d.name AS department
     FROM   hd_tickets t
     JOIN   hd_users       u ON u.id = t.user_id
     JOIN   hd_departments d ON d.id = u.department_id
     WHERE  t.status = 'open'
     ORDER  BY CASE t.priority
                 WHEN 'critical' THEN 1 WHEN 'high'   THEN 2
                 WHEN 'medium'   THEN 3 ELSE 4
               END",
    {}, { datasource: "training_db" }
  );

  if (q.recordCount == 0) {
    writeOutput(serializeJSON({ "summary": "No open tickets at this time.", "count": 0 }));
    abort;
  }

  // Format ticket list for the prompt
  ticketList = "";
  for (i = 1; i LTE q.recordCount; i++) {
    ticketList &= i & ". [" & q.priority[i] & "] "
               & q.title[i] & " (Dept: " & q.department[i] & ")" & chr(10);
  }

  systemPrompt = "You are an IT manager assistant.
Write a concise 3-4 sentence executive summary of the open support tickets listed below.
Highlight the most urgent items and any patterns you notice.
Plain text only, no bullet points, no markdown.";

  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": "Open tickets:" & chr(10) & ticketList }
  ];

  try {
    // Use lower temperature for factual summary
    summary = svc.chat(messages, 0.4);
  } catch (OllamaService.Error e) {
    cfheader(statuscode=503, statustext="Service Unavailable");
    writeOutput(serializeJSON({ "error": "AI unavailable: " & e.message }));
    abort;
  }

  writeOutput(serializeJSON({
    "count":   q.recordCount,
    "summary": trim(summary)
  }));
</cfscript>
EOF
```

**Test it:**

```bash
curl -s http://localhost:8500/api/ai-summary.cfm \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Tickets:', d['count']); print(d['summary'])"
```

::simple-task
---
:tasks: tasks
:name: verify_summary_endpoint
---
#active
Confirm `GET /api/ai-summary.cfm` returns a JSON body with a `summary` field.

#completed
AI summary generated. ✓
::

---

## 3. Display AI results in a CFML page

Consume either endpoint from any `.cfm` page:

```cfml
<cfscript>
  cfhttp(
    method = "GET",
    url    = "http://localhost:8500/api/ai-triage.cfm?ticket_id=2",
    result = "res"
  );
  triage = deserializeJSON(res.fileContent);
</cfscript>

<cfoutput>
  <h3>#htmlEditFormat(triage.title)#</h3>
  <p><strong>Current priority:</strong>   #triage.current_priority#</p>
  <p><strong>AI suggested priority:</strong> #triage.suggested_priority#</p>
  <blockquote>#htmlEditFormat(triage.resolution)#</blockquote>
</cfoutput>
```

---

## 4. Extension ideas

::hint-box
---
:summary: 💡 Going further — three extensions to try
---
**A. Auto-update the database priority**
After triage, if the AI's `suggested_priority` differs from the current one, update `hd_tickets.priority`:

```cfml
if (triage.suggested_priority != q.priority) {
  queryExecute(
    "UPDATE hd_tickets SET priority = :p WHERE id = :id",
    { p:  { value: triage.suggested_priority, cfsqltype: "cf_sql_varchar" },
      id: { value: ticketId,                  cfsqltype: "cf_sql_integer" } },
    { datasource: "training_db" }
  );
}
```

**B. AI comment**
Post the resolution steps as a comment in `hd_comments` so support staff can see the AI suggestion in the ticket thread.

**C. Department filter**
Add `?department=IT` to `ai-summary.cfm` to scope the summary to one department.
::

---

## Key concepts reference

| Feature | Pattern |
|---|---|
| Triage | Read ticket from DB → build system + user prompt → `svc.chat()` → parse JSON response |
| Summary | Query multiple rows → format as numbered list → `svc.chat(messages, 0.4)` |
| Clean LLM JSON | `reReplace()` to strip code fences → `isJSON()` guard → fallback struct |
| Temperature control | `svc.chat(messages, 0.4)` — lower = more factual for summaries |
| Error handling | `<cftry><cfcatch type="OllamaService.Error">` → return 503 |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Triage endpoint and summary endpoint both working — hit **Check** to complete.

#completed
AI Help Desk lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.ai-helpdesk-XXXXXXXX
---
::
