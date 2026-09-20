---
kind: unit

title: External Integration — cfhttp and cfmail

name: integration-other-technologies-unit-1
---

## Connecting ColdFusion to the outside world

Modern applications don't run in isolation — they call payment APIs, send email notifications, retrieve data feeds, and push events to external services. ColdFusion has first-class built-in support for these integrations through `<cfhttp>` (HTTP client) and `<cfmail>` (SMTP email).

::image-box
---
:src: __static__/cfml-integration-overview-v1.png
:alt: Diagram with cf-dev at the centre — arrows pointing outward to four external systems: a REST API labelled cfhttp GET/POST, an SMTP mail server labelled cfmail, an FTP server labelled cfftp, and an LDAP directory labelled cfldap — illustrating the range of ColdFusion's built-in integration capabilities
:max-width: 860px
---
_ColdFusion's built-in integration tags handle HTTP, email, FTP, and LDAP — no third-party libraries needed._
::

---

## 1. Consuming REST APIs with cfhttp

`<cfhttp>` is ColdFusion's HTTP client. It handles all HTTP verbs, custom headers, authentication, cookies, timeouts, and SSL.

**Activity:** Create `integration_demo.cfm` that calls a public REST API:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/integration_demo.cfm << 'EOF'
<cfscript>
  // ── GET: fetch public JSON data ─────────────────────────────────────
  cfhttp(
    url    = "https://jsonplaceholder.typicode.com/todos/1",
    method = "GET",
    result = "resp"
  );

  if (resp.statusCode contains "200") {
    todo = deserializeJSON(resp.fileContent);
    writeOutput("<strong>Todo #todo.id#:</strong> " & todo.title & "<br>");
    writeOutput("Completed: " & (todo.completed ? "yes" : "no") & "<br>");
  } else {
    writeOutput("Request failed: " & resp.statusCode);
  }
</cfscript>
EOF
```

```bash
curl -s http://localhost:8500/integration_demo.cfm
```

::simple-task
---
:tasks: tasks
:name: verify_cfhttp_page
---
#active
Create `integration_demo.cfm` that makes a `cfhttp` call and returns HTTP 200.

#completed
integration_demo.cfm is accessible. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_cfhttp_used
---
#active
Confirm `integration_demo.cfm` uses `cfhttp`.

#completed
cfhttp is used. ✓
::

---

## 2. POST JSON to an external API

Most modern APIs expect JSON in the request body. Use `cfhttpparam` to set the `Content-Type` header and body:

```cfml
<cfscript>
  // Build the payload
  newTicket = {
    title:       "Printer not working in Room 201",
    description: "The HP LaserJet shows an offline status",
    priority:    "high",
    userId:      42
  };

  cfhttp(
    url     = "https://jsonplaceholder.typicode.com/posts",
    method  = "POST",
    result  = "resp",
    charset = "utf-8"
  ) {
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body",   value=serializeJSON(newTicket));
  }

  writeOutput("Status: " & resp.statusCode & "<br>");
  if (isJSON(resp.fileContent)) {
    created = deserializeJSON(resp.fileContent);
    writeOutput("Created ID: " & (created.id ?: "n/a") & "<br>");
  }
</cfscript>
```

::hint-box
---
:summary: cfhttp timeout and error handling
---
Always set a timeout on external HTTP calls — external services can hang indefinitely:

```cfml
cfhttp(url="...", method="GET", result="resp", timeout=10) { ... }
```

And check the status before using the response:

```cfml
if (!resp.statusCode contains "200") {
  throw(type="IntegrationError", message="API call failed: " & resp.statusCode);
}
```

Never parse `resp.fileContent` without first confirming the response was successful.
::

---

## 3. Send email with cfmail

`<cfmail>` connects to an SMTP server and sends email. In the lab, a local stub SMTP server accepts all mail without actually delivering it.

**Activity:** Add an email notification to your integration page:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/send_notification.cfm << 'EOF'
<cfscript>
  // Send a plain text notification
  cfmail(
    to      = "support@training.dev",
    from    = "noreply@training.dev",
    subject = "New high-priority ticket",
    server  = "localhost",
    port    = 25
  ) {
    writeOutput("A new high-priority ticket has been created.
Please review it at http://localhost:8500/tickets.cfm");
  }

  writeOutput("Notification sent ✓");
</cfscript>
EOF
```

For HTML email with attachments, use `type="html"` and `cfmailparam`:

```cfml
<cfmail
  to      = "manager@training.dev"
  from    = "noreply@training.dev"
  subject = "Weekly Ticket Report"
  type    = "html"
  server  = "localhost"
  port    = 25>

  <h2>Open Tickets This Week</h2>
  <cfoutput query="openTickets">
    <p>#title# — Priority: #priority#</p>
  </cfoutput>

  <cfmailparam file="/tmp/report.pdf" disposition="attachment">
</cfmail>
```

::image-box
---
:src: __static__/cfmail-flow-v1.png
:alt: Flow diagram showing a CFML page calling cfmail, which connects to an SMTP server on port 25, which queues the message in ColdFusion's mail spool directory, and finally delivers the message to the recipient's mail server — with a note that in the lab the SMTP server is a local stub that accepts but does not deliver
:max-width: 860px
---
_cfmail flow: CFML page → SMTP server → mail spool → delivery. In the lab, the SMTP stub accepts all mail._
::

::simple-task
---
:tasks: tasks
:name: verify_cfmail_used
---
#active
Create any `.cfm` file under the CF webroot that contains a `cfmail` or `cfmailparam` call.

#completed
cfmail is used. ✓
::

---

## 4. FTP with cfftp

`<cfftp>` supports uploading, downloading, and listing files on FTP servers:

```cfml
<cfscript>
  // Open a connection
  cfftp(
    action     = "open",
    username   = "ftpuser",
    password   = "ftppass",
    server     = "ftp.example.com",
    connection = "myFTP"
  );

  // Download a file
  cfftp(
    action     = "getFile",
    connection = "myFTP",
    remotefile = "/reports/latest.csv",
    localfile  = expandPath("/downloads/latest.csv")
  );

  // Close the connection
  cfftp(action="close", connection="myFTP");
</cfscript>
```

---

## Key concepts reference

| Tag / function | Purpose |
|---|---|
| `cfhttp` | HTTP client — GET, POST, PUT, DELETE, PATCH |
| `cfhttpparam type="header"` | Add a request header |
| `cfhttpparam type="body"` | Set a raw request body (JSON, XML) |
| `cfhttpparam type="formfield"` | Add a form field (multipart or URL-encoded) |
| `cfmail` | Send email via SMTP |
| `cfmailparam` | Add attachment or custom header to cfmail |
| `cfftp` | FTP file transfer |
| `resp.statusCode` | HTTP response status (e.g. `"200 OK"`) |
| `resp.fileContent` | Response body as string |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
cfhttp and cfmail are both in use — hit **Check** to complete the lesson.

#completed
Integration lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.integration-001a9503
---
::
