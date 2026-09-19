---
kind: unit

title: Advanced Java Integration

name: advanced-java-integration-unit-1
---

## ColdFusion runs on the JVM — use it

ColdFusion is a Java application running inside Apache Tomcat. Every `.cfm` file compiles to Java bytecode. This means you have direct, zero-overhead access to the entire Java ecosystem from CFML — no bridges, no adapters.

::image-box
---
:src: __static__/cfml-jvm-bridge-v1.png
:alt: Architecture diagram showing ColdFusion CFML code on the left calling createObject("java","java.util.ArrayList") with an arrow pointing through a JVM boundary to the Java standard library on the right, with a label "same JVM process — zero overhead"
:max-width: 860px
---
_CFML and Java share the same JVM process — calling Java classes is a direct method invocation._
::

When should you reach for Java from CFML?

| Use case | Why Java |
|---|---|
| Cryptography / encoding | Java's `javax.crypto` is comprehensive and well-tested |
| Complex data structures | `java.util.TreeMap`, `LinkedHashMap`, `PriorityQueue` |
| Regular expressions | `java.util.regex` for advanced patterns |
| File I/O | `java.nio.file` for atomic writes, symlinks |
| Third-party libraries | Any JAR can be added to the classpath |
| JVM metrics | Monitor heap, threads, GC from CFML |

---

## 1. Creating Java objects with createObject()

`createObject("java", "fully.qualified.ClassName")` instantiates any Java class accessible on the classpath.

```cfml
<cfscript>
  // java.util.ArrayList — dynamic array
  list = createObject("java", "java.util.ArrayList").init();
  list.add("ColdFusion");
  list.add("Java");
  list.add("Lucee");
  writeOutput("Size: " & list.size() & "<br>");         // 3
  writeOutput("Contains CF: " & list.contains("ColdFusion") & "<br>"); // true

  // java.util.HashMap — key-value map preserving no order
  map = createObject("java", "java.util.HashMap").init();
  map.put("name", "Alex");
  map.put("role", "developer");
  writeOutput("Name: " & map.get("name") & "<br>");    // Alex
</cfscript>
```

::hint-box
---
:summary: Why call .init() after createObject()?
---
`createObject("java", "ClassName")` creates a ColdFusion wrapper around the Java class but does **not** call the constructor. `.init()` is the CFML convention for calling the constructor. You can pass constructor arguments to `init()`:

```cfml
// StringBuilder with an initial value
sb = createObject("java", "java.lang.StringBuilder").init("Hello");
```

If you forget `.init()`, you get a reference to an uninitialised object and most method calls will throw `NullPointerException`.
::

**Activity:** Create `java_demo.cfm` in the CF webroot:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm << 'EOF'
<cfscript>
  // ArrayList
  list = createObject("java", "java.util.ArrayList").init();
  list.add("ColdFusion");
  list.add("Java");
  list.add("Lucee");
  writeOutput("<strong>ArrayList size:</strong> " & list.size() & "<br>");

  // StringBuilder
  sb = createObject("java", "java.lang.StringBuilder").init("Hello");
  sb.append(", World!");
  writeOutput("<strong>StringBuilder:</strong> " & sb.toString() & "<br>");

  // HashMap
  map = createObject("java", "java.util.HashMap").init();
  map.put("engine", "ColdFusion 2025");
  map.put("port", "8500");
  writeOutput("<strong>Engine:</strong> " & map.get("engine") & "<br>");
</cfscript>
EOF
```

```bash
curl -s http://localhost:8500/java_demo.cfm
```

::simple-task
---
:tasks: tasks
:name: verify_java_page
---
#active
Create `java_demo.cfm` in `/opt/coldfusion2025/cfusion/wwwroot/` and verify it returns HTTP 200.

#completed
java_demo.cfm is accessible. ✓
::

---

## 2. Useful Java standard library classes

::image-box
---
:src: __static__/java-stdlib-cfml-v1.png
:alt: Four-panel grid showing CFML code using four Java standard library classes — StringBuilder for string building, UUID.randomUUID() for unique IDs, Collections.sort() for sorting an ArrayList, and System.currentTimeMillis() for high-precision timing
:max-width: 860px
---
_Four practical Java classes you'll use regularly from CFML._
::

```cfml
<cfscript>
  // ── String building ────────────────────────────────────────────────
  sb = createObject("java", "java.lang.StringBuilder").init();
  for (i = 1; i <= 5; i++) {
    sb.append("Item " & i & chr(10));
  }
  writeOutput("<pre>" & sb.toString() & "</pre>");

  // ── Generate a UUID ────────────────────────────────────────────────
  uuid = createObject("java", "java.util.UUID").randomUUID().toString();
  writeOutput("UUID: " & uuid & "<br>");

  // ── Sort a list ────────────────────────────────────────────────────
  fruits = createObject("java", "java.util.ArrayList").init();
  fruits.add("banana"); fruits.add("apple"); fruits.add("cherry");
  createObject("java", "java.util.Collections").sort(fruits);
  writeOutput("Sorted: " & fruits.toString() & "<br>");

  // ── High-precision timer ───────────────────────────────────────────
  start = createObject("java", "java.lang.System").currentTimeMillis();
  sleep(50);
  elapsed = createObject("java", "java.lang.System").currentTimeMillis() - start;
  writeOutput("Elapsed: " & elapsed & "ms<br>");
