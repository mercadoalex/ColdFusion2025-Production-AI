---
kind: unit

title: Apache Solr and Full-Text Search

name: apache-solr-advanced-search-unit-1
---

## Why full-text search matters

SQL `LIKE '%keyword%'` is not full-text search. It's a table scan with no relevance ranking, no stemming, no typo tolerance. For any feature where users type natural language queries — help desk ticket search, knowledge base lookup, product catalogues — you need a dedicated search engine. ColdFusion ships with built-in Apache Solr integration.

::image-box
---
:src: __static__/solr-cf-architecture-v1.png
:alt: Architecture diagram — CF 2025 on the left with cfindex arrow pointing to a Solr index (cylinder labelled "Solr collection"), and cfsearch arrow pointing back to CF. A separate arrow from CF to "Solr REST API (port 8983)" shows the direct HTTP query path. On the right, a browser shows a search results page.
:max-width: 900px
---
_ColdFusion talks to Solr in two ways: via cfindex/cfsearch (native integration) and via the Solr REST API directly._
::

| Solr vs SQL LIKE | Solr | SQL LIKE |
|---|---|---|
| Relevance ranking | ✅ tf-idf score | ❌ order depends on table |
| Stemming | ✅ "running" matches "run" | ❌ exact string only |
| Typo tolerance | ✅ fuzzy matching | ❌ exact match only |
| Speed on large datasets | ✅ inverted index | ❌ full table scan |
| Faceting / filtering | ✅ built-in | ❌ complex SQL needed |

---

## 1. Verify Solr is running

Your lab environment has Apache Solr pre-installed and running on port **8983**.

**Activity:** In the **Terminal (dev)** tab:

```bash
# Check the Solr admin UI
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8983/solr/
# Expected: 200

# List existing collections
curl -s "http://localhost:8983/solr/admin/collections?action=LIST&wt=json" \
  | python3 -m json.tool
```

::simple-task
---
:tasks: tasks
:name: verify_solr_running
---
#active
Confirm Solr is running at `http://localhost:8983/solr/` and returns HTTP 200.

#completed
Solr is running on port 8983. ✓
::

---

## 2. Create a Solr collection

A **collection** is Solr's equivalent of a database table — it holds indexed documents for one domain (e.g., tickets, articles, users).

```bash
# Create a collection named "training" with a default schema
curl -s "http://localhost:8983/solr/admin/collections?action=CREATE&name=training&numShards=1&replicationFactor=1&wt=json" \
  | python3 -m json.tool

# Verify it was created
curl -s "http://localhost:8983/solr/admin/collections?action=LIST&wt=json"
```

::simple-task
---
:tasks: tasks
:name: verify_collection_exists
---
#active
Create a Solr collection named `training` (or `students`).

#completed
Solr collection exists. ✓
::

---

## 3. Index ColdFusion records with cfindex

`<cfindex>` pushes records from a CF query into a Solr collection. It maps query columns to Solr document fields.

::image-box
---
:src: __static__/cfindex-mapping-v1.png
:alt: Side-by-side diagram — left shows a CF query result set with columns id, title, description, and a cfindex tag; right shows a Solr document with fields _uniquekey (from id), _title (from title), and _body (from description), with arrows showing the field mapping
:max-width: 860px
---
_cfindex maps CF query columns to Solr document fields: key → _uniquekey, title → _title, body → _body._
::

**Activity:** Create `index_tickets.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/index_tickets.cfm << 'EOF'
<cfscript>
  // Fetch tickets from the database
  tickets = queryExecute(
    "SELECT id, title, description FROM hd_tickets WHERE status != 'closed'",
    {}, { datasource: "training_db" }
  );

  if (tickets.recordCount == 0) {
    writeOutput("No tickets to index");
    abort;
  }
</cfscript>

<!--- Index all tickets into the "training" Solr collection --->
<cfindex
  collection = "training"
  action     = "refresh"
  type       = "custom"
  query      = "tickets"
  key        = "id"
  title      = "title"
  body       = "description"
  urlpath    = "http://localhost:8500/tickets.cfm?id=">

<cfoutput>Indexed #tickets.recordCount# tickets ✓</cfoutput>
```

```bash
curl -s http://localhost:8500/index_tickets.cfm
```

---

## 4. Search with cfsearch

`<cfsearch>` queries a Solr collection and returns a CF query object with the results, relevance scores, and URLs.

**Activity:** Create `search.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/search.cfm << 'EOF'
<cfparam name="url.q" default="">

<cfif len(trim(url.q))>
  <cfsearch
    collection = "training"
    name       = "results"
    criteria   = "#url.q#"
    maxrows    = 20
    startrow   = 1>
</cfif>
<!DOCTYPE html>
<html>
<head><title>Ticket Search</title></head>
<body>
  <h2>Search Tickets</h2>
  <form method="get">
    <input type="text" name="q" value="<cfoutput>#htmlEditFormat(url.q)#</cfoutput>" size="40">
    <button type="submit">Search</button>
  </form>

  <cfif isDefined("results")>
    <p><strong><cfoutput>#results.recordCount#</cfoutput> result(s) for "<cfoutput>#htmlEditFormat(url.q)#</cfoutput>"</strong></p>
    <cfoutput query="results">
      <div style="margin-bottom:1em">
        <a href="#results.url#">#results.title#</a>
        <span style="color:gray"> — score: #numberFormat(results.score,"0.00")#</span>
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
# Index first, then search
curl -s http://localhost:8500/index_tickets.cfm
curl -s "http://localhost:8500/search.cfm?q=printer" | grep -o "<a href[^>]*>[^<]*"
```

::simple-task
---
:tasks: tasks
:name: verify_search_page
---
#active
Create `search.cfm` that uses `<cfsearch>` and returns HTTP 200.

#completed
search.cfm is accessible. ✓
::

---

## 5. Direct Solr REST API from CFML

For advanced queries (faceting, boosting, complex filters), bypass `cfsearch` and call the Solr REST API directly:

```cfml
<cfscript>
  q = encodeForURL(url.q ?: "*:*");

  cfhttp(
    url    = "http://localhost:8983/solr/training/select?q=#q#&wt=json&rows=20&fl=id,title,score",
    method = "GET",
    result = "resp"
  );

  data = deserializeJSON(resp.fileContent);
  docs = data.response.docs;

  for (doc in docs) {
    writeOutput(doc.id & ": " & doc.title & " (score: " & doc.score & ")<br>");
  }
</cfscript>
```

::hint-box
---
:summary: cfindex vs direct Solr REST — which to use?
---
- **Use cfindex/cfsearch** for straightforward full-text search on CF query results. Simple to configure, handles the Solr connection details for you.
- **Use the Solr REST API directly** when you need facets, field boosting, geographic queries, highlighting, or any advanced Solr feature not exposed through the CF tags.

Both approaches can coexist in the same application.
::

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Create collection | `curl .../solr/admin/collections?action=CREATE&name=...` |
| Index records | `<cfindex collection="name" action="refresh" type="custom" query="q" key="id" title="col" body="col">` |
| Search | `<cfsearch collection="name" name="results" criteria="query" maxrows="20">` |
| Direct query | `GET /solr/training/select?q=keyword&wt=json` |
| Result fields | `results.title`, `results.url`, `results.score`, `results.summary` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Solr is running, collection exists, and search.cfm is accessible — hit **Check** to complete.

#completed
Solr lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.solr-search-7ec1ea17
---
::
