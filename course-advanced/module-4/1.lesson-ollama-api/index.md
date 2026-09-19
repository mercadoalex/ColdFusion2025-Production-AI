---
kind: lesson

title: Introduction to Ollama and Local LLMs
description: |
  Learn how to run large language models locally using Ollama. Explore the
  Ollama REST API, generate text completions, and understand how to integrate
  a local AI node into a multi-VM ColdFusion environment.

name: intro-ollama-local-llms
slug: intro-ollama-local-llms

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- cfml
- ai
- ollama
- llm

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  ollama-api-b6f93461: {}

tasks:
  verify_ollama_running:
    machine: ollama
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags)
      if [ "${STATUS}" != "200" ]; then
        echo "Ollama API not responding (HTTP ${STATUS}). Is ollama.service running?"
        exit 1
      fi
      echo "Ollama API is up ✓"

  verify_phi3_present:
    machine: ollama
    user: laborant
    needs:
      - verify_ollama_running
    run: |
      MODELS=$(curl -s http://localhost:11434/api/tags)
      if ! echo "${MODELS}" | python3 -c "import sys,json; d=json.load(sys.stdin); names=[m['name'] for m in d['models']]; assert any('phi3' in n for n in names)" 2>/dev/null; then
        echo "phi3:mini not found in Ollama model list"
        exit 1
      fi
      echo "phi3:mini is available ✓"

  verify_completion:
    machine: ollama
    user: laborant
    needs:
      - verify_phi3_present
    run: |
      RESPONSE=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Reply with only the word PONG","stream":false}')
      if ! echo "${RESPONSE}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "Ollama completion returned empty response"
        exit 1
      fi
      echo "Completion works ✓"

  verify_chat_endpoint:
    machine: ollama
    user: laborant
    needs:
      - verify_completion
    run: |
      RESPONSE=$(curl -s http://localhost:11434/api/chat \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","stream":false,"messages":[{"role":"system","content":"Reply only with the word OK."},{"role":"user","content":"Acknowledge."}]}')
      if ! echo "${RESPONSE}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('message',{}).get('content','')) > 0" 2>/dev/null; then
        echo "Ollama /api/chat returned empty message content"
        exit 1
      fi
      echo "Chat endpoint works ✓"

  verify_reachable_from_dev:
    machine: cf-dev
    user: laborant
    needs:
      - verify_chat_endpoint
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://ollama:11434/api/tags)
      if [ "${STATUS}" != "200" ]; then
        echo "Cannot reach Ollama from cf-dev at http://ollama:11434 (HTTP ${STATUS})"
        exit 1
      fi
      echo "Ollama is reachable from cf-dev ✓"

  verify_cf_dev_prompt:
    machine: cf-dev
    user: laborant
    needs:
      - verify_reachable_from_dev
    run: |
      RESPONSE=$(curl -s http://ollama:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Reply with only the word HELLO","stream":false}')
      if ! echo "${RESPONSE}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d.get('response','')) > 0" 2>/dev/null; then
        echo "Prompt from cf-dev to Ollama returned empty response"
        exit 1
      fi
      echo "cf-dev can send prompts to Ollama ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cf_dev_prompt
    run: |
      echo "Ollama API lesson complete ✓"
---
