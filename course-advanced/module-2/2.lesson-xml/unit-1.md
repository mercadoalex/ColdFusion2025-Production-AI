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

**Activity:** Open the **Terminal** tab in your playground, then run the commands below one at a time.

> 💡 **Which tab?** Look at the top of your playground — click the tab labelled **Terminal**. That is a live shell connected to your ColdFusion server. All `bash` commands in this lesson run there.

Create `xml_demo.cfm`:

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

```bash
curl -s http://localhost:8500/xml_demo.cfm
```

::simple-task
---
:tasks: tasks
:name: verify_xml_parse_page
---
#active
Create `xml_demo.cfm` that parses an XML string and returns HTTP 200.

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
Add `XmlSearch()` or `XmlParse()` or `cfxml` to `xml_demo.cfm` — the file must use at least one XML parsing function.

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

**Activity:** Create a data file and an XSLT stylesheet, then transform:

```bash
# Create the data directory
mkdir -p /opt/coldfusion2025/cfusion/wwwroot/data

# Create the XML data file
sudo tee /opt/coldfusion2025/cfusion/wwwroot/data/tickets.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<tickets>
  <ticket id="1" priority="high"><title>Email not working</title></ticket>
  <ticket id="2" priority="low"><title>New monitor request</title></ticket>
</tickets>
EOF

# Create the XSLT stylesheet
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

Create `xslt_demo.cfm`:

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

```bash
curl -s http://localhost:8500/xslt_demo.cfm | grep -o "<td>[^<]*</td>" | head -10
```

::simple-task
---
:tasks: tasks
:name: verify_xslt_page
---
#active
Create `xslt_demo.cfm` that uses `XmlTransform()` and returns HTTP 200.

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

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
xml_demo.cfm and xslt_demo.cfm are both working — hit **Check** to complete the lesson.

#completed
XML processing lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.xml-processing-b371ed76
---
::
