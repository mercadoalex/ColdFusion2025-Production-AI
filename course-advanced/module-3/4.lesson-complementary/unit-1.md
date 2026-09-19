---
kind: unit

title: PDF, Excel, and ZIP Generation

name: complementary-coldfusion-features-unit-1
---

## Document generation in ColdFusion

ColdFusion ships with native support for generating PDFs, Excel spreadsheets, and ZIP archives — no third-party libraries required. These capabilities are frequently requested in enterprise environments: monthly reports, data exports, backup archives.

::image-box
---
:src: __static__/cf-document-generation-v1.png
:alt: Three-panel diagram — left panel shows HTML content flowing into cfdocument to produce a PDF file, centre panel shows a CF query result flowing into spreadsheet functions to produce an .xlsx file, right panel shows a directory of files flowing into cfzip to produce a .zip archive
:max-width: 900px
---
_Three document generation paths: cfdocument → PDF, spreadsheetWrite → Excel, cfzip → ZIP._
::

---

## 1. PDF generation with cfdocument

`<cfdocument>` converts any HTML/CSS content — including dynamic CF output — into a PDF file. You can stream the PDF directly to the browser or save it to a file.

::hint-box
---
:summary: cfdocument and the Flying Saucer renderer
---
ColdFusion 2025 uses the **Flying Saucer** HTML-to-PDF renderer. It supports HTML 4 and CSS 2.1. Modern CSS features (flexbox, grid, CSS variables) are **not** supported. For complex layouts, use table-based HTML inside `<cfdocument>`.

If you need CSS3 support, consider the `cfpdf action="thumbnail"` action or a third-party library like iText.
::

**Activity:** Create `pdf_demo.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/pdf_demo.cfm << 'EOF'
<cfscript>
  // Check if a download is requested
  download = structKeyExists(url, "download") && url.download == "1";
</cfscript>

<cfif download>
  <!--- Stream PDF to the browser --->
  <cfdocument format="PDF" name="pdfContent">
    <html>
    <body style="font-family: Arial, sans-serif;">
      <h1 style="color: #333;">Help Desk Report</h1>
      <p>Generated: <cfoutput>#dateTimeFormat(now(), "yyyy-mm-dd HH:nn")#</cfoutput></p>
      <table border="1" cellpadding="5" style="border-collapse:collapse; width:100%">
        <tr style="background:#eee"><th>ID</th><th>Title</th><th>Priority</th><th>Status</th></tr>
        <cfquery name="tickets" datasource="training_db">
          SELECT id, title, priority, status FROM hd_tickets ORDER BY id
        </cfquery>
        <cfoutput query="tickets">
          <tr>
            <td>#id#</td>
            <td>#htmlEditFormat(title)#</td>
            <td>#priority#</td>
            <td>#status#</td>
          </tr>
        </cfoutput>
      </table>
    </body>
    </html>
  </cfdocument>
  <cfheader name="Content-Disposition" value="attachment; filename=report.pdf">
  <cfcontent type="application/pdf" variable="#toBinary(pdfContent)#">
<cfelse>
  <html><body>
    <h2>PDF Demo</h2>
    <a href="pdf_demo.cfm?download=1">Download PDF Report</a>
  </body></html>
</cfif>
```

```bash
curl -s http://localhost:8500/pdf_demo.cfm | head -5
```

::simple-task
---
:tasks: tasks
:name: verify_pdf_page
---
#active
Create `pdf_demo.cfm` that uses `<cfdocument>` or `<cfpdf>` and returns HTTP 200.

#completed
pdf_demo.cfm is accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_cfdocument_used
---
#active
Confirm `pdf_demo.cfm` contains `cfdocument` or `cfpdf`.

#completed
cfdocument/cfpdf is used. ✓
::

---

## 2. Excel export with spreadsheet functions

ColdFusion's built-in spreadsheet functions generate `.xlsx` files without requiring Excel or any additional software.

