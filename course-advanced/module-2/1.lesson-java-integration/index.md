---
kind: lesson

title: Advanced Java Integration
description: |
  Leverage the JVM from within ColdFusion. Load Java classes and libraries,
  invoke Java methods, handle Java objects, and integrate third-party JARs
  directly from CFML.

name: advanced-java-integration
slug: advanced-java-integration

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- java
- jvm

playground:
  name: cf-training-advanced-7442b9e0

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

  verify_createobject_java:
    machine: cf-dev
    user: laborant
    needs:
      - verify_java_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm"
      if ! grep -qi "createObject.*java\|createObject(\"java\"" "${FILE}" 2>/dev/null; then
        echo "No createObject java call found in java_demo.cfm"
        exit 1
      fi
      echo "Java object creation found ✓"

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

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_java_output
    run: |
      echo "Java integration lesson complete ✓"
---
