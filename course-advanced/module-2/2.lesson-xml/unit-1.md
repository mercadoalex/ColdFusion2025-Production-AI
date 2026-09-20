---
kind: unit

title: XML Processing — XPath and XSLT

name: xml-processing-xpath-xslt-unit-1
---

## XML in ColdFusion — why it still matters

Despite JSON's dominance in modern APIs, XML remains essential in enterprise ColdFusion environments: SOAP web services, government data feeds, EDI integrations, Office Open XML (`.docx`, `.xlsx`), and legacy system interfaces all speak XML. ColdFusion has first-class XML support built into the language core.

::image-box
---
:src: __static__/xml-processing-overview-v1.png
:alt: Three-panel diagram showing the three main XML operations in ColdFusion — left panel shows cfxml/XmlNew creating an XML document, centre panel shows XmlSearch with an XPath expression selecting nodes, right panel shows XmlTransform applying an XSLT stylesheet to produce HTML output
:max-width: 900px
---
_The three XML operations you'll master: create, query with XPath, and transform with XSLT._
::

| ColdFusion function | Purpose |
|---|---|
| `XmlNew()` / `cfxml` | Create an XML document from scratch |
| `XmlParse()` | Parse an XML string or URL into a ColdFusion XML object |
| `XmlSearch(doc, xpath)` | Select nodes using XPath 1.0 expressions |
| `XmlTransform(xml, xsl)` | Apply an XSLT stylesheet to produce new output |
| `toString(xmlDoc)` | Serialise a ColdFusion XML object back to a string |

---

## 1. Parsing XML

The most common starting point: you receive an XML string from an API or file, and you need to extract data from it.

```cfml
<cfscript>
  xmlStr = '<?xml version="1.0" encoding="UTF-8"?>
  <helpdesk>
    <ticket id="1" priority="high">
      <title>Email not working</title>
      <department>IT</department>
      <status>open</status>
    </ticket>
    <ticket id="2" priority="low">
      <title>New monitor request</title>
      <department>HR</department>
      <status>closed</status>
    </ticket>
  </helpdesk>';

  doc = xmlParse(xmlStr);

  // Access the root element
  writeOutput("Root: " & doc.xmlRoot.xmlName & "<br>");

  // Access first child by index
  first = doc.helpdesk.ticket[1];
  writeOutput("Ticket 1: " & first.title.xmlText & "<br>");
</cfscript>
```

::hint-box
---
:summary: ColdFusion XML objects are case-sensitive
---
Unlike most of CFML, XML element and attribute names **are case-sensitive** when accessed via dot notation on the parsed document. `doc.helpdesk` works if the root element is `<helpdesk>` — `doc.HelpDesk` would throw an error.

The safe alternative is always `XmlSearch()` with XPath, which handles case naturally:
```cfml
nodes = XmlSearch(doc, "//ticket");
```
::

**Activity — Terminal (dev):** You are logged in as `laborant` with `sudo` access. **Copy each block below, paste it into the Terminal (dev) tab, and press Enter. Wait for the shell prompt (`$`) to return before running the next one.**

Create `xml_demo.cfm` — paste this entire block at once and press Enter:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/xml_demo.cfm << 'EOF'
<cfscript>
  xmlStr = '<tickets>
    <ticket id="1"><title>Printer not working</title><priority>high</priority></ticket>
    <ticket id="2"><title>VPN issues</title><priority>medium</priority></ticket>
    <ticket id="3"><title>Password reset</title><priority>low</priority></ticket>
  </tickets>';

  doc = XmlParse(xmlStr);

  // XPath: select all ticket elements
  tickets = XmlSearch(doc, "//ticket");
  for (t in tickets) {
    writeOutput(t.XmlAttributes.id & ": " & t.title.XmlText
                & " [" & t.priority.XmlText & "]<br>");
  }
