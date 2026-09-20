---
kind: unit

title: Advanced Java Integration

name: advanced-java-integration-unit-1
---

## You already know Java — you just haven't used it yet

Here's a fact that surprises most ColdFusion developers: every `.cfm` file you've ever written was compiled to Java bytecode and executed inside the JVM. ColdFusion is not just *sitting on top of* Java — it **is** Java, wrapped in a friendlier syntax.

That means the entire Java ecosystem — fifteen-plus years of battle-tested libraries, cryptographic primitives, high-performance data structures, and a vast open-source universe on Maven Central — is available to you **right now**, with zero additional infrastructure.

No bridges. No adapters. No magic. One line of CFML and you're calling a Java class directly.

::image-box
---
:src: __static__/cfml-jvm-bridge-v1.png
:alt: Architecture diagram showing ColdFusion CFML code on the left calling createObject("java","java.util.ArrayList") with an arrow pointing through a JVM boundary to the Java standard library on the right, with a label "same JVM process — zero overhead"
:max-width: 860px
---
_CFML and Java share the same JVM process — calling a Java class is a direct method invocation, not an inter-process call._
::

When should you reach for Java from CFML?

| Use case | Why Java |
|---|---|
| Cryptography & encoding | `javax.crypto` is comprehensive, well-tested, and standard |
| Advanced data structures | `TreeMap`, `LinkedHashMap`, `PriorityQueue` — beyond a CF array |
| Regular expressions | `java.util.regex` for lookaheads, named groups, multi-line |
| File I/O | `java.nio.file` for atomic writes, symlinks, directory watches |
| Third-party libraries | Any JAR on Maven Central — add to classpath and call directly |
| JVM diagnostics | Heap usage, thread counts, GC metrics — from CFML |
| High-precision timing | `System.nanoTime()` for benchmarking below millisecond precision |

::hint-box
---
:summary: Do I need to know Java to use this lesson?
---
No. You don't need to read or write Java source code. Everything in this lesson is pure CFML — you're just calling Java classes using ColdFusion syntax.

If you do know Java, you'll feel immediately at home. If you don't, think of it this way: every Java class is like a CFC, and calling a method on it works exactly the same way as calling a method on a CFC you didn't write. You just need to know the class name and method signatures — and the Java docs at [docs.oracle.com/en/java/javase](https://docs.oracle.com/en/java/javase/) have those.
::

---

## 1. Creating Java objects with createObject()

`createObject("java", "fully.qualified.ClassName")` instantiates any Java class accessible on the classpath. The pattern is always the same:

```cfml
<cfscript>
  myObject = createObject("java", "package.ClassName").init( /* constructor args */ );
  result   = myObject.someMethod("argument");
</cfscript>
```

Let's start with the most useful standard-library classes:

```cfml
<cfscript>
  // ── java.util.ArrayList — a resizable array ─────────────────────────
  list = createObject("java", "java.util.ArrayList").init();
  list.add("ColdFusion");
  list.add("Java");
  list.add("Lucee");
  writeOutput("Size: "         & list.size()                & "<br>"); // 3
  writeOutput("Contains CF: "  & list.contains("ColdFusion")& "<br>"); // true
  writeOutput("Get item 0: "   & list.get(0)                & "<br>"); // ColdFusion

  // ── java.util.HashMap — key-value map ───────────────────────────────
  map = createObject("java", "java.util.HashMap").init();
  map.put("name", "Alex");
  map.put("role", "developer");
  writeOutput("Name: " & map.get("name") & "<br>");   // Alex
  writeOutput("Has key role: " & map.containsKey("role") & "<br>"); // true
</cfscript>
```

::hint-box
---
:summary: Why call .init() after createObject()?
---
`createObject("java", "ClassName")` creates a ColdFusion proxy around the Java class but **does not** call the constructor. `.init()` is the CFML convention for invoking the constructor — you can pass constructor arguments to it:

```cfml
// StringBuilder with an initial value
sb = createObject("java", "java.lang.StringBuilder").init("Hello, ");

// ArrayList pre-sized to 100 elements (performance hint to the JVM)
bigList = createObject("java", "java.util.ArrayList").init(100);
```

