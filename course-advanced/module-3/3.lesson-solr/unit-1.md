---
kind: unit

title: Apache Solr and Full-Text Search

name: apache-solr-advanced-search-unit-1
---

## Why full-text search matters

SQL `LIKE '%keyword%'` is not full-text search. It is a table scan with no relevance ranking, no stemming, and no typo tolerance. For any feature where users type natural language queries — help desk ticket search, knowledge base lookup, product catalogues — you need a dedicated search engine. ColdFusion ships with built-in Apache Solr integration.

::image-box
---
:src: __static__/solr-cf-architecture-v1.png
:alt: Architecture diagram — CF 2025 on the left with cfindex arrow pointing to a Solr index (cylinder labelled "Solr collection"), and cfsearch arrow pointing back to CF. A separate arrow from CF to "Solr REST API (port 8983)" shows the direct HTTP query path. On the right, a browser shows a search results page.
:max-width: 900px
---
_ColdFusion talks to Solr in two ways: via cfindex/cfsearch (native integration) and via the Solr REST API directly._
::

| Feature | Solr | SQL LIKE |
|---|---|---|
| Relevance ranking | ✅ tf-idf score | ❌ depends on table order |
| Stemming | ✅ "running" matches "run" | ❌ exact string only |
| Typo tolerance | ✅ fuzzy matching | ❌ exact match only |
| Speed on large datasets | ✅ inverted index | ❌ full table scan |
| Faceting / filtering | ✅ built-in | ❌ complex SQL needed |

::hint-box
---
:summary: Other full-text search options — how does Solr compare?
---
Solr is not the only choice. Here is how the main options compare, so you can make an informed decision for your own projects:

| Engine | Best for | Notes |
|---|---|---|
| **Apache Solr** | ColdFusion native integration, enterprise Java stacks | Built into CF — `cfindex`/`cfsearch` work out of the box. Based on Apache Lucene. Battle-tested since 2006. |
| **Elasticsearch** | Modern microservices, log analytics, Kibana dashboards | Also based on Lucene. REST-first API, massive ecosystem. More DevOps overhead than Solr. Call from CF via `cfhttp`. |
| **OpenSearch** | AWS environments, open-source Elasticsearch alternative | Amazon's fork of Elasticsearch 7.x. Same API — swap the URL. Fully managed on AWS. |
| **PostgreSQL FTS** | Apps already on PostgreSQL, smaller datasets | Built-in `tsvector`/`tsquery`. No separate service. Good enough for thousands of records; Solr wins at millions. |
| **MySQL FULLTEXT** | Apps already on MySQL, simple keyword search | `MATCH(col) AGAINST(query)` with `FULLTEXT` index. No ranking sophistication, no stemming config. |
| **Meilisearch** | Developer-friendly, typo-tolerant, fast setup | REST API only — no CF native tags. Excellent for small-to-medium datasets. Call via `cfhttp`. |
| **Typesense** | Similar to Meilisearch, open-source | Simpler than Solr/ES, very fast. REST API via `cfhttp`. |
| **SQLite FTS5** | Embedded apps, prototypes, no separate service | Available via Java SQLite JDBC driver from CF. Zero infrastructure. Limited scalability. |

**Why Solr for this course:**
ColdFusion ships with Solr pre-configured — `cfindex` and `cfsearch` abstract the REST API entirely. For production workloads at enterprise scale, many teams migrate to **Elasticsearch** or **OpenSearch** and call the REST API directly from CF, giving them the full feature set without the CF tag limitations. The direct REST API pattern you learn in section 6 of this lesson transfers directly to either of those engines.

::

::hint-box
---
:summary: How does Solr's inverted index work?
---
A traditional database stores rows — to search, it scans every row looking for a match. Solr stores an **inverted index**: a map from every word to the list of documents that contain it. When you search for "printer", Solr looks up "printer" in the index and gets back a list of matching document IDs instantly — no scanning.

This is the same structure used by Google, Elasticsearch, and every major search engine. The trade-off: indexing takes time and disk space, but queries are extremely fast regardless of dataset size.

**tf-idf** (term frequency — inverse document frequency) is Solr's default relevance score. A word that appears many times in a document (high tf) but rarely across all documents (high idf) gets a high score — it is a strong signal that the document is relevant to that term.
::

---

## 1. Verify Solr is running

Your lab environment has Apache Solr pre-installed and running on port **8983**.

**Activity — Terminal (dev):** Confirm Solr is up and list any existing collections:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8983/solr/
```

**Expected output:** `200`

```bash
curl -s "http://localhost:8983/solr/admin/collections?action=LIST&wt=json" \
  | python3 -m json.tool
