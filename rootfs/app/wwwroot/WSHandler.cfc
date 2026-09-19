component extends="CFIDE.websocket.ChannelListener" {

    public void function onWSMessage(
        required string channel,
        required any    data,
        required struct client
    ) {
        wsPublish(channel, data);
    }

    public void function onWSOpen(required struct client) {
        writeLog(file="websocket", text="WS opened: #client.clientid#");
    }

    public void function onWSClose(required struct client) {
        writeLog(file="websocket", text="WS closed: #client.clientid#");
    }

}
