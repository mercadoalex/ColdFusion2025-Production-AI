---
kind: lesson

title: Advanced Java Integration
description: |
  Leverage the JVM from within ColdFusion. Load Java classes and libraries,
  invoke Java methods, handle Java objects, and integrate third-party JARs
  directly from CFML.

name: advanced-java-integration
slug: advanced-java-integration

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- java
- jvm

playground:
  name: cf-training-devops-3039c6bb

challenges:
  java-integration-2de4c4c3: {}

tasks:
  verify_java_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/java_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "java_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "java_demo.cfm is accessible ✓"
    hintcheck: |
      echo "Create java_demo.cfm in the CF webroot — follow the Activity in section 1."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm ..."

  verify_createobject_java:
    machine: cf-dev
    user: laborant
    needs:
      - verify_java_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm"
      if ! grep -qi 'createObject' "${FILE}" 2>/dev/null; then
        echo "No createObject call found in java_demo.cfm"
        exit 1
      fi
      if ! grep -qi 'java' "${FILE}" 2>/dev/null; then
        echo "No java reference found in java_demo.cfm"
        exit 1
      fi
      echo "Java object creation found ✓"
    hintcheck: |
      echo "java_demo.cfm must call createObject(\"java\", ...) to instantiate a Java class."

  verify_java_output:
    machine: cf-dev
    user: laborant
    needs:
      - verify_createobject_java
    run: |
      BODY=$(curl -s http://localhost:8500/java_demo.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "java_demo.cfm is throwing an error"
        exit 1
      fi
      echo "java_demo.cfm runs without errors ✓"
    hintcheck: |
      echo "Check for CFML errors: tail /opt/coldfusion2025/cfusion/logs/exception.log"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_java_output
    run: |
      echo "Java integration lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
