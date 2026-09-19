---
kind: challenge

title: 'Parse and Transform an XML Feed'

description: |
  Parse an XML data feed using XPath, extract specific fields,
  and transform the document with an XSLT stylesheet into an HTML table.

categories:
  - programming

tagz:
  - coldfusion
  - xml
  - xpath
  - xslt

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  xml_parse_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/xml_challenge.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "xml_challenge.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "xml_challenge.cfm accessible ✓"

  xpath_results:
    machine: cf-dev
    user: laborant
    needs:
      - xml_parse_page
    run: |
      BODY=$(curl -s http://localhost:8500/xml_challenge.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "xml_challenge.cfm is throwing an error"
        exit 1
      fi
      if ! echo "${BODY}" | grep -qi "high\|medium\|low\|critical"; then
        echo "No priority values found — XPath extraction may not be working"
        exit 1
      fi
      echo "XPath results found in output ✓"

  xslt_transform_page:
    machine: cf-dev
    user: laborant
    needs:
      - xpath_results
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/xslt_challenge.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "xslt_challenge.cfm not found (got ${STATUS})"
        exit 1
      fi
      BODY=$(curl -s http://localhost:8500/xslt_challenge.cfm)
      if ! echo "${BODY}" | grep -qi "<table\|<tr\|<td"; then
        echo "XSLT output does not contain an HTML table"
        exit 1
      fi
      echo "XSLT transformation produces HTML table ✓"
---

## Parse and Transform an XML Feed

Work with an XML data feed about help desk tickets using XPath and XSLT.

### Part 1 — XPath extraction (xml_challenge.cfm)

Create `xml_challenge.cfm` that:
1. Parses this XML string:
```xml
<tickets>
  <ticket id="1" priority="high"><title>Email down</title><dept>IT</dept></ticket>
  <ticket id="2" priority="low"><title>New chair needed</title><dept>HR</dept></ticket>
  <ticket id="3" priority="critical"><title>Server unresponsive</title><dept>IT</dept></ticket>
</tickets>
```
2. Uses `XmlSearch()` to extract all tickets with `priority="high"` or `priority="critical"`
3. Outputs their titles and priorities

### Part 2 — XSLT transformation (xslt_challenge.cfm)

Create `xslt_challenge.cfm` that:
1. Parses the same XML
2. Applies an XSLT stylesheet that converts it to an HTML `<table>`
3. Returns the HTML table

::simple-task
---
:tasks: tasks
:name: xml_parse_page
---
#active
Create `xml_challenge.cfm` that parses XML and returns HTTP 200.

#completed
xml_challenge.cfm accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: xpath_results
---
#active
Use XPath to extract and display ticket priorities — output must contain "high", "medium", "low", or "critical".

#completed
XPath results found. ✓
::

::simple-task
---
:tasks: tasks
:name: xslt_transform_page
---
#active
Create `xslt_challenge.cfm` that applies an XSLT transformation and outputs an HTML table.

#completed
XSLT transformation produces HTML table. ✓
::