If you skip `.init()`, most method calls will throw `NullPointerException` or `UninitializedFieldError` because the object is technically just an uninitialised wrapper. Get into the habit: **createObject → init → use**.
::

::hint-box
---
:summary: Static methods don't need .init() — here's why
---
Some Java methods are *static* — they belong to the class, not to an instance. You call them without initialising an object first:

```cfml
// java.lang.System.currentTimeMillis() is a static method
millis = createObject("java", "java.lang.System").currentTimeMillis();

// java.util.UUID.randomUUID() is also static
uuid = createObject("java", "java.util.UUID").randomUUID().toString();
```

How do you know if a method is static? The Oracle Java docs mark static methods with the `static` keyword. As a rule of thumb: utility classes (`Math`, `System`, `Collections`, `Arrays`) are mostly static; container classes (`ArrayList`, `HashMap`, `StringBuilder`) are instance-based and need `.init()`.
::

**Activity — Terminal (dev):** Create `java_demo.cfm` in the CF webroot:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm << 'EOF'
<cfscript>
  // ── ArrayList ──────────────────────────────────────────────────────
  list = createObject("java", "java.util.ArrayList").init();
  list.add("ColdFusion");
  list.add("Java");
  list.add("Lucee");
  writeOutput("<strong>ArrayList size:</strong> " & list.size() & "<br>");

  // ── StringBuilder ──────────────────────────────────────────────────
  sb = createObject("java", "java.lang.StringBuilder").init("Hello");
  sb.append(", World!");
  writeOutput("<strong>StringBuilder:</strong> " & sb.toString() & "<br>");

  // ── HashMap ────────────────────────────────────────────────────────
  map = createObject("java", "java.util.HashMap").init();
  map.put("engine", "ColdFusion 2025");
  map.put("port", "8500");
  writeOutput("<strong>Engine:</strong> " & map.get("engine") & "<br>");
</cfscript>
EOF
```

Then verify it loads:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8500/java_demo.cfm
# Expected: 200
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

## 2. The Java standard library — your new toolbox

::image-box
---
:src: __static__/java-stdlib-cfml-v1.png
:alt: Four-panel grid showing CFML code using four Java standard library classes — StringBuilder for string building, UUID.randomUUID() for unique IDs, Collections.sort() for sorting an ArrayList, and System.currentTimeMillis() for high-precision timing
:max-width: 860px
---
_Four practical Java standard-library classes you'll use regularly from CFML._
::

These four classes cover a huge slice of day-to-day Java-from-CFML work. Study the patterns — they'll repeat throughout this lesson.

### StringBuilder — efficient string building

ColdFusion's string concatenation with `&` creates a new string object on every operation. For tight loops building large strings, `StringBuilder` is dramatically faster because it mutates a single internal buffer:

```cfml
<cfscript>
  sb = createObject("java", "java.lang.StringBuilder").init();
  for (i = 1; i <= 5; i++) {
    sb.append("Line " & i & chr(10));
  }
  writeOutput("<pre>" & sb.toString() & "</pre>");
  // Line 1
  // Line 2
  // Line 3
  // Line 4
  // Line 5
</cfscript>
```

::hint-box
---
:summary: How much faster is StringBuilder vs & concatenation?
---
For small strings (< 1000 chars) the difference is negligible — use whatever reads cleanly. For large strings in loops, the gap is real:

| Operation | 10,000 concatenations |
|---|---|
| `&` operator | ~200ms (new String object each time) |
| `StringBuilder.append()` | ~2ms (one buffer, mutated in place) |

If you're building a large HTML page, a CSV export, or any string in a loop over hundreds of rows, reach for `StringBuilder`.
::

### UUID — generate standards-compliant identifiers

```cfml
<cfscript>
  // java.util.UUID uses the RFC 4122 v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  uuid = createObject("java", "java.util.UUID").randomUUID().toString();
  writeOutput("UUID: " & uuid & "<br>");
  // UUID: 550e8400-e29b-41d4-a716-446655440000
