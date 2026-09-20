---
kind: lesson

title: AI-Powered Help Desk
description: |
  Build a real AI feature on top of the Help Desk application. Use
  OllamaService.cfc to auto-triage new tickets, suggest resolutions
  for open tickets, and generate a summary report — all powered by
  phi3:mini running locally on the ollama VM.

name: ai-helpdesk
slug: ai-helpdesk

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- helpdesk
- database

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  ai-helpdesk-f87111e5: {}

tasks:
  init_wait_for_cf:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 300
    run: |
      until nc -z 127.0.0.1 8500 2>/dev/null; do
        echo "Waiting for ColdFusion on port 8500..."
        sleep 5
      done
      sleep 10
      echo "ColdFusion is up ✓"

  verify_triage_endpoint:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:8500/api/ai-triage.cfm?ticket_id=1")
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-triage.cfm?ticket_id=1 returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-triage.cfm accessible ✓"

  verify_triage_json:
    machine: cf-dev
    user: laborant
    needs:
      - verify_triage_endpoint
    run: |
      BODY=$(curl -s "http://localhost:8500/api/ai-triage.cfm?ticket_id=1")
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'suggested_priority' in d and 'resolution' in d" 2>/dev/null; then
        echo "ai-triage.cfm response missing 'suggested_priority' or 'resolution' fields"
        exit 1
      fi
      echo "Triage fields present ✓"

  verify_summary_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - verify_triage_json
    run: |
      BODY=$(curl -s "http://localhost:8500/api/ai-summary.cfm")
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'summary' in d" 2>/dev/null; then
        echo "ai-summary.cfm response missing 'summary' field"
        exit 1
      fi
      echo "AI summary generated ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_summary_endpoint
    run: |
      echo "AI Help Desk lesson complete ✓"
---
