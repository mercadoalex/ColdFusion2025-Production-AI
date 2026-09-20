---
kind: unit

title: AI-Powered Help Desk

name: ai-helpdesk-unit-1
---

## From isolated AI calls to a real feature

In the previous lesson you built `OllamaService.cfc` and proved it can talk to `phi3:mini`. That was the plumbing. This lesson is the feature — something a real user benefits from.

The Help Desk application already has tickets in a database, a REST API, and users who need to work through a queue. AI makes two things dramatically faster:

1. **Auto-triage** — instead of a support engineer reading each ticket and manually deciding the priority, the model reads the description, considers the department, and suggests a priority level plus a step-by-step resolution guide. Takes ~5 seconds. Replaces 5–10 minutes of manual reading.

2. **Executive summary** — instead of a manager opening every ticket to understand the current state, a single API call produces a plain-English paragraph describing the open queue, its most urgent items, and any patterns. Takes ~10 seconds. Replaces a 30-minute weekly status meeting.

Both features reuse `OllamaService.cfc` from the previous lesson — no new AI infrastructure required.

::image-box
---
:src: __static__/ai-helpdesk-flow-v1.png
:alt: Two-column flow diagram. Left column shows GET /api/ai-triage.cfm?ticket_id=N — Browser calls ai-triage.cfm which reads from training_db (hd_tickets), builds a prompt, calls OllamaService.cfc which POSTs to Ollama phi3:mini via cfhttp, and returns a JSON response with suggested_priority and resolution fields. Right column shows GET /api/ai-summary.cfm — Browser calls ai-summary.cfm which queries all open tickets from training_db, formats them as a numbered list, calls OllamaService.cfc which POSTs to Ollama, and returns a JSON response with count and summary fields. Caption: Both endpoints share OllamaService.cfc.
:max-width: 960px
---
_Two AI endpoints, one service layer. Triage is per-ticket; summary spans the entire open queue._
::

By the end of this lesson you will have built:

- **`/api/ai-triage.cfm`** — reads a ticket from the DB, asks the model to suggest a priority and resolution steps, returns structured JSON
- **`/api/ai-summary.cfm`** — fetches all open tickets, asks the model for an executive summary paragraph, returns it as JSON

::hint-box
---
:summary: Do I need to build OllamaService.cfc again?
---
No. This lesson picks up exactly where the previous one ended. `OllamaService.cfc` must already exist at `/opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc`.

If you're starting this lesson fresh, run the creation command from the **Calling AI from CFML** lesson first — the triage and summary endpoints will not work without it.
::

::hint-box
---
:summary: What is the Help Desk database schema?
---
The `training_db` H2 database has three relevant tables:

| Table | Key columns |
|---|---|
| `hd_tickets` | `id`, `title`, `description`, `priority` (low/medium/high/critical), `status` (open/closed), `user_id` |
| `hd_users` | `id`, `name`, `department_id` |
| `hd_departments` | `id`, `name` |

The triage endpoint joins all three to get the ticket title, description, current priority, and the user's department — context that helps the model make a better suggestion.
::

---

## 1. Verify the prerequisites

Before building the AI endpoints, confirm the Help Desk database has ticket data and `OllamaService.cfc` is in place.

**Activity — Terminal (dev):**

```bash
# Confirm OllamaService.cfc exists
ls -la /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc

# Confirm tickets exist in the database
curl -s "http://localhost:8500/api/tickets.cfm" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Tickets found:', len(d))"
```

::hint-box
---
:summary: No tickets in the database? Seed it first.
---
If the tickets API returns an empty array, the database needs seeding. Run:

```bash
curl -s "http://localhost:8500/db-seed.cfm"
```

This creates sample tickets across departments with varying priorities. If `db-seed.cfm` doesn't exist, check the Help Desk setup from Module 3.
::

::simple-task
---
:tasks: tasks
:name: verify_triage_endpoint
---
#active
Create `ai-triage.cfm` (section 2 below) and confirm `GET /api/ai-triage.cfm?ticket_id=1` returns HTTP 200.

#completed
ai-triage.cfm accessible. ✓
::

---

## 2. AI triage endpoint

The triage endpoint does three things in sequence: reads the ticket from the database, builds a structured prompt, and asks the model to return a JSON response with a suggested priority and resolution steps.

::hint-box
---
:summary: Why ask the model to return JSON rather than plain text?
---
Plain text responses are great for humans to read but painful to process programmatically. If the model returns:

```
I think this is a high priority ticket. You should first check the network logs, then restart the service, then escalate to the network team.
```