</cfscript>
```

### Collections — sort, shuffle, search

`java.util.Collections` is a utility class of static methods that operate on Java collection objects:

```cfml
<cfscript>
  fruits = createObject("java", "java.util.ArrayList").init();
  fruits.add("banana");
  fruits.add("apple");
  fruits.add("cherry");

  // Sort in natural (alphabetical) order — modifies the list in place
  createObject("java", "java.util.Collections").sort(fruits);
  writeOutput("Sorted: " & fruits.toString() & "<br>"); // [apple, banana, cherry]

  // Reverse sort
  createObject("java", "java.util.Collections").reverse(fruits);
  writeOutput("Reversed: " & fruits.toString() & "<br>"); // [cherry, banana, apple]

  // Shuffle (useful for randomised card decks, question ordering, etc.)
  createObject("java", "java.util.Collections").shuffle(fruits);
  writeOutput("Shuffled: " & fruits.toString() & "<br>"); // random order
</cfscript>
```

### System — timing and environment

```cfml
<cfscript>
  // High-precision timing (milliseconds since Unix epoch)
  start   = createObject("java", "java.lang.System").currentTimeMillis();
  sleep(50);  // CFML sleep() call
  elapsed = createObject("java", "java.lang.System").currentTimeMillis() - start;
  writeOutput("Elapsed: " & elapsed & "ms<br>"); // ~50ms

  // System properties — useful for debugging runtime environment
  props = createObject("java", "java.lang.System").getProperties();
  writeOutput("Java version: " & props.get("java.version") & "<br>");
  writeOutput("OS: " & props.get("os.name") & " " & props.get("os.version") & "<br>");
  writeOutput("Temp dir: " & props.get("java.io.tmpdir") & "<br>");
</cfscript>
```

::hint-box
---
:summary: currentTimeMillis() vs nanoTime() — which should I use?
---
| Method | Resolution | Use for |
|---|---|---|
| `System.currentTimeMillis()` | Milliseconds | Wall-clock time, timestamps, date calculations |
| `System.nanoTime()` | Nanoseconds | Precise benchmarking within a single JVM process |

**Important:** `nanoTime()` does not represent a calendar date — it's a relative counter. Only use it to measure elapsed time:

```cfml
start   = createObject("java", "java.lang.System").nanoTime();
// ... do work ...
elapsed = createObject("java", "java.lang.System").nanoTime() - start;
writeOutput("Elapsed: " & (elapsed / 1000000) & "ms<br>"); // convert ns → ms
```

Never store `nanoTime()` to a database or compare it across requests.
::

**Activity — Terminal (dev):** Append the UUID and Collections examples to `java_demo.cfm`:

```bash
sudo tee -a /opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm << 'EOF'

<cfscript>
  // ── UUID ───────────────────────────────────────────────────────────
  uuid = createObject("java", "java.util.UUID").randomUUID().toString();
  writeOutput("<strong>UUID:</strong> " & uuid & "<br>");

  // ── Collections.sort ───────────────────────────────────────────────
  fruits = createObject("java", "java.util.ArrayList").init();
  fruits.add("banana"); fruits.add("apple"); fruits.add("cherry");
  createObject("java", "java.util.Collections").sort(fruits);
  writeOutput("<strong>Sorted:</strong> " & fruits.toString() & "<br>");

  // ── High-precision timer ───────────────────────────────────────────
  start   = createObject("java", "java.lang.System").currentTimeMillis();
  sleep(10);
  elapsed = createObject("java", "java.lang.System").currentTimeMillis() - start;
  writeOutput("<strong>Elapsed:</strong> " & elapsed & "ms<br>");
</cfscript>
EOF

curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8500/java_demo.cfm
# Expected: 200
```

::simple-task
---
:tasks: tasks
:name: verify_createobject_java
---
#active
Confirm `java_demo.cfm` contains a `createObject("java", ...)` call.

#completed
Java object creation found in java_demo.cfm. ✓
::

---

## 3. Useful patterns for real-world CFML

These patterns show up in real ColdFusion codebases. Each one demonstrates a gap that Java fills better than vanilla CFML.

### Pattern A — LinkedHashMap for insertion-ordered key iteration

ColdFusion structs do not guarantee key order (they use a Java `HashMap` internally). `LinkedHashMap` preserves insertion order — useful for building ordered responses:

::image-box
---
:src: __static__/java-linkedhashmap-cfml-v1.png
:alt: Three-column diagram showing insertion order on the left (status, code, message, id), a centre comparison between HashMap (keys scrambled, red, order not guaranteed) and LinkedHashMap (keys in insertion order, green, order preserved), and iteration output on the right matching the original insertion order
:max-width: 860px
---
_`HashMap` discards insertion order — `LinkedHashMap` guarantees it. Same API, predictable output._
::

```cfml
<cfscript>
  ordered = createObject("java", "java.util.LinkedHashMap").init();
  ordered.put("status",  "success");
  ordered.put("code",    200);
  ordered.put("message", "Record saved");
  ordered.put("id",      42);

  // Iterate in insertion order — guaranteed
  for (key in ordered.keySet()) {
    writeOutput(key & ": " & ordered.get(key) & "<br>");
  }
  // status: success
  // code: 200
  // message: Record saved
  // id: 42
</cfscript>
```

::hint-box
---
:summary: When does struct key order matter in practice?
---
Most of the time it doesn't — but there are cases where it does:

- **JSON serialisation for logs** — when a log aggregator reads fields in a fixed position, predictable key order avoids processing surprises
- **Building SQL column lists** — if you use a struct as an ordered column definition, iteration order matters
- **Debugging API responses** — it's much easier to read a JSON response when fields appear in a meaningful order

Use `LinkedHashMap` whenever you're building output that another system will consume and where field order improves readability or correctness.
::

### Pattern B — TreeMap for sorted key iteration

`TreeMap` automatically sorts keys in natural order (alphabetical for strings, ascending for numbers):

::image-box
---
:src: __static__/java-treemap-cfml-v1.png
:alt: Three-column diagram — left column shows three keys inserted in random order (zebra, apple, mango), centre column shows a TreeMap binary search tree with mango as root, apple as left child and zebra as right child, right column shows iteration output in alphabetical order (apple, mango, zebra) with a checkmark labelled A→Z
:max-width: 860px
---
_TreeMap sorts keys automatically on insertion — no manual `sort()` call needed._
::

```cfml
<cfscript>
  sorted = createObject("java", "java.util.TreeMap").init();
  sorted.put("zebra",   "last");
  sorted.put("apple",   "first");
  sorted.put("mango",   "middle");

  for (key in sorted.keySet()) {
    writeOutput(key & ": " & sorted.get(key) & "<br>");
  }
  // apple: first
  // mango: middle
  // zebra: last
</cfscript>
```

### Pattern C — PriorityQueue for priority-based processing

```cfml
<cfscript>
  // A PriorityQueue returns elements in natural order (smallest first for integers)
  pq = createObject("java", "java.util.PriorityQueue").init();
  pq.add(javaCast("int", 30));   // priority 30
  pq.add(javaCast("int",  5));   // priority 5  ← first out
  pq.add(javaCast("int", 20));   // priority 20

  while (!pq.isEmpty()) {
    writeOutput("Processing priority: " & pq.poll() & "<br>");
  }
  // Processing priority: 5
  // Processing priority: 20
  // Processing priority: 30
