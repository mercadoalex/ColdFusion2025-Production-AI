n<cfscript>
    wsPublish("chat", serializeJSON({
        type: "message",
        user: "server",
        text: "Hello from wsPublish — " & dateTimeFormat(now(), "HH:nn:ss")
    }));
    writeOutput("Published");
</cfscript>