**Activity:** Create `export.cfm`:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/export.cfm << 'EOF'
<cfscript>
  // Create a new workbook
  ss = spreadsheetNew("Tickets", true);   // true = .xlsx format

  // Write the header row
  spreadsheetSetCellValue(ss, "ID",       1, 1);
  spreadsheetSetCellValue(ss, "Title",    1, 2);
  spreadsheetSetCellValue(ss, "Priority", 1, 3);
  spreadsheetSetCellValue(ss, "Status",   1, 4);

  // Style the header
  headerStyle = spreadsheetCreateCellStyle(ss);
  headerStyle.setFillForegroundColor(
    createObject("java","org.apache.poi.ss.usermodel.IndexedColors").GREY_25_PERCENT.getIndex()
  );
  headerStyle.setFillPattern(
    createObject("java","org.apache.poi.ss.usermodel.FillPatternType").SOLID_FOREGROUND
  );
  for (col = 1; col <= 4; col++) {
    spreadsheetSetCellStyle(ss, headerStyle, 1, col);
  }

  // Write data rows
  tickets = queryExecute(
    "SELECT id, title, priority, status FROM hd_tickets ORDER BY id",
    {}, { datasource: "training_db" }
  );

  row = 2;
  for (t in tickets) {
    spreadsheetSetCellValue(ss, t.id,       row, 1);
    spreadsheetSetCellValue(ss, t.title,    row, 2);
    spreadsheetSetCellValue(ss, t.priority, row, 3);
    spreadsheetSetCellValue(ss, t.status,   row, 4);
    row++;
  }

  // Stream to browser
  cfheader(name="Content-Disposition", value="attachment; filename=tickets.xlsx");
  cfcontent(type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            variable=toBinary(spreadsheetReadBinary(ss)));
</cfscript>
EOF
```

```bash
# Verify the file returns a non-empty response with an xlsx content-type
curl -s -I http://localhost:8500/export.cfm | grep -i "Content-Disposition\|Content-Type"
```

::simple-task
---
:tasks: tasks
:name: verify_spreadsheet_page
---
#active
Create `export.cfm` at `/opt/coldfusion2025/cfusion/wwwroot/export.cfm`.

#completed
export.cfm exists. ✓
::

---

## 3. ZIP archives with cfzip

`<cfzip>` creates or extracts ZIP archives — useful for packaging multiple reports or attachments for download.

```cfml
<!--- Create a ZIP of all files in the exports directory --->
<cfzip
  action    = "zip"
  file      = "/tmp/exports.zip"
  source    = "/opt/coldfusion2025/cfusion/wwwroot/exports/"
  overwrite = "true">

<!--- Stream the ZIP to the browser --->
<cfheader name="Content-Disposition" value="attachment; filename=exports.zip">
<cfcontent type="application/zip" file="/tmp/exports.zip" deleteFile="true">
```

Extracting:

```cfml
<cfzip
  action      = "unzip"
  file        = "/tmp/upload.zip"
  destination = "/opt/coldfusion2025/cfusion/wwwroot/extracted/"
  overwrite   = "true">
```

---

## 4. Server-side form validation with cfparam

`<cfparam>` validates URL or form parameters, throwing an exception if validation fails — eliminating boilerplate validation code.

```cfml
<cfparam name="form.name"  type="string"  minlength="2" maxlength="100">
<cfparam name="form.email" type="email">
<cfparam name="form.age"   type="integer" min="18"      max="120">
<cfparam name="form.score" type="float"   min="0.0"     max="100.0">
```

::hint-box
---
:summary: cfparam vs manual validation — which to use?
---
Use `cfparam` for simple, declarative type and range validation at the top of a page. For complex business rules (unique email check, conditional required fields), write explicit `<cfif>` logic — `cfparam` is not designed for that.

A common pattern: `cfparam` for basic type-safety, then a validation CFC for business rules.
::

---

## Key concepts reference

| Feature | Tag / Function |
|---|---|
| PDF from HTML | `<cfdocument format="PDF" name="varName">` |
| PDF to browser | `<cfcontent type="application/pdf" variable="#toBinary(varName)#">` |
| New workbook | `spreadsheetNew("SheetName", true)` |
| Write cell | `spreadsheetSetCellValue(ss, value, row, col)` |
| Stream Excel | `cfcontent(type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ...)` |
| Create ZIP | `<cfzip action="zip" file="/path/to.zip" source="/dir/">` |
| Validate params | `<cfparam name="form.field" type="email">` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
pdf_demo.cfm and export.cfm are both in place — hit **Check** to complete the lesson.

#completed
Complementary features lesson complete. On to the next one! ✓
::

---

## Now Prove It

::card
---
:challenge: challenges.complementary-364af0ee
---
::