</cfscript>
```

::simple-task
---
:tasks: tasks
:name: verify_createobject_java
---
#active
Add a `createObject("java", ...)` call to `java_demo.cfm`.

#completed
Java object creation found in java_demo.cfm. ✓
::

---

## 3. Loading custom JARs with this.javaSettings

To use third-party libraries, place the JAR on the classpath using `this.javaSettings` in `Application.cfc`.

```cfml
// Application.cfc
component {
  this.name = "JavaIntegrationDemo";

  // Tell CF where to find additional JARs
  this.javaSettings = {
    loadPaths: [
      expandPath("/lib/"),        // directory — loads all JARs inside
      expandPath("/lib/gson.jar") // or a specific JAR file
    ],
    reloadOnChange: true,         // pick up new JARs without CF restart (dev only)
    watchInterval:  60            // seconds between classpath scans
  };
}
```

::hint-box
---
:summary: Where do I get JARs?
---
For open-source libraries, download the JAR from [Maven Central](https://search.maven.org/) or use CommandBox's package manager:

```bash
# Example: download Google Gson (JSON library)
box install google/gson
# Places gson-*.jar in your project's /lib directory
```

For your own Java code, compile with `javac` and place the resulting `.class` files (or a JAR) in the `loadPaths` directory.
::

**Activity:** Create the lib directory and test that `this.javaSettings` is picked up:

```bash
# Create lib directory
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/lib

# Create a minimal Application.cfc with javaSettings
sudo tee /opt/coldfusion2025/cfusion/wwwroot/Application.cfc << 'EOF'
component {
  this.name = "JavaDemo";
  this.javaSettings = {
    loadPaths: [expandPath("/lib/")],
    reloadOnChange: false
  };
}
EOF

# Reload the app (touch Application.cfc to force re-init)
touch /opt/coldfusion2025/cfusion/wwwroot/Application.cfc
curl -sf http://localhost:8500/java_demo.cfm && echo "App reloaded OK"
```

---

## 4. JVM diagnostics from CFML

ColdFusion exposes JVM internals through standard Java management APIs. This is useful for monitoring heap usage and thread counts in a running application.

```cfml
<cfscript>
  // ── Memory ─────────────────────────────────────────────────────────
  runtime = createObject("java", "java.lang.Runtime").getRuntime();
  maxMem  = int(runtime.maxMemory()  / 1024 / 1024);
  freeMem = int(runtime.freeMemory() / 1024 / 1024);
  totMem  = int(runtime.totalMemory()/ 1024 / 1024);

  writeOutput("Heap: " & (totMem - freeMem) & "MB used / " & maxMem & "MB max<br>");

  // ── Processors ─────────────────────────────────────────────────────
  cpus = runtime.availableProcessors();
  writeOutput("Available CPUs: " & cpus & "<br>");

  // ── System properties ──────────────────────────────────────────────
  props = createObject("java", "java.lang.System").getProperties();
  writeOutput("Java version: " & props.get("java.version") & "<br>");
  writeOutput("OS: " & props.get("os.name") & " " & props.get("os.version") & "<br>");
</cfscript>
```

::simple-task
---
:tasks: tasks
:name: verify_java_output
---
#active
Verify `java_demo.cfm` runs without any ColdFusion error or exception in the response.

#completed
java_demo.cfm runs without errors. ✓
::

---

## Key concepts reference

| Concept | CFML syntax |
|---|---|
| Instantiate a class | `createObject("java", "pkg.ClassName").init()` |
| Call static method | `createObject("java", "pkg.ClassName").staticMethod()` |
| Load custom JARs | `this.javaSettings = { loadPaths: [...] }` in Application.cfc |
| Check JVM memory | `java.lang.Runtime.getRuntime().maxMemory()` |
| Generate UUID | `java.util.UUID.randomUUID().toString()` |
| Sort a list | `java.util.Collections.sort(arrayListRef)` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
All three Java tasks are green — hit **Check** to complete this lesson.

#completed
Java integration lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.java-integration-XXXXXXXX
---
::
