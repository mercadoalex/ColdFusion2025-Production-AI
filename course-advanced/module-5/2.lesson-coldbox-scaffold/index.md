---
kind: lesson

title: Project Scaffolding with CommandBox

description: |
  Scaffold a ColdBox application with `coldbox create app`, understand
  the folder structure, and get the app running locally.

name: coldbox-scaffold-commandbox
slug: coldbox-scaffold-commandbox

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- commandbox

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  coldbox-scaffold-3a91a6cf: {}

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

  verify_coldbox_app:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f "/home/laborant/app/Application.cfc" ]; then
        echo "No Application.cfc found — scaffold with: box coldbox create app"
        exit 1
      fi
      if ! grep -qi "coldbox" "/home/laborant/app/Application.cfc"; then
        echo "Application.cfc does not extend ColdBox"
        exit 1
      fi
      echo "ColdBox app scaffolded ✓"

  verify_app_running:
    machine: cf-dev
    user: laborant
    needs:
      - verify_coldbox_app
    run: |
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
      if [ "$CODE" != "200" ]; then
        echo "App not responding on port 8888 (got $CODE)"
        exit 1
      fi
      echo "App running on port 8888 ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_app_running
    run: |
      echo "ColdBox scaffold lesson complete ✓"
---
