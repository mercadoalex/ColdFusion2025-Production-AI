---
kind: challenge

title: 'Index and Search Help Desk Tickets with Solr'

description: |
  Create a Solr collection, index the help desk tickets database into it,
  and build a search page that queries Solr and displays ranked results.

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
      BODY=$(curl -s "http://localhost:8983/solr/admin/collections?action=LIST&wt=json")
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'helpdesk' in d.get('collections',[])" 2>/dev/null; then
        echo "Solr collection 'helpdesk' not found — create it first"
        exit 1
      fi
      echo "helpdesk Solr collection exists ✓"

  tickets_indexed:
    machine: cf-dev
    user: laborant
    needs:
      - collection_created
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/index_helpdesk.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "index_helpdesk.cfm not found (got ${STATUS})"
        exit 1
      fi
      BODY=$(curl -s http://localhost:8500/index_helpdesk.cfm)
      if ! echo "${BODY}" | grep -qi "indexed\|records\|documents"; then
        echo "index_helpdesk.cfm did not confirm indexing"
        exit 1
      fi
      echo "Tickets indexed ✓"

  search_returns_results:
    machine: cf-dev
    user: laborant
    needs:
      - tickets_indexed
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8500/helpdesk_search.cfm?q=email")
      if [ "${STATUS}" != "200" ]; then
        echo "helpdesk_search.cfm not found (got ${STATUS})"
        exit 1
      fi
      BODY=$(curl -s "http://localhost:8500/helpdesk_search.cfm?q=email")
      if echo "${BODY}" | grep -qi "0 result\|no results"; then
        echo "Search for 'email' returned 0 results — check indexing"
        exit 1
      fi
      echo "Search returns results ✓"
---

## Index and Search Help Desk Tickets with Solr

### Step 1 — Create the Solr collection

```bash
curl -s "http://localhost:8983/solr/admin/collections?action=CREATE&name=helpdesk&numShards=1&replicationFactor=1"
```

### Step 2 — index_helpdesk.cfm

Create a page that queries `hd_tickets` and uses `<cfindex>` to push all tickets into the `helpdesk` collection.

### Step 3 — helpdesk_search.cfm

Create a search page that:
- Reads `url.q` as the search term
- Uses `<cfsearch collection="helpdesk">` to query
- Displays matching ticket titles with scores

::simple-task
---
:tasks: tasks
:name: collection_created
---
#active
Create a Solr collection named `helpdesk`.

#completed
helpdesk Solr collection exists. ✓
::

::simple-task
---
:tasks: tasks
:name: tickets_indexed
---
#active
Create `index_helpdesk.cfm` that indexes all tickets and confirms the count.

#completed
Tickets indexed. ✓
::

::simple-task
---
:tasks: tasks
:name: search_returns_results
---
#active
Create `helpdesk_search.cfm?q=email` that returns search results.

#completed
Search returns results. ✓
::