```

**Expected output** — a JSON object with a `collections` array (may be empty on first boot):

```json
{
  "responseHeader": { "status": 0, "QTime": 3 },
  "collections": []
}
```

The task below turns green automatically once Solr returns HTTP 200.

::simple-task
---
:tasks: tasks
:name: verify_solr_running
---
#active
Runs automatically — verifies Solr is responding on port 8983.

#completed
Solr is running on port 8983. ✓
::

---

## 2. Create a Solr collection

A **collection** is Solr's equivalent of a database table — it holds indexed documents for one domain (tickets, articles, products, etc.).

**Activity — Terminal (dev):** Create the `training` collection:

```bash
curl -s "http://localhost:8983/solr/admin/collections?action=CREATE&name=training&numShards=1&replicationFactor=1&wt=json" \
  | python3 -m json.tool
```

**Expected output:**

```json
{
  "responseHeader": { "status": 0, "QTime": 842 },
  "success": { ... }
}
```

`"status": 0` means success. Any other status code means the collection already exists or Solr had an error — check the message field.

Verify the collection was created:

```bash
curl -s "http://localhost:8983/solr/admin/collections?action=LIST&wt=json" \
  | python3 -m json.tool
```

**Expected output:**

```json
{
  "collections": ["training"]
}
```

The task below turns green automatically once a collection named `training` exists.

::simple-task
---
:tasks: tasks
:name: verify_collection_exists
---
#active
Runs automatically — verifies a Solr collection named `training` exists.

#completed
Solr collection exists. ✓
::

---

## 3. Register the collection in CF Admin

Before `cfindex` and `cfsearch` can use a Solr collection, ColdFusion must know about it. Use `cfcollection` to register it.

**Activity — Terminal (dev):** Create `register_collection.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/register_collection.cfm << 'EOF'
<cfcollection
  action     = "map"
  collection = "training"
  engine     = "solr"
  path       = "http://localhost:8983/solr/training">

<cfoutput>Collection "training" registered with ColdFusion ✓</cfoutput>
EOF
```

Run it:

```bash
curl -s http://localhost:8500/register_collection.cfm
```

**Expected output:**

```
Collection "training" registered with ColdFusion ✓
```

::hint-box
---
:summary: What does cfcollection action="map" actually do?
---
ColdFusion maintains its own internal registry of search collections in the CF Admin. `cfcollection action="map"` tells CF where to find an existing Solr collection — its URL and engine type. Without this step, `cfindex` and `cfsearch` will throw an error saying the collection does not exist, even though it is perfectly healthy in Solr.

You only need to run this once per CF server. After that, the mapping persists across CF restarts.
::

---

## 4. Index records with cfindex

`cfindex` pushes records from a CF query into a Solr collection. It maps query columns to Solr document fields.

::image-box
---
:src: __static__/cfindex-mapping-v1.png
:alt: Side-by-side diagram — left shows a CF query result set with columns id, title, description, and a cfindex tag; right shows a Solr document with fields _uniquekey (from id), _title (from title), and _body (from description), with arrows showing the field mapping
:max-width: 860px
---
_cfindex maps CF query columns to Solr document fields: key → _uniquekey, title → _title, body → _body._
::

**Activity — Terminal (dev):** Create `index_tickets.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/index_tickets.cfm << 'EOF'
<cfscript>
  // Fetch open tickets from the database
  tickets = queryExecute(
    "SELECT id, title, description FROM hd_tickets WHERE status != 'closed'",
    {},
    { datasource: "training_db" }
  );

  if (tickets.recordCount == 0) {
    writeOutput("No tickets to index — seed the database first.");
    abort;
  }
</cfscript>

