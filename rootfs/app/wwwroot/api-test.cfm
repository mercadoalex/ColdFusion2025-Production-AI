<!---
  api-test.cfm — Interactive REST API Console
  Tests the /api/tickets.cfm endpoint with live curl commands and responses.
--->
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>API Console — Help Desk Tickets</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, "Segoe UI", system-ui, sans-serif;
    background: #0f172a; color: #e2e8f0; min-height: 100vh;
    padding: 2rem 1rem;
  }
  .container { max-width: 860px; margin: 0 auto; }
  header { border-bottom: 1px solid #1e293b; padding-bottom: 1.5rem; margin-bottom: 2rem; }
  header h1 { font-size: 1.5rem; color: #f8fafc; }
  header p  { color: #94a3b8; margin-top: .35rem; font-size: .9rem; }
  .badge {
    display: inline-block; padding: .15rem .55rem; border-radius: 4px;
    font-size: .75rem; font-weight: 600; letter-spacing: .04em;
  }
  .get    { background: #166534; color: #bbf7d0; }
  .post   { background: #1e3a5f; color: #bfdbfe; }
  .delete { background: #7f1d1d; color: #fecaca; }

  .endpoint {
    background: #1e293b; border: 1px solid #334155; border-radius: 8px;
    margin-bottom: 1.5rem; overflow: hidden;
  }
  .ep-header {
    display: flex; align-items: center; gap: .75rem;
    padding: .9rem 1.2rem; cursor: pointer;
    user-select: none;
  }
  .ep-header:hover { background: #263348; }
  .ep-url  { font-family: "SF Mono", Consolas, monospace; font-size: .88rem; color: #e2e8f0; }
  .ep-desc { margin-left: auto; color: #64748b; font-size: .82rem; }
  .ep-body { border-top: 1px solid #334155; padding: 1.2rem; display: none; }
  .ep-body.open { display: block; }

  label   { display: block; font-size: .8rem; color: #94a3b8; margin-bottom: .3rem; }
  input, textarea {
    width: 100%; background: #0f172a; border: 1px solid #334155; border-radius: 5px;
    color: #e2e8f0; padding: .5rem .7rem; font-family: "SF Mono", Consolas, monospace;
    font-size: .83rem; margin-bottom: .9rem; resize: vertical;
  }
  input:focus, textarea:focus { outline: none; border-color: #3b82f6; }
  textarea { min-height: 90px; }

  button.run {
    background: #3b82f6; color: #fff; border: none; border-radius: 5px;
    padding: .5rem 1.1rem; font-size: .85rem; cursor: pointer; font-weight: 600;
  }
  button.run:hover { background: #2563eb; }
  button.run:active { background: #1d4ed8; }

  .response { margin-top: 1rem; display: none; }
  .response.show { display: block; }
  .res-meta {
    display: flex; gap: 1rem; align-items: center;
    font-size: .8rem; color: #64748b; margin-bottom: .5rem;
  }
  .status-ok  { color: #4ade80; font-weight: 700; }
  .status-err { color: #f87171; font-weight: 700; }
  pre.body {
    background: #0f172a; border: 1px solid #334155; border-radius: 5px;
    padding: .8rem; font-size: .8rem; overflow-x: auto; white-space: pre-wrap;
    color: #a5f3fc; max-height: 380px; overflow-y: auto;
  }
  .curl-box {
    background: #0f172a; border: 1px solid #1e293b; border-radius: 5px;
    padding: .6rem .9rem; font-family: "SF Mono", Consolas, monospace;
    font-size: .78rem; color: #94a3b8; margin-bottom: 1rem; word-break: break-all;
  }
  .curl-label { font-size: .72rem; color: #475569; margin-bottom: .3rem; }
  .section-title {
    font-size: .75rem; font-weight: 700; text-transform: uppercase;
    letter-spacing: .08em; color: #475569; margin-bottom: .7rem;
  }
  hr.sep { border: none; border-top: 1px solid #1e293b; margin: 1rem 0; }
</style>
</head>
<body>
<div class="container">

  <header>
    <h1>🎫 Help Desk API Console</h1>
    <p>Live REST endpoint: <code>/api/tickets.cfm</code> &nbsp;·&nbsp; Powered by Adobe ColdFusion 2025</p>
  </header>

  <!--- ── GET /api/tickets.cfm ──────────────────────────────────────────── --->
  <div class="endpoint" id="ep-list">
    <div class="ep-header" onclick="toggle('ep-list')">
      <span class="badge get">GET</span>
      <span class="ep-url">/api/tickets.cfm</span>
      <span class="ep-desc">List all tickets</span>
    </div>
    <div class="ep-body" id="ep-list-body">
      <p class="section-title">Try it</p>
      <div class="curl-label">Equivalent curl command</div>
      <div class="curl-box">curl -s http://localhost:8500/api/tickets.cfm | python3 -m json.tool</div>
      <button class="run" onclick="runRequest('GET','/api/tickets.cfm',null,'list')">▶ Send</button>
      <div class="response" id="res-list">
        <div class="res-meta">
          <span>HTTP <span id="status-list"></span></span>
          <span id="time-list"></span>
        </div>
        <pre class="body" id="body-list"></pre>
      </div>
    </div>
  </div>

  <!--- ── GET /api/tickets.cfm?id=N ────────────────────────────────────── --->
  <div class="endpoint" id="ep-get">
    <div class="ep-header" onclick="toggle('ep-get')">
      <span class="badge get">GET</span>
      <span class="ep-url">/api/tickets.cfm?id={id}</span>
      <span class="ep-desc">Get one ticket + comments</span>
    </div>
    <div class="ep-body" id="ep-get-body">
      <p class="section-title">Parameters</p>
      <label>Ticket ID</label>
      <input type="number" id="get-id" value="1" min="1">
      <div class="curl-label">Equivalent curl command</div>
      <div class="curl-box" id="curl-get">curl -s "http://localhost:8500/api/tickets.cfm?id=1"</div>
      <button class="run" onclick="runGetOne()">▶ Send</button>
      <div class="response" id="res-get">
        <div class="res-meta">
          <span>HTTP <span id="status-get"></span></span>
          <span id="time-get"></span>
        </div>
        <pre class="body" id="body-get"></pre>
      </div>
    </div>
  </div>

  <!--- ── POST /api/tickets.cfm ────────────────────────────────────────── --->
  <div class="endpoint" id="ep-post">
    <div class="ep-header" onclick="toggle('ep-post')">
      <span class="badge post">POST</span>
      <span class="ep-url">/api/tickets.cfm</span>
      <span class="ep-desc">Create a new ticket</span>
    </div>
    <div class="ep-body" id="ep-post-body">
      <p class="section-title">Request Body (JSON)</p>
      <label>JSON Payload</label>
      <textarea id="post-body">{
  "title": "Printer not working on 3rd floor",
  "description": "The HP LaserJet has been offline since this morning.",
  "user_id": 2,
  "priority": "high"
}</textarea>
      <div class="curl-label">Equivalent curl command</div>
      <div class="curl-box">curl -s -X POST http://localhost:8500/api/tickets.cfm \<br>&nbsp; -H "Content-Type: application/json" \<br>&nbsp; -d '{"title":"Printer not working","priority":"high","user_id":2}'</div>
      <button class="run" onclick="runPost()">▶ Send</button>
      <div class="response" id="res-post">
        <div class="res-meta">
          <span>HTTP <span id="status-post"></span></span>
          <span id="time-post"></span>
        </div>
        <pre class="body" id="body-post"></pre>
      </div>
    </div>
  </div>

  <!--- ── DELETE /api/tickets.cfm?id=N ─────────────────────────────────── --->
  <div class="endpoint" id="ep-del">
    <div class="ep-header" onclick="toggle('ep-del')">
      <span class="badge delete">DELETE</span>
      <span class="ep-url">/api/tickets.cfm?id={id}</span>
      <span class="ep-desc">Close a ticket</span>
    </div>
    <div class="ep-body" id="ep-del-body">
      <p class="section-title">Parameters</p>
      <label>Ticket ID to close</label>
      <input type="number" id="del-id" value="1" min="1">
      <div class="curl-label">Equivalent curl command</div>
      <div class="curl-box" id="curl-del">curl -s -X DELETE "http://localhost:8500/api/tickets.cfm?id=1"</div>
      <button class="run" onclick="runDelete()">▶ Send</button>
      <div class="response" id="res-del">
        <div class="res-meta">
          <span>HTTP <span id="status-del"></span></span>
          <span id="time-del"></span>
        </div>
        <pre class="body" id="body-del"></pre>
      </div>
    </div>
  </div>

</div>

<script>
function toggle(id) {
  var body = document.getElementById(id + '-body');
  body.classList.toggle('open');
}

function setResponse(key, status, ms, json) {
  var el = document.getElementById('res-' + key);
  el.classList.add('show');
  var sEl = document.getElementById('status-' + key);
  sEl.textContent = status;
  sEl.className = (status >= 200 && status < 300) ? 'status-ok' : 'status-err';
  document.getElementById('time-' + key).textContent = ms + 'ms';
  try {
    document.getElementById('body-' + key).textContent = JSON.stringify(JSON.parse(json), null, 2);
  } catch(e) {
    document.getElementById('body-' + key).textContent = json;
  }
}

function runRequest(method, url, body, key) {
  var t0 = Date.now();
  var opts = { method: method, headers: {} };
  if (body) { opts.headers['Content-Type'] = 'application/json'; opts.body = body; }
  fetch(url, opts)
    .then(function(r) {
      var status = r.status;
      return r.text().then(function(t) { setResponse(key, status, Date.now()-t0, t); });
    })
    .catch(function(e) { setResponse(key, 0, Date.now()-t0, 'Fetch error: '+e.message); });
}

function runGetOne() {
  var id = document.getElementById('get-id').value || 1;
  document.getElementById('curl-get').textContent =
    'curl -s "http://localhost:8500/api/tickets.cfm?id=' + id + '"';
  runRequest('GET', '/api/tickets.cfm?id=' + id, null, 'get');
}

function runPost() {
  var body = document.getElementById('post-body').value;
  runRequest('POST', '/api/tickets.cfm', body, 'post');
}

function runDelete() {
  var id = document.getElementById('del-id').value || 1;
  document.getElementById('curl-del').textContent =
    'curl -s -X DELETE "http://localhost:8500/api/tickets.cfm?id=' + id + '"';
  runRequest('DELETE', '/api/tickets.cfm?id=' + id, null, 'del');
}

// auto-open first panel
document.getElementById('ep-list-body').classList.add('open');
</script>
</body>
</html>