</cfscript>
```

::hint-box
---
:summary: What is javaCast() and why do I need it here?
---
ColdFusion uses dynamic typing — it doesn't distinguish between the number `30` and the string `"30"`. When you pass a plain CF value to a Java method that expects a specific primitive type, CF may guess wrong and cause a type-mismatch error.

`javaCast()` tells CF exactly what Java type to use:

```cfml
javaCast("int",    42)      // Java int — 32-bit integer
javaCast("long",   42)      // Java long — 64-bit integer
javaCast("float",  3.14)    // Java float
javaCast("double", 3.14)    // Java double
javaCast("string", "hello") // Java String (explicit)
javaCast("boolean", true)   // Java boolean
```

You won't need `javaCast()` for most string operations — CF passes strings correctly by default. You'll need it when working with numeric collections, method overloads, or any method that the CF runtime gets confused about.
::

---

## 4. Loading custom JARs with this.javaSettings

The real power unlock is third-party libraries. Place a JAR on the classpath via `this.javaSettings` in `Application.cfc`, and every class inside that JAR becomes callable from CFML.

::image-box
---
:src: __static__/java-jarsettings-cfml-v1.png
:alt: Diagram showing a project folder structure with an Application.cfc at the root pointing to a /lib directory containing gson.jar and commons-lang3.jar, with arrows from those JARs into ColdFusion's JVM classpath, and CFML code calling createObject("java","com.google.gson.Gson") on the right
:max-width: 860px
---
_Place JARs in `/lib`, declare the path in `Application.cfc`, and every class inside becomes callable from any `.cfm` file in the application._
::

```cfml
// Application.cfc
component {
  this.name = "JavaIntegrationDemo";

  this.javaSettings = {
    loadPaths: [
      expandPath("/lib/"),        // load all JARs in this directory
      expandPath("/lib/gson.jar") // or a single specific JAR
    ],
    reloadOnChange: true,         // pick up new JARs without restarting CF (dev only)
    watchInterval:  60            // seconds between classpath scans
  };
}
```

Once configured, use the class exactly as you would any standard-library class:

```cfml
<cfscript>
  // Google Gson — JSON serialisation/deserialisation
  gson   = createObject("java", "com.google.gson.Gson").init();
  struct = { name: "Alex", role: "developer", active: true };
  json   = gson.toJson(struct);
  writeOutput("JSON: " & json & "<br>");
  // JSON: {"name":"Alex","role":"developer","active":true}
</cfscript>
```

::hint-box
---
:summary: Where do I get JARs?
---
**Maven Central** is the central repository for Java open-source libraries — [search.maven.org](https://search.maven.org/). Search for a library name, click the version you want, and download the `.jar` file.

Common JARs useful from ColdFusion:

| Library | JAR | What it does |
|---|---|---|
| Google Gson | `gson-*.jar` | JSON (better than CF's built-in for edge cases) |
| Apache Commons Lang | `commons-lang3-*.jar` | String utilities, number parsing, date formatting |
| Apache PDFBox | `pdfbox-*.jar` | Read and write PDF files |
| Apache POI | `poi-*.jar` | Read and write Excel/Word files |
| iText | `itextpdf-*.jar` | Generate PDFs programmatically |
| Bouncy Castle | `bcprov-*.jar` | Cryptography beyond what CF provides |

**CommandBox** can also download JARs:
```bash
# Download Gson into /lib
box install google/gson --directory lib/
```
::

::hint-box
---
:summary: reloadOnChange — leave it off in production
---
`reloadOnChange: true` tells ColdFusion to scan the `loadPaths` directories on a background thread every `watchInterval` seconds and reload the classpath if JAR files have changed. This is genuinely useful in development — drop in a new JAR and CF picks it up without a restart.

In **production**, set `reloadOnChange: false`. The background file-watch thread adds overhead, and you don't want an accidental classpath reload in the middle of serving requests. Your deployment process should handle JAR updates as part of a controlled restart.
::

**Activity:** Create the lib directory and a minimal `Application.cfc`:

```bash
# Create lib directory in the webroot
sudo mkdir -p /opt/coldfusion2025/cfusion/wwwroot/lib

# Create Application.cfc with javaSettings
sudo tee /opt/coldfusion2025/cfusion/wwwroot/Application.cfc << 'EOF'
component {
  this.name = "JavaDemo";
  this.javaSettings = {
    loadPaths: [expandPath("/lib/")],
    reloadOnChange: false
  };
}
EOF

# Touch Application.cfc to force a ColdFusion application re-initialisation
sudo touch /opt/coldfusion2025/cfusion/wwwroot/Application.cfc

