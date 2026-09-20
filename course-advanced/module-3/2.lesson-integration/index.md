---
kind: lesson

title: External Integration — cfhttp and cfmail
description: |
  Connect ColdFusion with external systems via HTTP, messaging queues,
  and email. Consume REST APIs with cfhttp, send rich HTML email with
  cfmail, and handle cross-platform interoperability patterns.

name: integration-other-technologies
slug: integration-other-technologies

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- integration
- cfhttp
- cfmail

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  integration-001a9503: {}

tasks:
  verify_cfhttp_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/integration_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "integration_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "integration_demo.cfm is accessible ✓"

  verify_cfhttp_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfhttp_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/integration_demo.cfm"
      if ! grep -qi "cfhttp" "${FILE}" 2>/dev/null; then
        echo "cfhttp not found in integration_demo.cfm"
        exit 1
      fi
      echo "cfhttp is used ✓"

  verify_cfmail_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfhttp_used
    run: |
      COUNT=$(grep -ri "cfmail\|cfmailparam" /opt/coldfusion2025/cfusion/wwwroot/ 2>/dev/null | wc -l)
      if [ "${COUNT}" -lt 1 ]; then
        echo "No cfmail usage found in the project"
        exit 1
      fi
      echo "cfmail is used in ${COUNT} location(s) ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfmail_used
    run: |
      echo "Integration lesson complete ✓"
---