</cfscript>
EOF
```

Verify it is reachable — paste and press Enter:

```bash
curl -s http://localhost:8500/xml_demo.cfm
```

**Expected output:**

```
1: Printer not working [high]<br>2: VPN issues [medium]<br>3: Password reset [low]<br>
```

Each ticket is printed as `id: title [priority]` followed by an HTML `<br>` tag — one line per ticket, no spaces between them because the browser would render the line breaks visually.

Once you see that output, the task below will turn green automatically.

::simple-task
---
:tasks: tasks
:name: verify_xml_parse_page
---
#active
Runs automatically — verifies that `xml_demo.cfm` is reachable and returns HTTP 200.

#completed
xml_demo.cfm is accessible. ✓
::

---

## 2. XPath — selecting nodes precisely

XPath is a query language for navigating XML documents. ColdFusion implements XPath 1.0 through the `XmlSearch()` function.

::image-box
---
:src: __static__/xpath-expressions-cheatsheet-v1.png
:alt: XPath cheat sheet showing six common expression patterns — // for any descendant, @attr for attribute access, [predicate] for filtering, text() for text content, parent/child for path navigation, and position() for index-based selection — each with a CFML XmlSearch example
:max-width: 860px
---
_Common XPath expressions — these cover 90% of real-world XML parsing needs._
::

```cfml
<cfscript>
  doc = XmlParse(expandPath("/data/tickets.xml"));

  // ── All tickets ─────────────────────────────────────────────────────
  all = XmlSearch(doc, "//ticket");
  writeOutput("Total tickets: " & arrayLen(all) & "<br>");

  // ── Only high priority ──────────────────────────────────────────────
  high = XmlSearch(doc, "//ticket[@priority='high']");
  writeOutput("High priority: " & arrayLen(high) & "<br>");

  // ── Titles of open tickets ──────────────────────────────────────────
  open = XmlSearch(doc, "//ticket[status='open']/title");
  for (t in open) {
    writeOutput("Open: " & t.XmlText & "<br>");
  }

  // ── Attribute value of first ticket ────────────────────────────────
  firstId = XmlSearch(doc, "string(//ticket[1]/@id)");
  writeOutput("First ticket ID: " & firstId & "<br>");
</cfscript>
```

::simple-task
---
:tasks: tasks
:name: verify_xpath_usage
---
#active
Runs automatically — verifies that `xml_demo.cfm` contains at least one XML function (`XmlSearch`, `XmlParse`, or `cfxml`).

#completed
XML parsing/XPath usage found. ✓
::

---

## 3. Creating XML documents

You can build XML from scratch using `XmlNew()` and `XmlElemNew()`, or by using the `cfxml` tag with inline markup.

**cfxml approach (recommended for readable templates):**

```cfml
<cfxml variable="ticketXml">
  <tickets generated="#dateTimeFormat(now(), 'yyyy-mm-dd')#">
    <cfoutput query="tickets">
      <ticket id="#tickets.id#" priority="#tickets.priority#">
        <title>#XmlFormat(tickets.title)#</title>
        <department>#XmlFormat(tickets.department)#</department>
      </ticket>
    </cfoutput>
  </tickets>
</cfxml>

<!--- Serialise to string --->
<cfoutput>#toString(ticketXml)#</cfoutput>
```

::hint-box
---
:summary: Always use XmlFormat() for user data in XML
---
`XmlFormat()` escapes the five special XML characters: `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&apos;`. Skipping this is an XML injection vulnerability — user input containing `<` will break the document structure.
::

---

## 4. XSLT transformation

XSLT (eXtensible Stylesheet Language Transformations) converts an XML document into a different format — HTML, plain text, or another XML vocabulary — using a stylesheet.

**Activity — Terminal (dev):** You need to create three files on the server and then verify the result. Every command below runs in the **Terminal (dev)** tab. You are logged in as `laborant` — `sudo` is available and required.

> ⚠️ **Important:** copy each block **in full**, paste it into the **Terminal (dev)** tab, and press **Enter**. Wait until you see the shell prompt (`laborant@cf-dev:~$`) again before moving to the next step. Do not run two blocks at once.

---

**Step 1 of 5 — create the `/data` directory on the server**

This is where your XML and XSL files will live. ColdFusion's `expandPath()` maps `/data` to this folder.

```bash
sudo mkdir -p /opt/coldfusion2025/cfusion/wwwroot/data
```

You will see no output — that is normal. The prompt returns immediately when the directory is ready.

---

**Step 2 of 5 — create the XML data file (`tickets.xml`)**

This is the raw data that XSLT will transform. Copy the entire block — from `sudo tee` all the way to the final `EOF` — and paste it as one unit.

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/data/tickets.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<tickets>
  <ticket id="1" priority="high"><title>Email not working</title></ticket>
  <ticket id="2" priority="low"><title>New monitor request</title></ticket>
</tickets>
EOF
```

