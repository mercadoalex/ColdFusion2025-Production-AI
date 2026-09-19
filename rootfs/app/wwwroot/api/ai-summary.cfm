<!---
  /api/ai-summary.cfm
  GET — returns an AI-generated plain-English summary of all open tickets.
--->
<cfscript>
  cfheader(name="Content-Type",                value="application/json");
  cfheader(name="Access-Control-Allow-Origin", value="*");

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

  // Format tickets as a numbered list
  ticketList = "";
  for (i = 1; i LTE q.recordCount; i++) {
    ticketList &= i & ". [" & q.priority[i] & "] " & q.title[i]
               & " (Dept: " & q.department[i] & ")" & chr(10);
  }

  systemPrompt = "You are an IT manager assistant. Write a concise 3-4 sentence executive summary of the open support tickets listed below. Highlight the most urgent items and any patterns. Plain text only, no bullet points or markdown.";

  svc = createObject("component", "OllamaService");
  messages = [
    { "role": "system", "content": systemPrompt },
    { "role": "user",   "content": "Open tickets:" & chr(10) & ticketList }
  ];

  try {
    summary = svc.chat(messages, 0.5);
  } catch (any e) {
    summary = "AI summary unavailable: " & e.message;
  }

  writeOutput(serializeJSON({
    "count":   q.recordCount,
    "summary": trim(summary)
  }));
</cfscript>
