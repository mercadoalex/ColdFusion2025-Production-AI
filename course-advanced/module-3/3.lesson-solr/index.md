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
  name: cf-training-devops-3039c6bb

challenges:
  solr-search-7ec1ea17: {}

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
      echo "Solr is running on port 8983 ✓"
    hintcheck: |
      echo "Solr starts automatically. If not ready, wait 30 s, then:"
      echo "  curl -s -o /dev/null -w \"%{http_code}\" http://localhost:8983/solr/"
      echo "Or check: sudo systemctl status solr"

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
    hintcheck: |
      echo "Create the Solr collection — follow the cfcollection Activity in section 2."
      echo "The collection must be named 'students' or 'training'."

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
    hintcheck: |
      echo "Create search.cfm — follow the cfsearch Activity in section 3."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/search.cfm ..."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_search_page
    run: |
      echo "Solr lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
