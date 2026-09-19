<!---
  TicketService.cfc
  ColdFusion Component wrapping the Help Desk ticket data layer.
  Demonstrates: cffunction, cfargument, cfquery, queryToArray, and
  CFC-based service pattern.

  Usage:
    svc = createObject("component", "TicketService");
    tickets = svc.getAll();
    ticket  = svc.getById(3);
    id      = svc.create("Login broken", "Cannot log in", 2, "high");
    svc.close(3);
--->
<cfcomponent displayname="TicketService" hint="Service layer for hd_tickets">

  <!--- ── getAll ──────────────────────────────────────────────────────── --->
  <cffunction name="getAll" access="public" returntype="array"
    hint="Returns all tickets as an array of structs, newest first.">

    <cfset var q = "" />
    <cfquery name="q" datasource="training_db">
      SELECT t.id, t.title, t.status, t.priority, t.created_at,
             u.name AS submitter
      FROM   hd_tickets t
      JOIN   hd_users   u ON u.id = t.user_id
      ORDER  BY t.created_at DESC
    </cfquery>
    <cfreturn queryToArray(q) />
  </cffunction>

  <!--- ── getById ─────────────────────────────────────────────────────── --->
  <cffunction name="getById" access="public" returntype="struct"
    hint="Returns one ticket plus its comments. Throws if not found.">

    <cfargument name="id" type="numeric" required="true" />

    <cfset var qTicket   = "" />
    <cfset var qComments = "" />
    <cfset var result    = {} />

    <cfquery name="qTicket" datasource="training_db">
      SELECT t.id, t.title, t.description, t.status, t.priority,
             t.created_at, u.name AS submitter
      FROM   hd_tickets t
      JOIN   hd_users   u ON u.id = t.user_id
      WHERE  t.id = <cfqueryparam value="#arguments.id#" cfsqltype="cf_sql_integer">
    </cfquery>

    <cfif qTicket.recordCount EQ 0>
      <cfthrow type="TicketService.NotFound"
               message="Ticket ##arguments.id## not found" />
    </cfif>

    <cfquery name="qComments" datasource="training_db">
      SELECT c.id, c.comment_text, c.created_at, u.name AS author
      FROM   hd_comments c
      JOIN   hd_users    u ON u.id = c.user_id
      WHERE  c.ticket_id = <cfqueryparam value="#arguments.id#" cfsqltype="cf_sql_integer">
      ORDER  BY c.created_at
    </cfquery>

    <cfset result = {
      "id":          qTicket.id,
      "title":       qTicket.title,
      "description": qTicket.description,
      "status":      qTicket.status,
      "priority":    qTicket.priority,
      "created_at":  qTicket.created_at,
      "submitter":   qTicket.submitter,
      "comments":    queryToArray(qComments)
    } />

    <cfreturn result />
  </cffunction>

  <!--- ── create ──────────────────────────────────────────────────────── --->
  <cffunction name="create" access="public" returntype="numeric"
    hint="Inserts a new ticket and returns the new row id.">

    <cfargument name="title"       type="string"  required="true"  />
    <cfargument name="description" type="string"  required="false" default="" />
    <cfargument name="user_id"     type="numeric" required="false" default="1" />
    <cfargument name="priority"    type="string"  required="false" default="medium" />

    <cfset var qNew = "" />

    <cfquery datasource="training_db">
      INSERT INTO hd_tickets (title, description, status, priority, user_id, created_at)
      VALUES (
        <cfqueryparam value="#left(trim(arguments.title),255)#" cfsqltype="cf_sql_varchar">,
        <cfqueryparam value="#arguments.description#"           cfsqltype="cf_sql_varchar">,
        'open',
        <cfqueryparam value="#arguments.priority#"              cfsqltype="cf_sql_varchar">,
        <cfqueryparam value="#arguments.user_id#"               cfsqltype="cf_sql_integer">,
        CURRENT_TIMESTAMP
      )
    </cfquery>

    <cfquery name="qNew" datasource="training_db">
      SELECT MAX(id) AS new_id FROM hd_tickets
    </cfquery>

    <cfreturn qNew.new_id />
  </cffunction>

  <!--- ── close ───────────────────────────────────────────────────────── --->
  <cffunction name="close" access="public" returntype="void"
    hint="Marks a ticket as closed.">

    <cfargument name="id" type="numeric" required="true" />

    <cfquery datasource="training_db">
      UPDATE hd_tickets SET status = 'closed'
      WHERE  id = <cfqueryparam value="#arguments.id#" cfsqltype="cf_sql_integer">
    </cfquery>
  </cffunction>

  <!--- ── getByStatus ─────────────────────────────────────────────────── --->
  <cffunction name="getByStatus" access="public" returntype="array"
    hint="Returns tickets filtered by status.">

    <cfargument name="status" type="string" required="true" />

    <cfset var q = "" />
    <cfquery name="q" datasource="training_db">
      SELECT t.id, t.title, t.status, t.priority, t.created_at,
             u.name AS submitter
      FROM   hd_tickets t
      JOIN   hd_users   u ON u.id = t.user_id
      WHERE  t.status = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">
      ORDER  BY t.created_at DESC
    </cfquery>
    <cfreturn queryToArray(q) />
  </cffunction>

</cfcomponent>