You have to parse that with string manipulation — fragile and brittle.

If you ask the model to return JSON:
```json
{"suggested_priority":"high","resolution":"1. Check network logs. 2. Restart the service. 3. Escalate to network team."}
```

You can do `triage.suggested_priority` directly. **The system prompt is the key** — it tells the model exactly what format to use. With a clear instruction like *"respond in valid JSON only, return exactly two fields"*, `phi3:mini` follows it reliably most of the time.

The `isJSON()` guard and fallback struct handle the cases where it doesn't.
::

**Activity — Terminal (dev):** Create the triage endpoint:

```bash
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/api

sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-triage.cfm << 'TRIAGEEOF'
<cfscript>
  cfheader(name="Content-Type", value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");
  ticketId = structKeyExists(url,"ticket_id") ? val(url.ticket_id) : 0;
  if (ticketId LTE 0) {
    cfheader(statuscode="400", statustext="Bad Request");
    writeOutput(serializeJSON({"error":"ticket_id is required"}));
    abort;
  }
  q = queryExecute("SELECT t.title, t.description, t.priority, d.name AS department FROM hd_tickets t JOIN hd_users u ON u.id = t.user_id JOIN hd_departments d ON d.id = u.department_id WHERE t.id = :id AND t.status != 'closed'",{id:{value:ticketId,cfsqltype:"cf_sql_integer"}},{datasource:"training_db"});
  if (q.recordCount == 0) {
    cfheader(statuscode="404", statustext="Not Found");
    writeOutput(serializeJSON({"error":"Ticket not found or already closed"}));
    abort;
  }
  systemPrompt = "You are an IT support triage assistant. Analyse the support ticket and respond in valid JSON only. Return exactly two fields: suggested_priority (one of: low, medium, high, critical) and resolution (a 2-3 step actionable guide, plain text, no markdown). Do not include any text outside the JSON object.";
  userPrompt = "Ticket title: " & q.title & " | Department: " & q.department & " | Description: " & q.description;
  svc = createObject("component","OllamaService");
  messages = [{"role":"system","content":systemPrompt},{"role":"user","content":userPrompt}];
  try {
    aiRaw = svc.chat(messages, 0.2);
  } catch (OllamaService.Error e) {
    cfheader(statuscode="503", statustext="Service Unavailable");
    writeOutput(serializeJSON({"error":"AI unavailable: " & e.message}));
    abort;
  }
  aiRaw = trim(reReplace(aiRaw,"```json\s*|\s*```","","ALL"));
  triage = isJSON(aiRaw) ? deserializeJSON(aiRaw) : {"suggested_priority":q.priority,"resolution":aiRaw};
  out = {"ticket_id":ticketId,"title":q.title,"current_priority":q.priority,"suggested_priority":triage.suggested_priority ?: q.priority,"resolution":triage.resolution ?: "See AI response"};
  writeOutput(serializeJSON(out));
</cfscript>
TRIAGEEOF
```

**Activity — Terminal (dev):** Test the endpoint:

```bash
# Basic test — should return JSON with suggested_priority and resolution
curl -s "http://localhost:8500/api/ai-triage.cfm?ticket_id=1" | python3 -m json.tool

# Test the 400 path
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8500/api/ai-triage.cfm"
# Expected: 400

# Test the 404 path
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8500/api/ai-triage.cfm?ticket_id=9999"
# Expected: 404
```

::hint-box
---
:summary: Why temperature 0.2 for triage?
---
Triage is a classification task — you want the model to pick a priority level and give structured steps, not be creative. Low temperature (0.2) makes the output more deterministic and more likely to follow the JSON format instruction precisely.

If you use a high temperature (0.8+) on structured output tasks, the model is more likely to deviate from the requested format — adding commentary, wrapping the JSON in a sentence, or choosing unexpected priority levels.

**Rule of thumb:** Use low temperature (0.1–0.3) for classification, extraction, and structured output. Use higher temperature (0.6–0.9) for creative writing, suggestions, and brainstorming.
::

::hint-box
---
:summary: What is the reReplace() line doing?
---
`phi3:mini` sometimes wraps its JSON response in a Markdown code fence:

````
```json
{"suggested_priority":"high","resolution":"..."}
```
````

This is valid Markdown but invalid JSON. `reReplace(aiRaw, "```json\s*|\s*```", "", "ALL")` strips those fences using a regex that matches:
- `` ```json `` followed by optional whitespace
- `` ``` `` preceded by optional whitespace

