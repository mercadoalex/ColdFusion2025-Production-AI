---
kind: lesson

title: Apache Solr and Advanced Search
description: |
  Integrate Apache Solr with ColdFusion for enterprise full-text search.
  Learn indexing, querying, faceting, and building powerful
  search experiences driven by Solr collections.

name: apache-solr-advanced-search
slug: apache-solr-advanced-search

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- solr
- search

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_solr_running:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8983/solr/)
      if [ "${STATUS}" != "200" ]; then
        echo "Solr is not running on port 8983 (got ${STATUS})"
        exit 1
      fi
      echo "Solr is running on port 8983"

  verify_collection_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_solr_running
    run: |
      BODY=$(curl -s "http://localhost:8983/solr/admin/collections?action=LIST")
      if ! echo "${BODY}" | grep -qi "students\|training"; then
        echo "No students/training Solr collection found"
        exit 1
      fi
      echo "Solr collection exists"

  verify_search_page:
    machine: cf-dev
    user: laborant
    needs:
      - verify_collection_exists
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/search.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "search.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "search.cfm is accessible"
---

## ColdFusion + Solr via cfindex / cfsearch

```cfml
<!--- index a collection --->
<cfindex
  collection = "students"
  action     = "refresh"
  type       = "custom"
  query      = "studentsQuery"
  title      = "name"
  body       = "bio"
  key        = "id"
  urlpath    = "http://localhost:8500/student.cfm?id=">
```

## Search a collection

```cfml
<cfsearch
  collection = "students"
  name       = "results"
  criteria   = "#form.q#"
  maxrows    = "20"
  startrow   = "1">

<cfoutput query="results">
  <p><a href="#url#">#title#</a> — score: #score#</p>
</cfoutput>
```

## Solr REST API from CFML

```cfml
<cfscript>
  q = encodeForURL(form.q);
  cfhttp(
    url    = "http://localhost:8983/solr/students/select?q=#q#&wt=json&rows=20",
    method = "GET",
    result = "resp"
  );
  data = deserializeJSON(resp.fileContent);
  for (doc in data.response.docs) {
    writeOutput(doc.name & "<br>");
  }
</cfscript>
```

## Index database records into Solr

```cfml
<cfscript>
  students = queryExecute("SELECT id, name, bio FROM students", {}, {datasource:"training_db"});

  cfindex(
    collection = "students",
    action     = "refresh",
    type       = "custom",
    query      = "students",
    title      = "name",
    body       = "bio",
    key        = "id"
  );

  writeOutput("Indexed #students.recordCount# records");
</cfscript>
```

