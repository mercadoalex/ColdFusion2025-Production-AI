---
kind: lesson

title: PDF, Excel, and ZIP Generation
description: |
  Round out your ColdFusion expertise with document generation features:
  create PDFs with cfdocument, export Excel files with spreadsheet functions,
  compress files with cfzip, and validate form inputs with cfparam.

name: complementary-coldfusion-features
slug: complementary-coldfusion-features

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- pdf
- spreadsheet
- best-practices

playground:
  name: cf-training-devops-3039c6bb

challenges:
  complementary-364af0ee: {}

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
      echo "pdf_demo.cfm is accessible ✓"
    hintcheck: |
      echo "Create pdf_demo.cfm — follow the cfdocument Activity in section 1."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/pdf_demo.cfm ..."

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
      echo "cfdocument/cfpdf is used ✓"
    hintcheck: |
      echo "pdf_demo.cfm must contain <cfdocument> or <cfpdf> to generate a PDF."

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
      echo "export.cfm exists ✓"
    hintcheck: |
      echo "Create export.cfm — follow the SpreadsheetNew() Activity in section 2."
      echo "  sudo tee /opt/coldfusion2025/cfusion/wwwroot/export.cfm ..."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_spreadsheet_page
    run: |
      echo "Complementary features lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
