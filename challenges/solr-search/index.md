---
kind: challenge

title: 'Index and Search Help Desk Tickets with Apache Solr'

description: |
  Create a Solr collection, register it with ColdFusion, index help desk
  tickets from the database using cfindex, and build a search page with
  cfsearch that returns ranked results.

categories:
  - programming

tagz:
  - coldfusion
  - solr
  - search

difficulty: hard

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  collection_created:
    machine: cf-dev
    user: laborant
    run: |
      BODY=$(curl -s --max-time 15 "http://localhost:8983/solr/admin/collections?action=LIST&wt=json" 2>/dev/null)
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'helpdesk' in d.get('collections',[])" 2>/dev/null; then
        echo "Solr collection 'helpdesk' not found"
        echo "Run: curl -s 'http://localhost:8983/solr/admin/collections?action=CREATE&name=helpdesk&numShards=1&replicationFactor=1&wt=json'"
        exit 1
      fi
      echo "Solr collection 'helpdesk' exists ✓"
    hintcheck: |
      echo "Create the collection with:"
      echo "  curl -s 'http://localhost:8983/solr/admin/collections?action=CREATE&name=helpdesk&numShards=1&replicationFactor=1&wt=json'"
      echo "Verify: curl -s 'http://localhost:8983/solr/admin/collections?action=LIST&wt=json' | python3 -m json.tool"

  tickets_indexed:
    machine: cf-dev
    user: laborant
    needs:
      - collection_created
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/index_helpdesk.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "index_helpdesk.cfm not found at ${FILE}"
        exit 1
      fi
      BODY=$(curl -s --max-time 60 http://localhost:8500/index_helpdesk.cfm 2>/dev/null)
      if ! echo "${BODY}" | grep -qi "indexed\|records\|documents\|tickets"; then
        echo "index_helpdesk.cfm did not confirm indexing — response: ${BODY}"
        exit 1
      fi
      echo "Tickets indexed into helpdesk collection ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/index_helpdesk.cfm using cfindex:"
      echo "  <cfindex collection=\"helpdesk\" action=\"refresh\" type=\"custom\""
      echo "           query=\"tickets\" key=\"id\" title=\"title\" body=\"description\">"
      echo "Then run: curl -s http://localhost:8500/index_helpdesk.cfm"

  search_returns_results:
    machine: cf-dev
    user: laborant
    needs:
      - tickets_indexed
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/helpdesk_search.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "helpdesk_search.cfm not found at ${FILE}"
        exit 1
      fi
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8500/helpdesk_search.cfm?q=email" 2>/dev/null)
      if [ "${STATUS}" != "200" ]; then
        echo "helpdesk_search.cfm?q=email returned HTTP ${STATUS}"
        exit 1
      fi
      BODY=$(curl -s "http://localhost:8500/helpdesk_search.cfm?q=email" 2>/dev/null)
      if echo "${BODY}" | grep -qi "0 result\|no results\|error\|exception"; then
        echo "Search for 'email' returned 0 results or an error — check indexing"
        exit 1
      fi
      echo "helpdesk_search.cfm returns results for 'email' ✓"
    hintcheck: |
      echo "Create /opt/coldfusion2025/cfusion/wwwroot/helpdesk_search.cfm using cfsearch:"
      echo "  <cfsearch collection=\"helpdesk\" name=\"results\" criteria=\"#url.q#\" maxrows=\"20\">"
      echo "Then test: curl -s 'http://localhost:8500/helpdesk_search.cfm?q=email'"
---

## Index and Search Help Desk Tickets with Apache Solr

Build the complete Solr search pipeline for the help desk: create a collection, index all tickets from the database, and expose a search page backed by `cfsearch`.

All commands run on the **Terminal (dev)** tab.

---

### Task 1 — Create the helpdesk Solr collection

```bash
curl -s "http://localhost:8983/solr/admin/collections?action=CREATE&name=helpdesk&numShards=1&replicationFactor=1&wt=json" \
  | python3 -m json.tool
```

Expected: `"status": 0` in the response. Then register the collection with ColdFusion so `cfindex` and `cfsearch` can use it:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/register_helpdesk.cfm << 'EOF'
<cfcollection
  action     = "map"
  collection = "helpdesk"
  engine     = "solr"
  path       = "http://localhost:8983/solr/helpdesk">
<cfoutput>Collection "helpdesk" registered ✓</cfoutput>
EOF

curl -s http://localhost:8500/register_helpdesk.cfm
```

::simple-task
---
:tasks: tasks
:name: collection_created
---
#active
Create a Solr collection named `helpdesk` and confirm it appears in the collections list.

#completed
Solr collection 'helpdesk' exists. ✓
::

---

### Task 2 — Index all tickets with cfindex

Create `/opt/coldfusion2025/cfusion/wwwroot/index_helpdesk.cfm` that queries `hd_tickets` and pushes every record into the `helpdesk` collection:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/index_helpdesk.cfm << 'EOF'
<cfscript>
  tickets = queryExecute(
    "SELECT id, title, description FROM hd_tickets",
    {},
    { datasource: "training_db" }
  );

  if (tickets.recordCount == 0) {
    writeOutput("No tickets found — run seed-db.cfm first.");
    abort;
  }
</cfscript>

<cfindex
  collection = "helpdesk"
  action     = "refresh"
  type       = "custom"
  query      = "tickets"
  key        = "id"
  title      = "title"
  body       = "description"
  urlpath    = "http://localhost:8500/tickets.cfm?id=">

<cfoutput>Indexed #tickets.recordCount# tickets into Solr ✓</cfoutput>
EOF
```

Run it:

```bash
curl -s http://localhost:8500/index_helpdesk.cfm
```

Expected: `Indexed 3 tickets into Solr ✓` (count depends on seeded data). If you see "No tickets found", seed the database first: `curl -s http://localhost:8500/seed-db.cfm`

::simple-task
---
:tasks: tasks
:name: tickets_indexed
---
#active
Create `index_helpdesk.cfm` using `cfindex` and confirm it outputs a confirmation message with the record count.

#completed
Tickets indexed into helpdesk collection. ✓
::

---

### Task 3 — Build the search page with cfsearch

Create `/opt/coldfusion2025/cfusion/wwwroot/helpdesk_search.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/helpdesk_search.cfm << 'EOF'
<cfparam name="url.q" default="">

<cfif len(trim(url.q))>
  <cfsearch
    collection = "helpdesk"
    name       = "results"
    criteria   = "#url.q#"
    maxrows    = 20
    startrow   = 1>
</cfif>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Help Desk Search</title>
  <style>
    body { font-family: sans-serif; max-width: 760px; margin: 2rem auto; }
    .result { margin-bottom: 1.5rem; border-bottom: 1px solid #e5e7eb; padding-bottom: 1rem; }
    .score  { color: #6b7280; font-size: .85rem; }
  </style>
</head>
<body>
  <h2>Search Help Desk Tickets</h2>
  <form method="get">
    <input type="text" name="q"
           value="<cfoutput>#htmlEditFormat(url.q)#</cfoutput>"
           size="40" placeholder="e.g. printer, email, VPN">
    <button type="submit">Search</button>
  </form>

  <cfif isDefined("results")>
    <p><strong>
      <cfoutput>#results.recordCount# result(s) for "#htmlEditFormat(url.q)#"</cfoutput>
    </strong></p>

    <cfoutput query="results">
      <div class="result">
        <a href="#results.url#">#results.title#</a>
        <span class="score"> — score: #numberFormat(results.score,"0.00")#</span>
        <p>#results.summary#</p>
      </div>
    </cfoutput>
  </cfif>
</body>
</html>
EOF
```

Test it:

```bash
curl -s "http://localhost:8500/helpdesk_search.cfm?q=email" | grep -o "<a href[^>]*>[^<]*"
```

Expected: one or more ticket titles as anchor links.

::simple-task
---
:tasks: tasks
:name: search_returns_results
---
#active
Create `helpdesk_search.cfm` using `cfsearch` and confirm searching for `?q=email` returns at least one result.

#completed
helpdesk_search.cfm returns results for 'email'. ✓
::
