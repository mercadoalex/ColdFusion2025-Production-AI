<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ColdFusion Status</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, "Segoe UI", system-ui, sans-serif;
      background: #0f172a;
      color: #e2e8f0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 2rem;
    }
    .card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 12px;
      padding: 2rem 2.5rem;
      max-width: 680px;
      width: 100%;
    }
    h1 { font-size: 1.4rem; color: #f1f5f9; margin-bottom: 1.5rem; display: flex; align-items: center; gap: .6rem; }
    .dot { width: 10px; height: 10px; border-radius: 50%; background: #22c55e; display: inline-block; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; }
    th { text-align: left; font-size: .7rem; color: #64748b; text-transform: uppercase; letter-spacing: .06em; padding: .4rem .6rem; border-bottom: 1px solid #334155; }
    td { padding: .55rem .6rem; font-size: .9rem; border-bottom: 1px solid #1e293b; }
    td:first-child { color: #94a3b8; width: 42%; }
    td:last-child { color: #38bdf8; font-family: monospace; }
    .section { font-size: .7rem; color: #64748b; text-transform: uppercase; letter-spacing: .06em; margin: 1.2rem 0 .5rem; }
    .ok   { color: #22c55e; }
    .warn { color: #f59e0b; }
    footer { margin-top: 1.5rem; font-size: .75rem; color: #475569; text-align: center; }
  </style>
</head>
<body>
<cfscript>
  // ── Application scope ──────────────────────────────────────────────────────
  appName    = application.applicationName ?: (isDefined("application.name") ? application.name : "—");
  startTime  = isDefined("application.startTime") ? dateTimeFormat(application.startTime, "yyyy-mm-dd HH:nn:ss") : "not set";

  // ── Session scope ──────────────────────────────────────────────────────────
  sessionEnabled = isSessionEnabled() ? "enabled" : "disabled";
  sessionUserId  = isDefined("session.userId") ? session.userId : "—";

  // ── Server info ────────────────────────────────────────────────────────────
  cfVersion  = server.coldfusion.productVersion;
  cfName     = server.coldfusion.productName;
  javaVer    = server.java.version;
  uptime     = server.os.name;

  // ── Memory (JVM) ──────────────────────────────────────────────────────────
  rt         = createObject("java", "java.lang.Runtime").getRuntime();
  totalMem   = int(rt.totalMemory() / 1024 / 1024);
  freeMem    = int(rt.freeMemory()  / 1024 / 1024);
  usedMem    = totalMem - freeMem;
  maxMem     = int(rt.maxMemory()   / 1024 / 1024);
</cfscript>

<div class="card">
  <h1><span class="dot"></span> ColdFusion 2025 — Server Status</h1>

  <p class="section">Engine</p>
  <table>
    <tr><th>Key</th><th>Value</th></tr>
    <cfoutput>
    <tr><td>Product</td>          <td>#cfName#</td></tr>
    <tr><td>Version</td>          <td>#cfVersion#</td></tr>
    <tr><td>Java Version</td>     <td>#javaVer#</td></tr>
    <tr><td>Server Name</td>      <td>#cgi.server_name#</td></tr>
    <tr><td>Server Time</td>      <td>#dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")#</td></tr>
    </cfoutput>
  </table>

  <p class="section">JVM Memory</p>
  <table>
    <cfoutput>
    <tr><th>Key</th><th>Value</th></tr>
    <tr><td>Used</td>   <td>#usedMem# MB</td></tr>
    <tr><td>Total</td>  <td>#totalMem# MB</td></tr>
    <tr><td>Max</td>    <td>#maxMem# MB</td></tr>
    </cfoutput>
  </table>

  <p class="section">Application Scope (Application.cfc)</p>
  <table>
    <cfoutput>
    <tr><th>Key</th><th>Value</th></tr>
    <tr><td>this.name</td>        <td>#appName#</td></tr>
    <tr><td>onApplicationStart</td><td><span class="#(startTime neq 'not set' ? 'ok' : 'warn')#">#(startTime neq 'not set' ? 'fired — ' & startTime : 'not fired yet')#</span></td></tr>
    <tr><td>Session management</td><td>#sessionEnabled#</td></tr>
    <tr><td>session.userId</td>   <td>#sessionUserId#</td></tr>
    </cfoutput>
  </table>
</div>

<footer>&copy; 2026 Hungry Minds &nbsp;&middot;&nbsp; Powered by Adobe ColdFusion 2025</footer>
</body>
</html>
