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
      echo "java_demo.cfm is accessible"

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
      echo "Java object creation found"

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
      echo "java_demo.cfm runs without errors"
---

## Creating Java objects

```cfml
<cfscript>
  // java.util.ArrayList
  list = createObject("java", "java.util.ArrayList").init();
  list.add("ColdFusion");
  list.add("Java");
  list.add("Lucee");
  writeOutput("Size: " & list.size());

  // java.util.HashMap
  map = createObject("java", "java.util.HashMap").init();
  map.put("name", "Alex");
  map.put("role", "developer");
  writeOutput("Name: " & map.get("name"));
</cfscript>
```

## String utilities

```cfml
<cfscript>
  sb = createObject("java", "java.lang.StringBuilder").init("Hello");
  sb.append(", World!");
  writeOutput(sb.toString());
</cfscript>
```

## Loading a custom JAR

```cfml
<cfscript>
  // place mylib.jar in {cfusion}/lib/ or use this.javaSettings
  loader = createObject("component", "javaloader.JavaLoader").init(
    loadPaths = [expandPath("/lib/mylib.jar")]
  );
  obj = loader.create("com.example.MyClass").init();
  result = obj.doSomething();
  writeOutput(result);
</cfscript>
```

## this.javaSettings in Application.cfc

```cfml
component {
  this.name = "MyApp";
  this.javaSettings = {
    loadPaths: [expandPath("/lib/")],
    reloadOnChange: false
  };
}
```

