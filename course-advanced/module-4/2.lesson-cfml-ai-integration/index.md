---
kind: lesson

title: Calling AI from CFML
description: |
  Use ColdFusion's cfhttp tag to call the Ollama API from CFML code.
  Build a reusable OllamaService.cfc, handle streaming vs non-streaming
  responses, and wire up a working AI chat endpoint backed by phi3:mini.

name: cfml-ai-integration
slug: cfml-ai-integration

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- ollama
- cfhttp

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  cfml-ai-integration-001a9503: {}

tasks:
  verify_ai_test_cfm:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/ai_test.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "GET /ai_test.cfm returned HTTP ${STATUS}"
        exit 1
      fi
      BODY=$(curl -s http://localhost:8500/ai_test.cfm)
      if [ -z "${BODY}" ]; then
        echo "ai_test.cfm returned an empty body"
        exit 1
      fi
      echo "ai_test.cfm is responding with content ✓"

  verify_ollama_service_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_test_cfm
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc ]; then
        echo "OllamaService.cfc not found at /opt/coldfusion2025/cfusion/wwwroot/"
        exit 1
      fi
      echo "OllamaService.cfc found ✓"

  verify_ai_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ollama_service_exists
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/api/ai-chat.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "GET /api/ai-chat.cfm returned HTTP ${STATUS}"
        exit 1
      fi
      echo "ai-chat.cfm is accessible ✓"

  verify_ai_response:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_endpoint
    run: |
      BODY=$(curl -s -X POST http://localhost:8500/api/ai-chat.cfm \
              -H "Content-Type: application/json" \
              -d '{"prompt":"Reply with only the word PONG"}')
      if ! echo "${BODY}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "ai-chat.cfm POST did not return a non-empty response field"
        exit 1
      fi
      echo "AI response received ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_response
    run: |
      echo "CFML AI integration lesson complete ✓"
---
