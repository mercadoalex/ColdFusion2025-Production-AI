<!---
  /api/tickets.cfm
  Lightweight REST endpoint for the Help Desk tickets resource.

  GET  /api/tickets.cfm          — list all tickets (summary fields)
  GET  /api/tickets.cfm?id=N     — get one ticket with comments
  POST /api/tickets.cfm          — create a ticket (JSON body: title, description, user_id, priority)
  DELETE /api/tickets.cfm?id=N   — close a ticket (sets status = 'closed')
--->
<cfscript>
  // ── helpers ──────────────────────────────────────────────────────────────
  function jsonError(numeric code, string msg) {
    cfheader(statuscode=arguments.code, statustext=arguments.msg);
    cfheader(name="Content-Type", value="application/json");
    writeOutput(serializeJSON({ "error": arguments.msg, "code": arguments.code }));
    abort;
  }

  function send(any data, numeric code=200) {
    cfheader(statuscode=arguments.code, statustext="OK");
    cfheader(name="Content-Type", value="application/json");
    cfheader(name="Access-Control-Allow-Origin", value="*");
    writeOutput(serializeJSON(arguments.data));
    abort;
  }

  method = cgi.REQUEST_METHOD;

  // ── GET ──────────────────────────────────────────────────────────────────
  if (method == "GET") {

    if (structKeyExists(url, "id")) {
      // single ticket + its comments
      id = val(url.id);
      if (id LTE 0) { jsonError(400, "id must be a positive integer"); }

      qTicket = queryExecute(
        "SELECT t.id, t.title, t.description, t.status, t.priority,
                t.created_at, u.name AS submitter
         FROM   hd_tickets t
         JOIN   hd_users   u ON u.id = t.user_id
         WHERE  t.id = :id",
        { id: { value: id, cfsqltype: "cf_sql_integer" } },
        { datasource: "training_db" }
      );

      if (qTicket.recordCount == 0) { jsonError(404, "Ticket #id# not found"); }

      qComments = queryExecute(
        "SELECT c.id, c.comment_text, c.created_at, u.name AS author
         FROM   hd_comments c
         JOIN   hd_users    u ON u.id = c.user_id
         WHERE  c.ticket_id = :id
         ORDER  BY c.created_at",
        { id: { value: id, cfsqltype: "cf_sql_integer" } },
        { datasource: "training_db" }
      );

      ticket = {
        "id":          qTicket.id,
        "title":       qTicket.title,
        "description": qTicket.description,
        "status":      qTicket.status,
        "priority":    qTicket.priority,
        "created_at":  qTicket.created_at,
        "submitter":   qTicket.submitter,
        "comments":    queryToArray(qComments)
      };
      send(ticket);
    }

    // list all tickets
    qList = queryExecute(
      "SELECT t.id, t.title, t.status, t.priority, t.created_at, u.name AS submitter
       FROM   hd_tickets t
       JOIN   hd_users   u ON u.id = t.user_id
       ORDER  BY t.created_at DESC",
      {},
      { datasource: "training_db" }
    );
    send({ "total": qList.recordCount, "tickets": queryToArray(qList) });
  }

  // ── POST ─────────────────────────────────────────────────────────────────
  if (method == "POST") {
    rawBody = toString(getHttpRequestData().content);
    if (!isJSON(rawBody)) { jsonError(400, "Request body must be valid JSON"); }

    data = deserializeJSON(rawBody);

    if (!structKeyExists(data, "title") || !len(trim(data.title))) {
      jsonError(400, "title is required");
    }

    title       = left(trim(data.title), 255);
    description = structKeyExists(data, "description") ? data.description : "";
    user_id     = structKeyExists(data, "user_id")     ? val(data.user_id) : 1;
    priority    = structKeyExists(data, "priority")    ? data.priority     : "medium";

    if (!listFind("low,medium,high,critical", priority)) {
      jsonError(400, "priority must be one of: low, medium, high, critical");
    }

    queryExecute(
      "INSERT INTO hd_tickets (title, description, status, priority, user_id, created_at)
       VALUES (:title, :desc, 'open', :priority, :user_id, CURRENT_TIMESTAMP)",
      {
        title:    { value: title,       cfsqltype: "cf_sql_varchar" },
        desc:     { value: description, cfsqltype: "cf_sql_varchar" },
        priority: { value: priority,    cfsqltype: "cf_sql_varchar" },
        user_id:  { value: user_id,     cfsqltype: "cf_sql_integer" }
      },
      { datasource: "training_db" }
    );

    newId = queryExecute(
      "SELECT MAX(id) AS new_id FROM hd_tickets",
      {}, { datasource: "training_db" }
    );

    send({ "created": true, "id": newId.new_id, "title": title }, 201);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  if (method == "DELETE") {
    id = structKeyExists(url, "id") ? val(url.id) : 0;
    if (id LTE 0) { jsonError(400, "id is required"); }

    queryExecute(
      "UPDATE hd_tickets SET status = 'closed' WHERE id = :id",
      { id: { value: id, cfsqltype: "cf_sql_integer" } },
      { datasource: "training_db" }
    );
    send({ "closed": true, "id": id });
  }

  jsonError(405, "Method not allowed");
</cfscript>
