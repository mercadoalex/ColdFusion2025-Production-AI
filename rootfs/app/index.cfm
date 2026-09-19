<!--- index.cfm — Lucee / CommandBox starter app (port 8888) --->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Lucee Training App</title>
  <style>
    body   { font-family: -apple-system, "Segoe UI", sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; max-width: 760px; margin: auto; }
    h1     { color: #4fc3f7; margin-bottom: .25rem; }
    .meta  { color: #64748b; font-size: .85rem; margin-bottom: 2rem; }
    code   { background: #1e293b; padding: .15rem .45rem; border-radius: 4px; font-family: monospace; color: #7dd3fc; font-size: .9em; }
    .card  { background: #1e293b; border: 1px solid #334155; border-radius: 8px; padding: 1.25rem 1.5rem; margin-bottom: 1.25rem; }
    .card h3 { margin: 0 0 .75rem; color: #38bdf8; font-size: 1rem; }
    .step  { display: flex; gap: 1rem; margin-bottom: .6rem; align-items: flex-start; }
    .num   { background: #1d4ed8; color: #fff; border-radius: 50%; width: 22px; height: 22px; display: flex; align-items: center; justify-content: center; font-size: .75rem; font-weight: 700; flex-shrink: 0; margin-top: 1px; }
    .ok    { color: #4ade80; }
    hr     { border: none; border-top: 1px solid #1e293b; margin: 1.5rem 0; }
    ul     { margin: .5rem 0 0 1rem; padding: 0; }
    li     { margin: .3rem 0; color: #94a3b8; }
  </style>
</head>
<body>

<h1>Lucee Training App</h1>
<p class="meta">
  Engine: <code><cfoutput>#server.lucee.version#</cfoutput></code> &nbsp;·&nbsp;
  Port: <code>8888</code> &nbsp;·&nbsp;
  Time: <code><cfoutput>#timeFormat(now(), "HH:mm:ss")#</cfoutput></code> &nbsp;·&nbsp;
  <span class="ok">● live</span>
</p>

<div class="card">
  <h3>⚡ How to edit and run CFML</h3>
  <div class="step"><div class="num">1</div><div>Open the <strong>IDE tab</strong> and navigate to <code>/home/laborant/app/index.cfm</code></div></div>
  <div class="step"><div class="num">2</div><div>Edit the file and <strong>save</strong> — no compile step, no restart needed</div></div>
  <div class="step"><div class="num">3</div><div><strong>Refresh this tab</strong> — your changes appear instantly</div></div>
</div>

<div class="card">
  <h3>📁 File locations</h3>
  <ul>
    <li><code>/home/laborant/app/index.cfm</code> — this file (Lucee webroot)</li>
    <li><code>/home/laborant/app/server.json</code> — CommandBox server config</li>
    <li><code>/opt/coldfusion2025/cfusion/wwwroot/</code> — Adobe CF webroot (port 8500)</li>
  </ul>
</div>

<div class="card">
  <h3>🛠 Useful terminal commands</h3>
  <ul>
    <li><code>systemctl status lucee-server</code> — check server status</li>
    <li><code>sudo journalctl -u lucee-server -f</code> — follow logs</li>
    <li><code>sudo systemctl restart lucee-server</code> — restart if needed</li>
    <li><code>box server log</code> — CommandBox server log</li>
  </ul>
</div>

<div class="card">
  <h3>🔧 Administration (CLI)</h3>
  <p style="margin:0 0 .75rem;color:#94a3b8;font-size:.875rem">Lucee 7 is administered via the CommandBox CLI — no web UI. Run these in the <strong>Terminal</strong> tab:</p>
  <ul>
    <li><code>box cfconfig show</code> — show all current server settings</li>
    <li><code>box cfconfig set adminPassword=training</code> — change admin password</li>
    <li><code>box cfconfig export to=.CFConfig.json</code> — export config to file</li>
    <li><code>box cfconfig import from=.CFConfig.json</code> — apply config from file</li>
  </ul>
</div>

<hr>
<h3 style="color:#38bdf8;margin-bottom:.75rem">Quick CFML Reference</h3>
<cfscript>
  tags = [
    ["cfset",    "Set a variable: <cfset name = 'World'>"],
    ["cfoutput", "Output a variable: <cfoutput>##name##</cfoutput>"],
    ["cfif",     "Conditionals: <cfif x GT 0>...</cfif>"],
    ["cfloop",   "Loop over array/query/range"],
    ["cfquery",  "Run SQL: <cfquery datasource='training_db' name='q'>SELECT...</cfquery>"],
    ["cfdump",   "Inspect any variable: <cfdump var='##myVar##'>"],
    ["cfinclude","Include another file: <cfinclude template='header.cfm'>"],
    ["cffunction","Define a function in a CFC"]
  ];
</cfscript>
<table style="width:100%;border-collapse:collapse;font-size:.875rem">
  <tr style="border-bottom:1px solid #334155">
    <th style="text-align:left;padding:.4rem .75rem;color:#64748b;width:140px">Tag</th>
    <th style="text-align:left;padding:.4rem .75rem;color:#64748b">Purpose</th>
  </tr>
  <cfloop array="#tags#" index="t">
    <cfoutput>
    <tr style="border-bottom:1px solid ##1e293b">
      <td style="padding:.4rem .75rem"><code>#t[1]#</code></td>
      <td style="padding:.4rem .75rem;color:##94a3b8">#t[2]#</td>
    </tr>
    </cfoutput>
  </cfloop>
</table>

</body>
</html>
