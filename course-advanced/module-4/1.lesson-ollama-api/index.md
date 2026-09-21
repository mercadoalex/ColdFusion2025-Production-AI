---
kind: lesson

title: Introduction to Ollama and Local LLMs
description: |
  Learn how to run large language models locally using Ollama. Explore the
  Ollama REST API, generate text completions, and understand how to integrate
  a local AI node into a multi-VM ColdFusion environment.

name: intro-ollama-local-llms
slug: intro-ollama-local-llms

createdAt: 2026-09-03
updatedAt: 2026-09-03

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
      if [ ! -s /tmp/ollama_completion.txt ]; then
        echo "Run the generate activity in section 3 — output should be saved to /tmp/ollama_completion.txt"
        exit 1
      fi
      echo "Completion result found ✓"
    hintcheck: |
      echo "Run the curl command in section 3 and make sure it completes without error."
      echo "The command should end with: | tee /tmp/ollama_completion.txt"

  verify_chat_endpoint:
    machine: ollama
    user: laborant
    needs:
      - verify_completion
    run: |
      if [ ! -s /tmp/ollama_chat.txt ]; then
        echo "Run the chat activity in section 4 — output should be saved to /tmp/ollama_chat.txt"
        exit 1
      fi
      echo "Chat result found ✓"
    hintcheck: |
      echo "Run the curl command in section 4 and make sure it completes without error."
      echo "The command should end with: | tee /tmp/ollama_chat.txt"

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
    hintcheck: |
      echo "Run: curl -s -o /dev/null -w \"%{http_code}\" http://ollama:11434/api/tags"
      echo "It should return 200. If not, check that the ollama VM is still running."

  verify_cf_dev_prompt:
    machine: cf-dev
    user: laborant
    needs:
      - verify_reachable_from_dev
    run: |
      if [ ! -s /tmp/ollama_from_dev.txt ]; then
        echo "Run the generate activity in section 5 — output should be saved to /tmp/ollama_from_dev.txt"
        exit 1
      fi
      echo "cf-dev prompt result found ✓"
    hintcheck: |
      echo "Run the curl command in section 5 (Terminal dev tab) and make sure it completes."
      echo "The command should end with: | tee /tmp/ollama_from_dev.txt"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cf_dev_prompt
    run: |
      echo "Ollama API lesson complete ✓"
---