After stripping, `trim()` removes any leading/trailing newlines, leaving clean JSON. The `isJSON()` guard then confirms it's parseable before calling `deserializeJSON()`. If it's still not valid JSON (rare, but possible), the fallback struct uses the current DB priority and returns the raw AI text in the `resolution` field.
::

::simple-task
---
:tasks: tasks
:name: verify_triage_json
---
#active
Confirm the response from `GET /api/ai-triage.cfm?ticket_id=1` contains both `suggested_priority` and `resolution` fields.

#completed
Triage fields present. ✓
::

---

## 3. AI summary endpoint

The summary endpoint fetches all open tickets, formats them as a numbered list ordered by priority, and asks the model to write a 3–4 sentence executive paragraph describing the state of the queue.

::hint-box
---
:summary: Why format tickets as a numbered list rather than passing raw JSON to the model?
---
Language models are trained primarily on natural language text, not structured data. A numbered list like:

```
1. [critical] VPN access broken (Dept: IT)
2. [high] Email server slow (Dept: Operations)
3. [medium] Printer offline (Dept: Finance)
```

is much easier for the model to reason about than a raw JSON array of structs. It reads like a briefing document, which is exactly the kind of content the model was trained to summarise.

This is a general principle: **transform your data into the format the model is best at reading before sending it**. SQL result sets, database rows, and CFML structs should be formatted as clean prose or lists before they go into a prompt.
::