<!--- Push all tickets into the "training" Solr collection --->
<cfindex
  collection = "training"
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
curl -s http://localhost:8500/index_tickets.cfm
```

**Expected output:**

```
Indexed 3 tickets into Solr ✓
```

The number will match however many open tickets are in `hd_tickets`. If you see `No tickets to index`, run `seed-db.cfm` first:

```bash
curl -s http://localhost:8500/seed-db.cfm
```

::hint-box
---
:summary: cfindex action types — refresh vs update vs delete
---
| Action | What it does |
|---|---|
| `refresh` | Re-indexes the entire query — replaces all existing documents for this collection |
| `update` | Adds or updates individual documents (use for incremental indexing) |
| `delete` | Removes documents matching the `key` value |
| `purge` | Deletes **all** documents from the collection |

For a full re-index (e.g. nightly batch job), use `refresh`. For real-time updates when a ticket is edited, use `update` with just that ticket's `id`.
::

---

## 5. Search with cfsearch

`cfsearch` queries a Solr collection and returns a CF query object with the results, relevance scores, and URLs.

**Activity — Terminal (dev):** Create `search.cfm`:

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
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Ticket Search</title>
  <style>
    body { font-family: sans-serif; max-width: 760px; margin: 2rem auto; }
    .result { margin-bottom: 1.5rem; border-bottom: 1px solid #e5e7eb; padding-bottom: 1rem; }
    .score  { color: #6b7280; font-size: .85rem; }
  </style>
</head>
<body>
  <h2>Search Tickets</h2>
  <form method="get">
    <input type="text" name="q"
           value="<cfoutput>#htmlEditFormat(url.q)#</cfoutput>"
           size="40" placeholder="e.g. printer, VPN, password">
    <button type="submit">Search</button>
  </form>

  <cfif isDefined("results")>
    <p><strong>
      <cfoutput>#results.recordCount# result(s) for "#htmlEditFormat(url.q)#"</cfoutput>
    </strong></p>

    <cfoutput query="results">
      <div class="result">
        <a href="#results.url#">#results.title#</a>
        <span class="score"> — relevance score: #numberFormat(results.score,"0.00")#</span>
        <p>#results.summary#</p>
      </div>
    </cfoutput>
  </cfif>
</body>
</html>
EOF
```

Test the full search flow:

```bash
# Step 1 — make sure tickets are indexed
curl -s http://localhost:8500/index_tickets.cfm

# Step 2 — search for "printer"
curl -s "http://localhost:8500/search.cfm?q=printer" | grep -o "<a href[^>]*>[^<]*"
```

**Expected output** — one or more anchor tags from the results:

```
<a href="http://localhost:8500/tickets.cfm?id=1">Printer not working
```

The task below turns green automatically once `search.cfm` returns HTTP 200.

::simple-task
---
:tasks: tasks
:name: verify_search_page
---
#active
Runs automatically — verifies `search.cfm` exists and returns HTTP 200.

#completed
search.cfm is accessible. ✓
::

---

## 6. Direct Solr REST API from CFML

For advanced queries — faceting, field boosting, highlighting, geographic filters — bypass `cfsearch` and call the Solr REST API directly with `cfhttp`:

**Activity — Terminal (dev):** Create `search_api.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/search_api.cfm << 'EOF'
<cfscript>
  q = encodeForURL(url.q ?: "*:*");

  cfhttp(
    url    = "http://localhost:8983/solr/training/select?q=#q#&wt=json&rows=10&fl=id,title,score",
    method = "GET",
    result = "resp"
  );

  data = deserializeJSON(resp.fileContent);

  writeOutput("<p>Found: " & data.response.numFound & " documents</p>");
  for (doc in data.response.docs) {
    writeOutput(doc.id & ": " & (doc.title[1] ?: "untitled")
              & " (score: " & numberFormat(doc.score, "0.00") & ")<br>");
  }
</cfscript>
EOF
```

Test it:

```bash
curl -s "http://localhost:8500/search_api.cfm?q=printer"
```

**Expected output:**

```
Found: 1 documents
1: Printer not working (score: 0.53)
```

::hint-box
---
:summary: cfindex/cfsearch vs direct Solr REST API — when to use each
---
| Scenario | Use |
|---|---|
| Simple full-text search on CF query data | `cfindex` + `cfsearch` |
| Faceted navigation (filter by category, date, etc.) | Solr REST API |
| Field boosting (title matches rank higher than body) | Solr REST API with `qf` parameter |
| Search result highlighting (bold the matched term) | Solr REST API with `hl=true` |
| Geographic/spatial search | Solr REST API with spatial fields |
| Incremental real-time indexing | `cfindex action="update"` |

Both approaches can coexist — use `cfindex` to populate the collection, use the REST API for complex queries.
::

---

## Key concepts reference

| Concept | Detail |
|---|---|
| Create collection | `curl .../solr/admin/collections?action=CREATE&name=training&numShards=1` |
| Register with CF | `<cfcollection action="map" collection="training" engine="solr" path="http://localhost:8983/solr/training">` |
| Full re-index | `<cfindex action="refresh" type="custom" query="q" key="id" title="col" body="col">` |
| Incremental update | `<cfindex action="update" ...>` |
| Search | `<cfsearch collection="training" name="results" criteria="keyword" maxrows="20">` |
| Result fields | `results.title`, `results.url`, `results.score`, `results.summary` |
| Direct REST query | `GET /solr/training/select?q=keyword&wt=json&rows=10` |
| Relevance score | tf-idf — higher score = more relevant |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all previous tasks pass.

#completed
Solr lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"If you have data, you have opportunity. If you can search it, you have power."*
> — attributed to various data engineers

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.solr-search-7ec1ea17
---
::
