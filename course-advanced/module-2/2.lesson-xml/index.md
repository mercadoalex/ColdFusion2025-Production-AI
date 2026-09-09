---
kind: lesson

title: Handling and Integration with XML
description: |
  Create, parse, manipulate and transform XML documents in ColdFusion.
  Integrate XML with web services, apply XSLT transforms,
  and handle real-world XML data interchange.

name: xml-handling-integration
slug: xml-handling-integration

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- xml
- xslt

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_xml_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/xml_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "xml_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "xml_demo.cfm is accessible"

  verify_xml_parse:
    machine: cf-dev
    user: laborant
    needs:
      - verify_xml_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/xml_demo.cfm"
      if ! grep -qi "xmlParse\|xmlNew\|XmlSearch" "${FILE}" 2>/dev/null; then
        echo "No XML functions found in xml_demo.cfm"
        exit 1
      fi
      echo "XML functions are used"

  verify_xml_output:
    machine: cf-dev
    user: laborant
    needs:
      - verify_xml_parse
    run: |
      BODY=$(curl -s http://localhost:8500/xml_demo.cfm)
      if echo "${BODY}" | grep -qi "error\|exception"; then
        echo "xml_demo.cfm is throwing an error"
        exit 1
      fi
      echo "xml_demo.cfm runs without errors"
---

## Create XML

```cfml
<cfscript>
  doc = xmlNew();
  doc.xmlRoot = xmlElemNew(doc, "students");

  student = xmlElemNew(doc, "student");
  student.xmlAttributes["id"] = "1";
  student.name = xmlElemNew(doc, "name");
  student.name.xmlText = "Alex";

  arrayAppend(doc.students.xmlChildren, student);
  writeOutput(toString(doc));
</cfscript>
```

## Parse XML string

```cfml
<cfscript>
  xmlStr = '<?xml version="1.0"?>
  <students>
    <student id="1"><name>Alex</name><score>95</score></student>
    <student id="2"><name>Maria</name><score>88</score></student>
  </students>';

  doc = xmlParse(xmlStr);

  // XPath search
  nodes = xmlSearch(doc, "//student");
  for (node in nodes) {
    writeOutput(node.name.xmlText & ": " & node.score.xmlText & "<br>");
  }
</cfscript>
```

## XSLT transformation

```cfml
<cfscript>
  xmlDoc  = xmlParse(expandPath("/data/students.xml"));
  xslDoc  = xmlParse(expandPath("/transforms/students.xsl"));
  result  = xmlTransform(xmlDoc, xslDoc);
  writeOutput(result);
</cfscript>
```

## Read XML from URL

```cfml
<cfhttp url="https://api.example.com/students.xml" method="get" result="resp">
<cfscript>
  doc = xmlParse(resp.fileContent);
  nodes = xmlSearch(doc, "//student/name");
  for (n in nodes) {
    writeOutput(n.xmlText & "<br>");
  }
</cfscript>
```

