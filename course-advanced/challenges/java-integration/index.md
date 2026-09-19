---
kind: challenge

title: 'Java Integration — UUID Generator Service'

description: |
  Build a CFML page that uses Java standard library classes to generate
  UUIDs, sort a list, and report JVM memory usage.

categories:
  - programming

tagz:
  - coldfusion
  - java
  - jvm

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  java_uuid_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/java_challenge.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "java_challenge.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "java_challenge.cfm accessible ✓"

  uses_uuid:
    machine: cf-dev
    user: laborant
    needs:
      - java_uuid_page
    run: |
      BODY=$(curl -s http://localhost:8500/java_challenge.cfm)
      # UUID pattern: 8-4-4-4-12 hex chars
      if ! echo "${BODY}" | grep -qE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"; then
        echo "No UUID found in java_challenge.cfm output"
        exit 1
      fi
      echo "UUID found in output ✓"

  uses_jvm_memory:
    machine: cf-dev
    user: laborant
    needs:
      - uses_uuid
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/java_challenge.cfm"
      if ! grep -qi "Runtime\|maxMemory\|freeMemory\|currentTimeMillis" "${FILE}" 2>/dev/null; then
        echo "No JVM Runtime call found in java_challenge.cfm"
        exit 1
      fi
      echo "JVM Runtime usage found ✓"
---

## Java Integration — UUID Generator Service

Create a page at `/opt/coldfusion2025/cfusion/wwwroot/java_challenge.cfm` that demonstrates Java integration from CFML.

### Requirements

The page must:
1. Generate and display a **UUID** using `java.util.UUID.randomUUID()`
2. Read and display JVM memory stats using `java.lang.Runtime.getRuntime()`
3. Output must be visible as plain text or HTML — no errors

### Example output

```
UUID: 550e8400-e29b-41d4-a716-446655440000
Heap: 128MB used / 512MB max
Available CPUs: 2
```

::simple-task
---
:tasks: tasks
:name: java_uuid_page
---
#active
Create `java_challenge.cfm` that returns HTTP 200.

#completed
java_challenge.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: uses_uuid
---
#active
Output a UUID in the format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.

#completed
UUID found in output. ✓
::

::simple-task
---
:tasks: tasks
:name: uses_jvm_memory
---
#active
Call `java.lang.Runtime.getRuntime()` to read memory stats.

#completed
JVM Runtime usage found. ✓
::
