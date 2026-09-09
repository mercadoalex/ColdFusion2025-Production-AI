---
kind: lesson

title: Integration with Other Technologies
description: |
  Connect ColdFusion with external systems via HTTP, messaging queues,
  LDAP, FTP, and email. Understand integration architectures and
  cross-platform interoperability patterns.

name: integration-other-technologies
slug: integration-other-technologies

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- integration
- cfhttp
- ldap

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_cfhttp_page:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/integration_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "integration_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "integration_demo.cfm is accessible"

  verify_cfhttp_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfhttp_page
    run: |
      FILE="/opt/coldfusion2025/cfusion/wwwroot/integration_demo.cfm"
      if ! grep -qi "cfhttp" "${FILE}" 2>/dev/null; then
        echo "cfhttp not found in integration_demo.cfm"
        exit 1
      fi
      echo "cfhttp is used"

  verify_cfmail_used:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cfhttp_used
    run: |
      COUNT=$(grep -ri "cfmail\|cfmailparam" /opt/coldfusion2025/cfusion/wwwroot/ 2>/dev/null | wc -l)
      if [ "${COUNT}" -lt 1 ]; then
        echo "No cfmail usage found in the project"
        exit 1
      fi
      echo "cfmail is used in ${COUNT} location(s)"
---

## HTTP integration with cfhttp

```cfml
<cfscript>
  cfhttp(
    url    = "https://jsonplaceholder.typicode.com/users",
    method = "GET",
    result = "resp"
  );
  users = deserializeJSON(resp.fileContent);
  for (user in users) {
    writeOutput(user.name & "<br>");
  }
</cfscript>
```

## POST JSON to external API

```cfml
<cfscript>
  payload = serializeJSON({name: "Alex", email: "alex@example.com"});
  cfhttp(
    url         = "https://api.example.com/students",
    method      = "POST",
    result      = "resp",
    charset     = "utf-8"
  ) {
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=payload);
  }
  writeOutput("Status: " & resp.statusCode);
</cfscript>
```

## Send email with cfmail

```cfml
<cfmail
  to      = "student@example.com"
  from    = "noreply@training.dev"
  subject = "Welcome to CF Training"
  type    = "html"
  server  = "localhost"
  port    = "25">
  <p>Hello, welcome to the course!</p>
</cfmail>
```

## FTP operations with cfftp

```cfml
<cfscript>
  cfftp(
    action      = "open",
    username    = "ftpuser",
    password    = "ftppass",
    server      = "ftp.example.com",
    connection  = "myFTP"
  );
  cfftp(action="getFile", connection="myFTP",
        remotefile="/reports/latest.csv",
        localfile=expandPath("/downloads/latest.csv"));
  cfftp(action="close", connection="myFTP");
</cfscript>
```

