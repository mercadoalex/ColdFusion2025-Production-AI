---
kind: lesson

title: Building REST APIs with ColdBox

description: |
  Build a structured REST API using ColdBox resource routing, renderData(),
  and response status codes — replacing raw .cfm endpoints with a proper
  MVC layer.

name: coldbox-rest-api
slug: coldbox-rest-api

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- rest
- api

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  coldbox-rest-b4e57e76: {}

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

  verify_api_handler:
    machine: cf-dev
    user: laborant
    run: |
      HANDLER=$(grep -rl "renderData\|event.renderData" /home/laborant/app/handlers/ 2>/dev/null | head -1)
      if [ -z "$HANDLER" ]; then
        echo "No renderData() call found in handlers"
        exit 1
      fi
      echo "API handler with renderData found ✓"

  verify_api_responds:
    machine: cf-dev
    user: laborant
    needs:
      - verify_api_handler
    run: |
      BODY=$(curl -s http://localhost:8888/api/tickets)
      if ! echo "$BODY" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "API endpoint did not return valid JSON"
        exit 1
      fi
      echo "API returns valid JSON ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_api_responds
    run: |
      echo "ColdBox REST API lesson complete ✓"
---
