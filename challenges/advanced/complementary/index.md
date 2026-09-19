---
kind: challenge

title: 'Generate a PDF Ticket Report and Excel Export'

description: |
  Create a PDF report of open help desk tickets using cfdocument,
  and an Excel export of all tickets using ColdFusion spreadsheet functions.

categories:
  - programming

tagz:
  - coldfusion
  - pdf
  - spreadsheet

difficulty: easy

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  pdf_report_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/ticket_report.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "ticket_report.cfm not found (got ${STATUS})"
        exit 1
      fi
      FILE="/opt/coldfusion2025/cfusion/wwwroot/ticket_report.cfm"
      if ! grep -qi "cfdocument\|cfpdf" "${FILE}" 2>/dev/null; then
        echo "ticket_report.cfm does not use cfdocument or cfpdf"
        exit 1
      fi
      echo "ticket_report.cfm with cfdocument found ✓"

  excel_export_page:
    machine: cf-dev
    user: laborant
    needs:
      - pdf_report_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/ticket_export.cfm"
      if [ ! -f "${FILE}" ]; then
        echo "ticket_export.cfm not found"
        exit 1
      fi
      if ! grep -qi "spreadsheetNew\|spreadsheetSetCellValue\|spreadsheetWrite" "${FILE}"; then
        echo "ticket_export.cfm does not use spreadsheet functions"
        exit 1
      fi
      echo "ticket_export.cfm with spreadsheet functions found ✓"

  zip_archive_created:
    machine: cf-dev
    user: laborant
    needs:
      - excel_export_page
    run: |
      FILE=$(find /opt/coldfusion2025/cfusion/wwwroot -name "*.cfm" \
              -exec grep -li "cfzip" {} \; 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No cfzip usage found — add a ZIP download endpoint"
        exit 1
      fi
      echo "cfzip usage found in ${FILE} ✓"
---

## Generate a PDF Ticket Report and Excel Export

### Part 1 — ticket_report.cfm

Create a page that:
1. Queries all open tickets from `hd_tickets`
2. Uses `<cfdocument format="PDF">` to wrap an HTML table of the tickets
3. Streams the PDF to the browser with `Content-Disposition: attachment`

### Part 2 — ticket_export.cfm

Create a page that:
1. Queries all tickets from `hd_tickets`
2. Creates an `.xlsx` workbook with `spreadsheetNew()`
3. Writes ticket data row by row
4. Streams the file to the browser

### Bonus — add a ZIP download

Create any page that uses `<cfzip>` to package multiple files for download.

::simple-task
---
:tasks: tasks
:name: pdf_report_page
---
#active
Create `ticket_report.cfm` using `<cfdocument>`.

#completed
ticket_report.cfm with cfdocument found. ✓
::

::simple-task
---
:tasks: tasks
:name: excel_export_page
---
#active
Create `ticket_export.cfm` using spreadsheet functions.

#completed
ticket_export.cfm with spreadsheet functions found. ✓
::

::simple-task
---
:tasks: tasks
:name: zip_archive_created
---
#active
Add a `<cfzip>` call to any page in the webroot.

#completed
cfzip usage found. ✓
::
