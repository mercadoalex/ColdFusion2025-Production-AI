---
kind: lesson

title: Apache Solr and Full-Text Search
description: |
  Integrate Apache Solr with ColdFusion for enterprise full-text search.
  Index database records, query collections with cfindex and cfsearch,
  and build a search UI backed by Solr.

name: apache-solr-advanced-search
slug: apache-solr-advanced-search

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- solr
- search

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  solr-search-7ec1ea17: {}

tasks:
  init_wait_for_cf:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 120
    run: |
      until curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/CFIDE/administrator/ | grep -q "200\|302"; do
        echo "Waiting for ColdFusion on port 8500..."
        sleep 5
      done
      echo "ColdFusion is up ✓"

  verify_solr_running:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8983/solr/)
      if [ "${STATUS}" != "200" ]; then
        echo "Solr is not running on port 8983 (got ${STATUS})"
        exit 1
      fi
      echo "Solr is running on port 8983 ✓"

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
      echo "Solr collection exists ✓"

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
      echo "search.cfm is accessible ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_search_page
    run: |
      echo "Solr lesson complete ✓"
---
