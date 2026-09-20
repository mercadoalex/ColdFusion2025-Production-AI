---
kind: lesson

title: What is ColdBox? MVC Architecture & Why Frameworks

description: |
  Understand what ColdBox solves, how MVC maps to ColdFusion concepts,
  and when to choose a framework over raw CFML pages.

name: coldbox-intro-mvc
slug: coldbox-intro-mvc

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- mvc

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  coldbox-intro-c174c787: {}

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

  init_wait_for_lucee:
    init: true
    machine: cf-dev
    user: laborant
    timeout_seconds: 300
    run: |
      until curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/ | grep -q "200\|302"; do
        echo "Waiting for Lucee/CommandBox on port 8888..."
        sleep 5
      done
      echo "Lucee is up ✓"

  verify_coldbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/coldbox" ]; then
        echo "ColdBox not installed — run: cd /home/laborant/app && box install coldbox"
        exit 1
      fi
      if [ ! -f "/home/laborant/app/coldbox/system/Bootstrap.cfc" ]; then
        echo "ColdBox directory exists but appears incomplete"
        exit 1
      fi
      echo "ColdBox installed ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_coldbox_installed
    run: |
      echo "ColdBox intro lesson complete ✓"
---
