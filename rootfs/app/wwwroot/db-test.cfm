<!--- db-test.cfm — tests the training_db datasource and shows help desk data --->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>DB Test — ColdFusion Training</title>
  <style>
    body  { font-family: monospace; background: #0f172a; color: #e2e8f0; padding: 2rem; max-width: 900px; }
    h2    { color: #38bdf8; margin-bottom: 1rem; }
    h3    { color: #7dd3fc; margin: 1.5rem 0 .5rem; }
    .ok   { color: #4ade80; }
    .err  { color: #f87171; }
    .muted{ color: #64748b; }
    table { width: 100%; border-collapse: collapse; font-size: .85rem; margin-bottom: 1rem; }
    th    { background: #1e293b; color: #94a3b8; text-align: left; padding: .4rem .75rem; border-bottom: 1px solid #334155; }
    td    { padding: .4rem .75rem; border-bottom: 1px solid #1e293b; }
    tr:hover td { background: #1e293b; }
    .badge { display:inline-block; padding:.15rem .5rem; border-radius:4px; font-size:.75rem; font-weight:700; }
    .open        { background:#1e3a5f; color:#7dd3fc; }
    .in_progress { background:#3b1f6e; color:#c4b5fd; }
    .resolved    { background:#14532d; color:#86efac; }
    .high   { background:#7f1d1d; color:#fca5a5; }
    .medium { background:#78350f; color:#fcd34d; }
    .low    { background:#1e293b; color:#94a3b8; }
    .btn { display:inline-block; padding:.4rem 1rem; border-radius:5px; font-size:.8rem;
           font-weight:600; text-decoration:none; background:#1d4ed8; color:#fff; margin-right:.5rem; }
    .btn-secondary { background:#1e293b; border:1px solid #475569; color:#94a3b8; }
  </style>
</head>
<body>
<h2>Datasource Connectivity Test</h2>

<cftry>
  <!--- Basic connectivity check --->
  <cfquery datasource="training_db" name="ping">
    SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME IN ('HD_TICKETS','HD_USERS','HD_DEPARTMENTS','HD_COMMENTS')
  </cfquery>

  <cfif ping.cnt LT 4>
    <p class="err">❌ Schema not seeded yet.
      <a class="btn" href="/seed-db.cfm">Run Seed Script →</a>
    </p>
  <cfelse>
    <p class="ok">✅ Connected to <strong>training_db</strong> (H2 embedded) — schema ready.</p>

    <!--- Ticket summary --->
    <cfquery datasource="training_db" name="tickets">
      SELECT
        t.id,
        t.title,
        t.status,
        t.priority,
        t.category,
        u.full_name  AS requester,
        a.full_name  AS assignee,
        t.created_at
      FROM hd_tickets t
      JOIN hd_users u ON u.id = t.requester_id
      LEFT JOIN hd_users a ON a.id = t.assignee_id
      ORDER BY t.id DESC
    </cfquery>

    <h3>Tickets (<cfoutput>#tickets.recordCount#</cfoutput> rows)</h3>
    <table>
      <tr>
        <th>#</th><th>Title</th><th>Status</th><th>Priority</th>
        <th>Category</th><th>Requester</th><th>Assignee</th>
      </tr>
      <cfoutput query="tickets">
        <tr>
          <td>#id#</td>
          <td>#title#</td>
          <td><span class="badge #status#">#status#</span></td>
          <td><span class="badge #priority#">#priority#</span></td>
          <td>#category#</td>
          <td>#requester#</td>
          <td>#len(trim(assignee)) ? assignee : "<span class='muted'>unassigned</span>"#</td>
        </tr>
      </cfoutput>
    </table>

    <!--- User summary --->
    <cfquery datasource="training_db" name="users">
      SELECT u.full_name, u.role, u.email, d.name AS department
      FROM hd_users u
      LEFT JOIN hd_departments d ON d.id = u.department_id
      ORDER BY u.role, u.full_name
    </cfquery>

    <h3>Users (<cfoutput>#users.recordCount#</cfoutput> rows)</h3>
    <table>
      <tr><th>Name</th><th>Role</th><th>Email</th><th>Department</th></tr>
      <cfoutput query="users">
        <tr>
          <td>#full_name#</td>
          <td>#role#</td>
          <td>#email#</td>
          <td>#department#</td>
        </tr>
      </cfoutput>
    </table>

  </cfif>

  <cfcatch type="any">
    <p class="err">❌ Error: <cfoutput>#cfcatch.message#</cfoutput></p>
    <pre><cfoutput>#cfcatch.detail#</cfoutput></pre>
    <p><a class="btn" href="/seed-db.cfm">Run Seed Script →</a></p>
  </cfcatch>
</cftry>

<p style="margin-top:1.5rem">
  <a class="btn btn-secondary" href="/">← Home</a>
  <a class="btn btn-secondary" href="/seed-db.cfm">Re-run Seed</a>
  <a class="btn btn-secondary" href="/api-test.cfm">API Test</a>
</p>
</body>
</html>