# Confirm the app still loads without error
curl -sf http://localhost:8500/java_demo.cfm && echo "Application reloaded OK"
```

---

## 5. JVM diagnostics from CFML

ColdFusion exposes JVM internals through standard Java management APIs. This is the same data that monitoring tools like JConsole and VisualVM read — but you're reading it in ColdFusion, from a `.cfm` page, with zero external tooling.

::image-box
---
:src: __static__/jvm-diagnostics-cfml-v1.png
:alt: ColdFusion page output showing JVM diagnostics — heap usage bar (used MB vs max MB), available CPU count, Java version, OS name, and uptime — all sourced from java.lang.Runtime and java.lang.System
:max-width: 860px
---
_A CFML diagnostic page pulling live JVM metrics — heap, CPUs, version, OS — from standard Java management APIs._
::

```cfml
<cfscript>
  // ── Heap memory ────────────────────────────────────────────────────
  runtime = createObject("java", "java.lang.Runtime").getRuntime();
  maxMem  = int(runtime.maxMemory()   / 1024 / 1024); // bytes → MB
  freeMem = int(runtime.freeMemory()  / 1024 / 1024);
  totMem  = int(runtime.totalMemory() / 1024 / 1024);
  usedMem = totMem - freeMem;

  writeOutput("Heap: " & usedMem & "MB used / " & maxMem & "MB max<br>");
  writeOutput("Free in current allocation: " & freeMem & "MB<br>");

  // ── Available processors ───────────────────────────────────────────
  cpus = runtime.availableProcessors();
  writeOutput("Available CPUs: " & cpus & "<br>");

  // ── Java system properties ─────────────────────────────────────────
  props = createObject("java", "java.lang.System").getProperties();
  writeOutput("Java version: " & props.get("java.version") & "<br>");
  writeOutput("OS: "           & props.get("os.name")      & " "
                               & props.get("os.version")   & "<br>");
  writeOutput("Temp dir: "     & props.get("java.io.tmpdir")& "<br>");
  writeOutput("CF home: "      & props.get("coldfusion.home") & "<br>");
