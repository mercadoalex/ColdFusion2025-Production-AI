---
kind: lesson

title: Complementary ColdFusion Features
description: |
  Round out your ColdFusion expertise with platform features that
  don't fit neatly elsewhere: PDF generation, spreadsheet handling,
  ZIP manipulation, server-side validation, and enterprise best practices.

name: complementary-coldfusion-features
slug: complementary-coldfusion-features

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- pdf
- spreadsheet
- best-practices

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_pdf_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/pdf_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "pdf_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "pdf_demo.cfm is accessible"

  verify_cfdocument_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_pdf_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/pdf_demo.cfm"
      if ! grep -qi "cfdocument\|cfpdf" "${FILE}" 2>/dev/null; then
        echo "cfdocument/cfpdf not found in pdf_demo.cfm"
        exit 1
      fi
      echo "cfdocument/cfpdf is used"

  verify_spreadsheet_page:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfdocument_used
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/export.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "export.cfm not found"
        exit 1
      fi
      echo "export.cfm exists"
---

## PDF generation with cfdocument

```cfml
<cfdocument format="PDF" filename="/tmp/report.pdf" overwrite="true">
  <html>
  <body>
    <h1>Student Report</h1>
    <cfquery name="students" datasource="training_db">
      SELECT name, score FROM students ORDER BY score DESC
    </cfquery>
    <table border="1">
      <tr><th>Name</th><th>Score</th></tr>
      <cfoutput query="students">
        <tr><td>#name#</td><td>#score#</td></tr>
      </cfoutput>
    </table>
  </body>
  </html>
</cfdocument>
<cfoutput>PDF saved to /tmp/report.pdf</cfoutput>
```

## Excel export with spreadsheet functions

```cfml
<cfscript>
  students = queryExecute("SELECT name, score FROM students", {}, {datasource:"training_db"});

  ss = spreadsheetNew("Students", true);
  spreadsheetSetHeader(ss, "Name,Score");

  row = 2;
  for (s in students) {
    spreadsheetSetCellValue(ss, s.name,  row, 1);
    spreadsheetSetCellValue(ss, s.score, row, 2);
    row++;
  }

  spreadsheetWrite(ss, expandPath("/exports/students.xlsx"), true);
  writeOutput("Excel exported");
</cfscript>
```

## ZIP files with cfzip

```cfml
<cfzip action="zip"
       file="/tmp/reports.zip"
       source="/opt/coldfusion2025/cfusion/wwwroot/exports/"
       overwrite="true">
```

## Server-side form validation with cfparam

```cfml
<cfparam name="form.name"  type="string"  minlength="2" maxlength="100">
<cfparam name="form.email" type="email">
<cfparam name="form.age"   type="integer" min="18" max="120">
```

