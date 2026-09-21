---
kind: lesson

title: Calling AI from CFML
description: |
  Use ColdFusion's cfhttp tag to call the Ollama API from CFML code.
  Build a reusable OllamaService.cfc, handle streaming vs non-streaming
  responses, and wire up a working AI chat endpoint backed by phi3:mini.

name: cfml-ai-integration
slug: cfml-ai-integration

createdAt: 2026-09-03
updatedAt: 2026-09-03

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
  cfml-ai-integration-c3d196db: {}

tasks:
  verify_ai_test_cfm:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/ai_test.cfm ]; then
        echo "ai_test.cfm not found — complete the Activity in section 2"
        exit 1
      fi
      echo "ai_test.cfm found ✓"
    hintcheck: |
      echo "Run the Activity in section 2 to create ai_test.cfm, then:"
      echo "  curl -s http://localhost:8500/ai_test.cfm | tee /tmp/ai_test_output.txt"

  verify_ollama_service_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_test_cfm
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc ]; then
        echo "OllamaService.cfc not found — complete the Activity in section 4"
        exit 1
      fi
      echo "OllamaService.cfc found ✓"
    hintcheck: |
      echo "Run the tee command in section 4 to create OllamaService.cfc, then verify:"
      echo "  ls /opt/coldfusion2025/cfusion/wwwroot/OllamaService.cfc"

  verify_ai_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ollama_service_exists
    run: |
      if [ ! -f /opt/coldfusion2025/cfusion/wwwroot/api/ai-chat.cfm ]; then
        echo "api/ai-chat.cfm not found — complete the Activity in section 5"
        exit 1
      fi
      echo "api/ai-chat.cfm found ✓"
    hintcheck: |
      echo "Run the mkdir + tee commands in section 5 to create api/ai-chat.cfm"

  verify_ai_response:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_endpoint
    run: |
      if [ ! -s /tmp/ai_response.txt ]; then
        echo "Run the POST test in section 5 Activity — save output to /tmp/ai_response.txt"
        exit 1
      fi
      if ! python3 -c "import sys,json; d=json.load(open('/tmp/ai_response.txt')); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "/tmp/ai_response.txt exists but does not contain a non-empty response field"
        exit 1
      fi
      echo "AI response confirmed ✓"
    hintcheck: |
      echo "In section 5, run the POST test and capture it:"
      echo "  curl -s -X POST http://localhost:8500/api/ai-chat.cfm \\"
      echo "    -H 'Content-Type: application/json' \\"
      echo "    -d '{\"prompt\":\"In two sentences, what is ColdFusion used for?\"}' \\"
      echo "    | tee /tmp/ai_response.txt"

  verify_error_handling:
    machine: cf-dev
    user: laborant
    needs:
      - verify_ai_response
    run: |
      if [ ! -s /tmp/ai_error_test.txt ]; then
        echo "Run the error test in section 6 Activity — save output to /tmp/ai_error_test.txt"
        exit 1
      fi
      if ! grep -q "Error handling works correctly" /tmp/ai_error_test.txt; then
        echo "/tmp/ai_error_test.txt exists but does not contain expected text"
        exit 1
      fi
      echo "Error handling verified ✓"
    hintcheck: |
      echo "In section 6, run:"
      echo "  curl -s http://localhost:8500/ai_error_test.cfm | tee /tmp/ai_error_test.txt"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_error_handling
    run: |
      echo "CFML AI integration lesson complete ✓"
    hintcheck: |
      echo "Complete all previous tasks first — they must all be green before this turns green."
---
