<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hungry Minds · ColdFusion Training</title>
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
    }
    footer {
      width: 100%;
      text-align: center;
      padding: .75rem 1rem;
      font-size: .75rem;
      color: #475569;
      border-top: 1px solid #1e293b;
      position: fixed;
      bottom: 0;
      left: 0;
      background: #0f172a;
    }
    footer a { color: #475569; text-decoration: none; }
    footer a:hover { color: #94a3b8; }
    .card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 12px;
      padding: 2.5rem 3rem;
      max-width: 700px;
      width: 90%;
    }
    .badge {
      display: inline-block;
      background: #1d4ed8;
      color: #bfdbfe;
      font-size: 0.7rem;
      font-weight: 700;
      letter-spacing: .08em;
      text-transform: uppercase;
      padding: .25rem .6rem;
      border-radius: 4px;
      margin-bottom: 1rem;
    }
    h1 { font-size: 1.8rem; color: #f1f5f9; margin-bottom: .5rem; }
    .subtitle { color: #94a3b8; font-size: .95rem; margin-bottom: 2rem; }
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: .75rem;
      margin-bottom: 2rem;
    }
    .info-item {
      background: #0f172a;
      border: 1px solid #1e3a5f;
      border-radius: 8px;
      padding: .75rem 1rem;
    }
    .info-label { font-size: .7rem; color: #64748b; text-transform: uppercase; letter-spacing: .06em; }
    .info-value { font-size: .95rem; color: #38bdf8; font-family: monospace; margin-top: .25rem; }
    .links { display: flex; gap: .75rem; flex-wrap: wrap; }
    .btn {
      display: inline-block;
      padding: .6rem 1.2rem;
      border-radius: 6px;
      font-size: .875rem;
      font-weight: 600;
      text-decoration: none;
      transition: opacity .15s;
    }
    .btn:hover { opacity: .85; }
    .btn-primary { background: #1d4ed8; color: #fff; }
    .btn-secondary { background: #1e293b; border: 1px solid #475569; color: #94a3b8; }
    .code-block {
      background: #0f172a;
      border: 1px solid #1e3a5f;
      border-radius: 6px;
      padding: 1rem;
      font-family: monospace;
      font-size: .85rem;
      color: #7dd3fc;
      margin-bottom: 2rem;
      overflow-x: auto;
    }
    .cf-tag { color: #f472b6; }
    .cf-attr { color: #a78bfa; }
    .cf-val { color: #34d399; }
    .cf-comment { color: #475569; font-style: italic; }
  </style>
</head>
<body>
  <div class="card">
    <span class="badge">Hungry Minds · ColdFusion Training</span>
    <h1>Hello from your Playground 👋</h1>
    <p class="subtitle">Your ColdFusion 2025 environment is running. Edit this file to start experimenting.</p>

    <div class="info-grid">
      <div class="info-item">
        <div class="info-label">CF Version</div>
        <div class="info-value"><cfoutput>#server.coldfusion.productVersion#</cfoutput></div>
      </div>
      <div class="info-item">
        <div class="info-label">Server Name</div>
        <div class="info-value"><cfoutput>#cgi.server_name#</cfoutput></div>
      </div>
      <div class="info-item">
        <div class="info-label">Timestamp</div>
        <div class="info-value"><cfoutput>#dateTimeFormat(now(), "HH:mm:ss")#</cfoutput></div>
      </div>
      <div class="info-item">
        <div class="info-label">Engine</div>
        <div class="info-value"><cfoutput>#server.coldfusion.productName#</cfoutput></div>
      </div>
    </div>

    <div class="code-block">
<span class="cf-comment">&lt;!--- This is your starter index.cfm ---&gt;</span>
<span class="cf-tag">&lt;cfset</span> <span class="cf-attr">greeting</span> = <span class="cf-val">"Hello, World!"</span> <span class="cf-tag">/&gt;</span>
<span class="cf-tag">&lt;cfoutput&gt;</span>
  #greeting# — <span class="cf-tag">&lt;cfoutput&gt;</span>#dateFormat(now())#<span class="cf-tag">&lt;/cfoutput&gt;</span>
<span class="cf-tag">&lt;/cfoutput&gt;</span>
    </div>

    <div class="links">
      <a class="btn btn-primary" href="/CFIDE/administrator/">CF Admin</a>
      <a class="btn btn-secondary" href="/status.cfm">Server Status</a>
      <a class="btn btn-secondary" href="/api-test.cfm">API Test</a>
      <a class="btn btn-secondary" href="/db-test.cfm">DB Test</a>
    </div>
  </div>

  <footer>
    &copy; 2026 Hungry Minds &nbsp;&middot;&nbsp; Course content by Alejandro Mercado &nbsp;&middot;&nbsp; Powered by Adobe ColdFusion 2025
  </footer>
</body>
</html>
