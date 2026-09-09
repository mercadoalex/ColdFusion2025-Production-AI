---
kind: lesson

title: Project Scaffolding with CommandBox

description: |
  Scaffold a ColdBox application with `coldbox create app`, understand
  the folder structure, and get the app running locally.

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  verify_coldbox_app:
    machine: dev-machine
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
      echo "ColdBox app scaffolded"

  verify_app_running:
    machine: dev-machine
    user: laborant
    needs:
      - verify_coldbox_app
    run: |
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
      if [ "$CODE" != "200" ]; then
        echo "App not responding on port 8888 (got $CODE)"
        exit 1
      fi
      echo "App running on port 8888"
---
