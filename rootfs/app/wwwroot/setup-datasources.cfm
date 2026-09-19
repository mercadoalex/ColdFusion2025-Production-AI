<!---
  setup-datasources.cfm
  Registers the training_db H2 datasource via the CF Admin API.
  Called once at first boot by cf-readiness-probe.sh after CF is fully up.
  Safe to call repeatedly — skips registration if datasource already exists.
--->
<cfsilent>
<cftry>
  <!--- Load the CF Admin API --->
  <cfobject type="component" name="adminAPI"
    component="CFIDE.adminapi.administrator">
  <cfset adminAPI.login("training")>

  <cfobject type="component" name="datasourceAPI"
    component="CFIDE.adminapi.datasource">

  <!--- Only register if not already present --->
  <cfset dsns = datasourceAPI.getDatasources()>
  <cfif NOT structKeyExists(dsns, "training_db")>
    <cfset stDSN = structNew()>
    <cfset stDSN.name          = "training_db">
    <cfset stDSN.driver        = "other">
    <cfset stDSN.url           = "jdbc:h2:/opt/coldfusion2025/cfusion/db/training;AUTO_SERVER=FALSE;DB_CLOSE_ON_EXIT=FALSE">
    <cfset stDSN.class         = "org.h2.Driver">
    <cfset stDSN.driverClassPath = "/opt/coldfusion2025/cfusion/lib/h2-2.2.224.jar">
    <cfset stDSN.username      = "sa">
    <cfset stDSN.password      = "">
    <cfset stDSN.description   = "H2 embedded DB for training exercises">
    <cfset stDSN.maxConnections = 10>
    <cfset stDSN.timeout       = 20>
    <cfset stDSN.loginTimeout  = 30>
    <cfset datasourceAPI.setDatasource(argumentCollection=stDSN)>
    <cfset result = "created">
  <cfelse>
    <cfset result = "exists">
  </cfif>

  <cfcatch type="any">
    <cfset result = "error: " & cfcatch.message>
  </cfcatch>
</cftry>
</cfsilent>
<cfoutput>#result#</cfoutput>
