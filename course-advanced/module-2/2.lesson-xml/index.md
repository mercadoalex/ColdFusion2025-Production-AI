---
kind: lesson

title: XML Processing — XPath and XSLT
description: |
  Parse and transform XML documents in ColdFusion using XPath expressions
  and XSLT stylesheets. Work with cfxml, XmlSearch(), and XmlTransform()
  for real-world data integration scenarios.

name: xml-processing-xpath-xslt
slug: xml-processing-xpath-xslt

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- xml
- xpath
- xslt

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  xml-processing-XXXXXXXX: {}

tasks:
  verify_xml_parse_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/xml_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "xml_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "xml_demo.cfm is accessible ✓"

  verify_xpath_usage:
    machine: cf-dev
    user: laborant
    needs:
      - verify_xml_parse_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/xml_demo.cfm"
      if ! grep -qi "XmlSearch\|XmlParse\|cfxml" "${FILE}" 2>/dev/null; then
        echo "No XML parsing found in xml_demo.cfm"
        exit 1
      fi
      echo "XML parsing/XPath usage found ✓"

  verify_xslt_page:
    machine: cf-dev
    user: laborant
    needs:
      - verify_xpath_usage
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/xslt_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "xslt_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "xslt_demo.cfm is accessible ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_xslt_page
    run: |
      echo "XML processing lesson complete ✓"
---
