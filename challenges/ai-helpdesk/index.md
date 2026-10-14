---
kind: challenge

title: 'AI-Powered Ticket Classifier'

description: |
  Build an AI endpoint that classifies a help desk ticket into a department
  (IT, HR, Finance, Facilities) based on its title and description, then
  extend it to a batch endpoint that classifies all open tickets at once.

categories:
  - programming

tagz:
  - coldfusion
  - ai
  - helpdesk
  - database

difficulty: hard

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  classifier_endpoint:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/api/ai-classify.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "ai-classify.cfm not found at ${FILE}"
        exit 1
      fi
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:8500/api/ai-classify.cfm?ticket_id=1" 2>/dev/null)
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-classify.cfm?ticket_id=1 returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-classify.cfm accessible ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/api/ai-classify.cfm"
      echo "It must accept ?ticket_id=N, fetch the ticket, call OllamaService.cfc, and return JSON."
      echo "Test: curl -s 'http://localhost:8500/api/ai-classify.cfm?ticket_id=1'"

  classification_returned:
    machine: cf-dev
    user: laborant
    needs:
      - classifier_endpoint
    run: |
      BODY=$(curl -s --max-time 120 \
        "http://localhost:8500/api/ai-classify.cfm?ticket_id=1" 2>/dev/null)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'department' in d and d['department'] in ['IT','HR','Finance','Facilities','Other']" 2>/dev/null; then
        echo "ai-classify.cfm did not return a valid JSON department classification"
        echo "Response was: ${BODY}"
        exit 1
      fi
      echo "Department classification returned ✓"
    hintcheck: |
      echo "Your system prompt must instruct the model to respond in JSON only:"
      echo '  "Classify into exactly one of: IT, HR, Finance, Facilities, Other.'
      echo '   Respond in JSON only: {\"department\":\"IT\",\"confidence\":\"high\"}"'
      echo "Test: curl -s 'http://localhost:8500/api/ai-classify.cfm?ticket_id=1' | python3 -m json.tool"

  batch_classify_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - classification_returned
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/api/ai-classify-batch.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "ai-classify-batch.cfm not found at ${FILE}"
        exit 1
      fi
      BODY=$(curl -s --max-time 300 \
        http://localhost:8500/api/ai-classify-batch.cfm 2>/dev/null)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d.get('results'),list) and len(d['results'])>0" 2>/dev/null; then
        echo "ai-classify-batch.cfm did not return a non-empty results array"
        echo "Response was: ${BODY}"
        exit 1
      fi
      echo "Batch classification returned results ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/api/ai-classify-batch.cfm"
      echo "It must query hd_tickets WHERE status != 'closed', classify each one,"
      echo "and return: {\"count\": N, \"results\": [{\"ticket_id\":1,\"department\":\"IT\"}, ...]}"
      echo "Test: curl -s http://localhost:8500/api/ai-classify-batch.cfm | python3 -m json.tool"
---

## AI-Powered Ticket Classifier

The lesson built triage and summary endpoints. This challenge adds a third AI pattern: **structured classification** — a system prompt that forces the model to respond with exactly one value from a fixed set. This technique is the foundation of any AI feature that must produce machine-readable output.

Work in `/opt/coldfusion2025/cfusion/wwwroot/api/` — the same directory as `ai-triage.cfm` and `ai-summary.cfm`.

---

### Task 1 — Build the single-ticket classifier

Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-classify.cfm`. It receives `?ticket_id=N`, fetches the ticket from the database, calls `OllamaService.cfc` with a classification system prompt, and returns structured JSON.

The key technique is the **constrained system prompt** — instructing the model to respond with JSON only and from a fixed list of values:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-classify.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type", value="application/json");

  ticketId = val(url.ticket_id ?: 0);
  if (ticketId == 0) {
    writeOutput(serializeJSON({ "error": "ticket_id required" }));
    abort;
  }

  // ── Fetch the ticket ────────────────────────────────────────────────
  ticket = queryExecute(
    "SELECT t.id, t.title, t.description, d.name AS department
     FROM hd_tickets t
     JOIN hd_users u    ON u.id = t.user_id
     JOIN hd_departments d ON d.id = u.department_id
     WHERE t.id = :id",
    { id: { value: ticketId, cfsqltype: "cf_sql_integer" } },
    { datasource: "training_db" }
  );

  if (ticket.recordCount == 0) {
    cfheader(statuscode=404, statustext="Not Found");
    writeOutput(serializeJSON({ "error": "ticket not found" }));
    abort;
  }

  // ── Classification prompt ────────────────────────────────────────────
  systemPrompt = "You are an IT support classifier. " &
    "Given a ticket title and description, classify it into exactly one of: " &
    "IT, HR, Finance, Facilities, Other. " &
    "Respond in JSON only, with no explanation: " &
    "{""department"":""IT"",""confidence"":""high""}";

  userMessage = "Title: " & ticket.title & chr(10) &
                "Description: " & ticket.description;

  // ── Call Ollama via the service layer ────────────────────────────────
  ollamaSvc = createObject("component", "OllamaService");
  raw = ollamaSvc.chat(
    systemPrompt = systemPrompt,
    userMessage  = userMessage,
    temperature  = 0.1
  );

  // ── Clean code fences the model sometimes adds ───────────────────────
  clean = trim(reReplace(raw, "```json\s*|\s*```", "", "ALL"));

  if (!isJSON(clean)) {
    writeOutput(serializeJSON({
      "ticket_id":   ticketId,
      "title":       ticket.title,
      "department":  "Other",
      "confidence":  "low",
      "raw":         raw
    }));
    abort;
  }

  parsed = deserializeJSON(clean);

  writeOutput(serializeJSON({
    "ticket_id":  ticketId,
    "title":      ticket.title,
    "department": parsed.department ?: "Other",
    "confidence": parsed.confidence ?: "unknown"
  }));
</cfscript>
EOF
```

Test it:

```bash
curl -s "http://localhost:8500/api/ai-classify.cfm?ticket_id=1" | python3 -m json.tool
```

Expected output:

```json
{
    "ticket_id": 1,
    "title": "Printer not working",
    "department": "IT",
    "confidence": "high"
}
```

::simple-task
---
:tasks: tasks
:name: classifier_endpoint
---
#active
Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-classify.cfm` — `GET ?ticket_id=1` must return HTTP 200.

#completed
ai-classify.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: classification_returned
---
#active
Confirm the JSON response contains a `department` field with value `IT`, `HR`, `Finance`, `Facilities`, or `Other`.

#completed
Department classification returned. ✓
::

---

### Task 3 — Batch classifier for all open tickets

Create `/opt/coldfusion2025/cfusion/wwwroot/api/ai-classify-batch.cfm` that fetches all open tickets and classifies each one, returning a results array:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/api/ai-classify-batch.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type", value="application/json");

  // ── Fetch open tickets ───────────────────────────────────────────────
  tickets = queryExecute(
    "SELECT t.id, t.title, t.description
     FROM hd_tickets t
     WHERE t.status != 'closed'
     ORDER BY t.id
     LIMIT 5",
    {},
    { datasource: "training_db" }
  );

  ollamaSvc    = createObject("component", "OllamaService");
  systemPrompt = "You are an IT support classifier. " &
    "Classify the ticket into exactly one of: IT, HR, Finance, Facilities, Other. " &
    "Respond in JSON only: {""department"":""IT"",""confidence"":""high""}";

  results = [];

  for (row in tickets) {
    raw = ollamaSvc.chat(
      systemPrompt = systemPrompt,
      userMessage  = "Title: " & row.title & chr(10) & "Description: " & row.description,
      temperature  = 0.1
    );

    clean = trim(reReplace(raw, "```json\s*|\s*```", "", "ALL"));
    parsed = isJSON(clean) ? deserializeJSON(clean) : { department: "Other", confidence: "low" };

    arrayAppend(results, {
      "ticket_id":  row.id,
      "title":      row.title,
      "department": parsed.department ?: "Other",
      "confidence": parsed.confidence ?: "unknown"
    });
  }

  writeOutput(serializeJSON({
    "count":   tickets.recordCount,
    "results": results
  }));
</cfscript>
EOF
```

Test it (allow up to 5 minutes — each ticket makes one Ollama call):

```bash
curl -s --max-time 300 http://localhost:8500/api/ai-classify-batch.cfm | python3 -m json.tool
```

Expected output:

```json
{
    "count": 3,
    "results": [
        { "ticket_id": 1, "title": "Printer not working", "department": "IT",       "confidence": "high" },
        { "ticket_id": 2, "title": "Cannot access payroll", "department": "Finance", "confidence": "high" },
        { "ticket_id": 3, "title": "New employee onboarding", "department": "HR",    "confidence": "medium" }
    ]
}
```

::simple-task
---
:tasks: tasks
:name: batch_classify_endpoint
---
#active
Create `/api/ai-classify-batch.cfm` that returns `{"count": N, "results": [...]}` with at least one classified ticket.

#completed
Batch classification returned results. ✓
::