You should see the XML content echoed back to the Terminal — that confirms `tee` wrote the file.

Then verify the file is actually on disk:

```bash
cat /opt/coldfusion2025/cfusion/wwwroot/data/tickets.xml
```

**Expected output:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tickets>
  <ticket id="1" priority="high"><title>Email not working</title></ticket>
  <ticket id="2" priority="low"><title>New monitor request</title></ticket>
</tickets>
```

If you see that, the file is in place and ready for the transformation step.

---

**Step 3 of 5 — create the XSLT stylesheet (`tickets.xsl`)**

This stylesheet tells ColdFusion how to turn the XML into an HTML table. Again, copy the whole block from `sudo tee` to the final `EOF`.

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/data/tickets.xsl << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" indent="yes"/>
  <xsl:template match="/">
    <html><body>
      <h2>Open Tickets</h2>
      <table border="1">
        <tr><th>ID</th><th>Priority</th><th>Title</th></tr>
        <xsl:for-each select="//ticket">
          <tr>
            <td><xsl:value-of select="@id"/></td>
            <td><xsl:value-of select="@priority"/></td>
            <td><xsl:value-of select="title"/></td>
          </tr>
        </xsl:for-each>
      </table>
    </body></html>
  </xsl:template>
</xsl:stylesheet>
EOF
```

You should see the XSL content echoed back — same as step 2.

---

**Step 4 of 5 — create the ColdFusion page (`xslt_demo.cfm`)**

This is the CFML file that loads both files and runs the transformation.

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/xslt_demo.cfm << 'EOF'
<cfscript>
  xmlDoc = XmlParse(expandPath("/data/tickets.xml"));
  xslDoc = XmlParse(expandPath("/data/tickets.xsl"));
  result = XmlTransform(xmlDoc, xslDoc);
  writeOutput(result);
</cfscript>
EOF
```

---

**Step 5 of 5 — verify the transformation runs correctly**

The task box below is the verification. It runs `curl` against `xslt_demo.cfm` and checks for HTTP 200. Once all four files from steps 1–4 are in place it will turn green automatically — no extra command needed.

If you want to see the raw HTML output yourself first, run this in **Terminal (dev)**:

```bash
curl -s http://localhost:8500/xslt_demo.cfm | grep -o "<td>[^<]*</td>" | head -10
```

**Expected output:**

```
<td>1</td><td>high</td><td>Email not working</td>
<td>2</td><td>low</td><td>New monitor request</td>
```

::simple-task
---
:tasks: tasks
:name: verify_xslt_page
---
#active
Runs automatically — checks that `xslt_demo.cfm` is reachable and returns HTTP 200. Complete steps 1–4 above and this turns green on its own.

#completed
xslt_demo.cfm is accessible. ✓
::

---

## Key concepts reference

| Function | Usage |
|---|---|
| `XmlParse(string/url)` | Parse XML string or URL into CF XML object |
| `XmlNew()` | Create empty XML document |
| `XmlElemNew(doc, "tag")` | Create a new element node |
| `XmlSearch(doc, xpath)` | Select nodes using XPath — returns array |
| `XmlTransform(xml, xsl)` | Apply XSLT stylesheet, returns result string |
| `XmlFormat(str)` | Escape special characters for safe embedding |
| `toString(xmlObj)` | Serialise CF XML object back to string |

---

When tasks 1–3 above are all green, this turns green automatically.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once `xml_demo.cfm` and `xslt_demo.cfm` are both verified.

#completed
XML processing lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.xml-processing-b371ed76
---
::