**Activity — Terminal (dev):** Create the summary endpoint:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-summary.cfm << 'SUMMARYEOF'
<cfscript>
  cfheader(name="Content-Type", value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");
  q = queryExecute("SELECT t.id, t.title, t.priority, d.name AS department FROM hd_tickets t JOIN hd_users u ON u.id = t.user_id JOIN hd_departments d ON d.id = u.department_id WHERE t.status = 'open' ORDER BY CASE t.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END",{},{datasource:"training_db"});
  if (q.recordCount == 0) {
    writeOutput(serializeJSON({"summary":"No open tickets at this time.","count":0}));
    abort;
  }
  ticketList = "";
  for (i = 1; i LTE q.recordCount; i++) {
    ticketList &= i & ". [" & q.priority[i] & "] " & q.title[i] & " (Dept: " & q.department[i] & ") ";
  }
  systemPrompt = "You are an IT manager assistant. Write a concise 3-4 sentence executive summary of the open support tickets listed. Highlight the most urgent items and any patterns you notice. Plain text only, no bullet points, no markdown.";
  svc = createObject("component","OllamaService");
  messages = [{"role":"system","content":systemPrompt},{"role":"user","content":"Open tickets: " & ticketList}];
  try {
    summary = svc.chat(messages, 0.4);
  } catch (OllamaService.Error e) {
    cfheader(statuscode="503", statustext="Service Unavailable");
    writeOutput(serializeJSON({"error":"AI unavailable: " & e.message}));
    abort;
  }
  writeOutput(serializeJSON({"count":q.recordCount,"summary":trim(summary)}));
</cfscript>
SUMMARYEOF
```

**Activity — Terminal (dev):** Test the endpoint:

```bash
# Pretty-print the full response
curl -s http://localhost:8500/api/ai-summary.cfm | python3 -m json.tool

# Print just the summary text
curl -s http://localhost:8500/api/ai-summary.cfm \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Tickets:', d['count']); print(); print(d['summary'])"
```

::hint-box
---
:summary: Why temperature 0.4 for summary and 0.2 for triage?
---
The summary task is slightly more open-ended than triage — you want the model to produce a readable paragraph, not just fill in a JSON field. A small amount of temperature (0.4) lets the sentence structure vary naturally while still keeping the content factual and grounded.

Triage at 0.2 is stricter because you need it to output a specific JSON structure and pick from a defined set of priority values. Summary at 0.4 has more room because the output is free-form prose — any coherent paragraph works.
::

::simple-task
---
:tasks: tasks
:name: verify_summary_endpoint
---
#active
Confirm `GET /api/ai-summary.cfm` returns a JSON body with a non-empty `summary` field.

#completed
AI summary generated. ✓
::

---

## 4. Consuming AI results in a CFML page

Both endpoints return JSON, so any `.cfm` page can consume them with a `cfhttp` call and display the results inline. This is the bridge between the AI API and the actual Help Desk UI:

```cfml
<cfscript>
  // ── Call the triage endpoint for ticket #2 ───────────────────────────
  cfhttp(method="GET", url="http://localhost:8500/api/ai-triage.cfm?ticket_id=2", result="res");
  triage = deserializeJSON(res.fileContent);
</cfscript>

<cfoutput>
  <h3>#htmlEditFormat(triage.title)#</h3>
  <p><strong>Current priority:</strong>   #triage.current_priority#</p>
  <p><strong>AI suggested priority:</strong> #triage.suggested_priority#</p>
  <blockquote>#htmlEditFormat(triage.resolution)#</blockquote>
</cfoutput>
```

**Activity — Terminal (dev):** Create a quick display page to see it rendered:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/ai-helpdesk-demo.cfm << 'DEMOEOF'
<cfscript>
  cfhttp(method="GET", url="http://localhost:8500/api/ai-triage.cfm?ticket_id=1", result="triageRes", timeout=120);
  cfhttp(method="GET", url="http://localhost:8500/api/ai-summary.cfm", result="summaryRes", timeout=120);
  triage = isJSON(triageRes.fileContent) ? deserializeJSON(triageRes.fileContent) : {};
  summary = isJSON(summaryRes.fileContent) ? deserializeJSON(summaryRes.fileContent) : {};
</cfscript>
<!DOCTYPE html>
<html><head><title>AI Help Desk Demo</title></head>
<body style="font-family:sans-serif;max-width:800px;margin:40px auto;padding:20px">
<h1>AI Help Desk</h1>
<h2>Ticket Triage — Ticket #1</h2>
<cfoutput>
<p><strong>Title:</strong> #htmlEditFormat(triage.title ?: "n/a")#</p>
<p><strong>Current priority:</strong> #htmlEditFormat(triage.current_priority ?: "n/a")#</p>
<p><strong>AI suggested priority:</strong> #htmlEditFormat(triage.suggested_priority ?: "n/a")#</p>
<blockquote>#htmlEditFormat(triage.resolution ?: "n/a")#</blockquote>
<h2>Open Ticket Summary (#summary.count ?: 0# tickets)</h2>
<p>#htmlEditFormat(summary.summary ?: "No summary available")#</p>
</cfoutput>
</body></html>
DEMOEOF

echo "Open: http://localhost:8500/ai-helpdesk-demo.cfm"
```

::hint-box
---
:summary: Why wrap both cfhttp calls before rendering the HTML?
---
Both AI calls can take 5–30 seconds each. If you interleave them with HTML output (call, render, call, render), the browser receives a partial page while waiting. By making both calls at the top of the script and storing results in variables, the full page renders at once — clean, no partial-load artefacts.

In a production application you'd likely use AJAX calls from the browser so the page loads immediately and the AI results fill in asynchronously, but for a server-rendered `.cfm` page this top-load pattern is correct.
::

---

## 5. Extension ideas

::hint-box
---
:summary: Going further — three extensions to try
---
**A. Auto-update the database priority**

After a successful triage response, if the AI's suggestion differs from the current priority, write it back:

```cfml
if (triage.suggested_priority != q.priority) {
  queryExecute(
    "UPDATE hd_tickets SET priority = :p WHERE id = :id",
    {p:{value:triage.suggested_priority,cfsqltype:"cf_sql_varchar"},id:{value:ticketId,cfsqltype:"cf_sql_integer"}},
    {datasource:"training_db"}
  );
}
```

**B. Post the resolution as an AI comment**

Insert the resolution steps into `hd_comments` so support staff see the AI suggestion in the ticket thread alongside human replies.

**C. Department-scoped summary**

Add `?department=IT` to `ai-summary.cfm` and filter the query with `AND d.name = :dept`. The model then summarises only one department's tickets — useful for department heads who don't want to see the full queue.
::

---

## Key concepts reference

| Concept | Pattern |
|---|---|
| Read ticket for AI | `queryExecute()` → join `hd_tickets`, `hd_users`, `hd_departments` |
| Structured JSON output | System prompt: *"respond in valid JSON only, return exactly these fields"* |
| Clean code-fenced JSON | `reReplace(raw,"```json\s*\|\s*```","","ALL")` + `trim()` |
| Guard before deserialize | `isJSON(raw) ? deserializeJSON(raw) : fallbackStruct` |
| Format rows for LLM | Loop over query rows → build numbered list string → send as user message |
| Temperature for classification | 0.2 — strict, structured, follows format instructions |
| Temperature for summary | 0.4 — factual but readable prose |
| Reuse service layer | Both endpoints call `OllamaService.cfc` — no new AI infrastructure |
| Consume from CFML page | `cfhttp` GET to the endpoint → `deserializeJSON(res.fileContent)` |

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
:challenge: challenges.ai-helpdesk-f87111e5
---
::