</cfscript>
```

::hint-box
---
:summary: Building a health endpoint with JVM metrics
---
A common pattern is a `/_health.cfm` endpoint that returns JVM metrics as JSON — useful for load balancers, uptime monitors, and dashboards:

```cfml
<cfscript>
  runtime = createObject("java", "java.lang.Runtime").getRuntime();
  props   = createObject("java", "java.lang.System").getProperties();

  health = {
    status:      "ok",
    heapUsedMB:  int((runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024),
    heapMaxMB:   int(runtime.maxMemory()  / 1024 / 1024),
    cpus:        runtime.availableProcessors(),
    javaVersion: props.get("java.version"),
    timestamp:   now()
  };

  cfheader(name="Content-Type", value="application/json");
  writeOutput(serializeJSON(health));
</cfscript>
```

Your load balancer hits `/_health.cfm` every 30 seconds. If `heapUsedMB / heapMaxMB > 0.90`, fire an alert before the OutOfMemoryError hits production.
::

::hint-box
---
:summary: What does "maxMemory" actually mean?
---
The JVM has three memory values that confuse people at first:

| Value | Meaning |
|---|---|
| `maxMemory()` | The absolute ceiling — JVM will never exceed this (set by `-Xmx` flag) |
| `totalMemory()` | Currently allocated heap — may grow up to `maxMemory()` |
| `freeMemory()` | Free bytes within the currently allocated `totalMemory()` |

**Used heap = totalMemory() - freeMemory()**

To control `maxMemory()`, edit ColdFusion's JVM arguments in the CF Admin under **Server Settings → Java and JVM** and change the `-Xmx` value. The default is often 512MB or 1024MB — tune it to roughly 60–70% of available RAM.
::

**Activity:** Add the JVM diagnostics block to `java_demo.cfm` and verify it renders without errors:

```bash
# Append the diagnostics block to java_demo.cfm
sudo tee -a /opt/coldfusion2025/cfusion/wwwroot/java_demo.cfm << 'EOF'

<cfscript>
  runtime = createObject("java", "java.lang.Runtime").getRuntime();
  maxMem  = int(runtime.maxMemory()   / 1024 / 1024);
  freeMem = int(runtime.freeMemory()  / 1024 / 1024);
  totMem  = int(runtime.totalMemory() / 1024 / 1024);
  writeOutput("<hr><strong>JVM Diagnostics</strong><br>");
  writeOutput("Heap: " & (totMem - freeMem) & "MB used / " & maxMem & "MB max<br>");
  writeOutput("CPUs: " & runtime.availableProcessors() & "<br>");
  props = createObject("java", "java.lang.System").getProperties();
  writeOutput("Java: " & props.get("java.version") & "<br>");
</cfscript>
EOF

# Confirm no errors in the response
BODY=$(curl -s http://localhost:8500/java_demo.cfm)
echo "${BODY}" | grep -qi "error\|exception" && echo "ERROR found!" || echo "No errors — diagnostics OK"
```

::simple-task
---
:tasks: tasks
:name: verify_java_output
---
#active
Verify `java_demo.cfm` runs end-to-end without any ColdFusion error or exception in the HTTP response.

#completed
java_demo.cfm runs without errors. ✓
::

---

## 6. Error handling across the Java boundary

Java exceptions are translated into ColdFusion exceptions automatically — you catch them the same way you catch any CF error. The `type` attribute of the exception is the fully-qualified Java exception class name.

```cfml
<cfscript>
  try {
    // ArrayIndexOutOfBoundsException — accessing index 99 on a 3-item list
    list = createObject("java", "java.util.ArrayList").init();
    list.add("only");
    list.add("three");
    list.add("items");
    bad = list.get(99);  // throws java.lang.IndexOutOfBoundsException

  } catch (java.lang.IndexOutOfBoundsException e) {
    writeOutput("Caught specific Java exception: " & e.message & "<br>");

  } catch (any e) {
    writeOutput("Caught general exception: " & e.type & " — " & e.message & "<br>");
  }
</cfscript>
```

::hint-box
---
:summary: Catching specific Java exceptions vs catching "any"
---
Prefer catching specific exception types over `catch(any)` — it makes your error handling self-documenting and prevents silently swallowing unexpected errors.

Common Java exceptions you'll encounter from CFML:

| Exception class | When it's thrown |
|---|---|
| `java.lang.NullPointerException` | Called a method on a null object (usually forgot `.init()`) |
| `java.lang.IndexOutOfBoundsException` | Accessed an ArrayList with an out-of-range index |
| `java.lang.ClassNotFoundException` | The class name is wrong, or the JAR isn't on the classpath |
| `java.lang.ClassCastException` | Passed the wrong type to a method |
| `java.io.IOException` | File read/write failed |
| `java.lang.IllegalArgumentException` | Passed an invalid argument value |

When debugging, always log `e.stackTrace` — it shows the full Java stack and pinpoints exactly which Java method threw the error:

```cfml
catch (any e) {
  writeLog(text = e.type & ": " & e.message & chr(10) & e.stackTrace,
           file = "java_errors", type = "error");
}
```
::

::hint-box
---
:summary: NullPointerException — the #1 beginner mistake
---
The single most common error when starting with Java from CFML is forgetting `.init()`:

```cfml
// WRONG — createObject returns an uninitialised proxy
list = createObject("java", "java.util.ArrayList");
list.add("item");  // NullPointerException!

// CORRECT — .init() calls the constructor
list = createObject("java", "java.util.ArrayList").init();
list.add("item");  // works fine
```

The error message "Object is not a valid Java instance" or `NullPointerException` in a `createObject` context almost always means a missing `.init()`.
::

---

## Key concepts reference

| Concept | CFML syntax |
|---|---|
| Instantiate a class | `createObject("java", "pkg.ClassName").init()` |
| Constructor with arguments | `createObject("java", "pkg.ClassName").init(arg1, arg2)` |
| Call static method | `createObject("java", "pkg.ClassName").staticMethod()` |
| Load custom JARs | `this.javaSettings = { loadPaths: [...] }` in `Application.cfc` |
| Cast to Java primitive | `javaCast("int", 42)` · `javaCast("long", 42)` · `javaCast("boolean", true)` |
| Check JVM memory | `java.lang.Runtime.getRuntime().maxMemory()` |
| Generate UUID | `java.util.UUID.randomUUID().toString()` |
| Sort a collection | `java.util.Collections.sort(arrayListRef)` |
| Ordered map | `java.util.LinkedHashMap` (insertion order) |
| Sorted map | `java.util.TreeMap` (natural key order) |
| Build strings fast | `java.lang.StringBuilder` |
| Catch Java exceptions | `catch (java.lang.ClassName e) { ... }` |

---

When all three tasks above are green, this lesson is complete.

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

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.java-integration-2de4c4c3
---
::
