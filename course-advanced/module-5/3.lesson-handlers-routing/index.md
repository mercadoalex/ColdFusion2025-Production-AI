---
kind: lesson

title: Handlers, Actions & Routing

description: |
  Build ColdBox handlers and actions, configure URL routing in
  Router.cfc, and map HTTP verbs to handler actions.

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  verify_handler_exists:
    machine: dev-machine
    user: laborant
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" 2>/dev/null | head -1)
      if [ -z "$HANDLER" ]; then
        echo "No handler CFC found in handlers/"
        exit 1
      fi
      echo "Handler found: $HANDLER"

  verify_handler_action:
    machine: dev-machine
    user: laborant
    needs:
      - verify_handler_exists
    run: |
      HANDLER=$(find /home/laborant/app/handlers -name "*.cfc" | head -1)
      if ! grep -qi "function" "$HANDLER"; then
        echo "No action function found in handler"
        exit 1
      fi
      echo "Handler action found"

  verify_route_responds:
    machine: dev-machine
    user: laborant
    needs:
      - verify_handler_action
    run: |
      CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
      if [ "$CODE" != "200" ]; then
        echo "Default route not responding (got $CODE)"
        exit 1
      fi
      echo "Route responds with 200"
---
