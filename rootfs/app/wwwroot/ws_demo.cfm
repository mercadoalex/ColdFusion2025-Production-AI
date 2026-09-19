<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CF WebSocket Demo</title>
    <style>
        body { font-family: sans-serif; max-width: 600px; margin: 2rem auto; }
        #chat-log { border: 1px solid #ccc; height: 200px; overflow-y: auto; padding: 0.5rem; margin-bottom: 0.5rem; }
        #msg-input { width: 75%; padding: 0.4rem; }
        button { padding: 0.4rem 1rem; }
    </style>
</head>
<body>
    <h2>WebSocket Chat Demo</h2>
    <div id="chat-log"></div>
    <input id="msg-input" type="text" placeholder="Type a message…">
    <button onclick="sendMsg()">Send</button>
    <p id="status">Connecting…</p>

    <cfwebsocket
        name        = "chatWS"
        onMessage   = "handleMessage"
        onOpen      = "handleOpen"
        onClose     = "handleClose"
        subscribeTo = "chat"
    >

    <script>
        const log    = document.getElementById("chat-log");
        const status = document.getElementById("status");

        function handleOpen() {
            status.textContent = "Connected";
        }

        function handleMessage(msg) {
            if (msg.type === "data") {
                log.insertAdjacentHTML("beforeend",
                    `<p><strong>user</strong>: ${msg.data}</p>`);
                log.scrollTop = log.scrollHeight;
            }
        }

        function handleClose() {
            status.textContent = "Disconnected";
        }

        function sendMsg() {
            const input = document.getElementById("msg-input");
            if (!input.value.trim()) return;
            chatWS.publish("chat", input.value);
            input.value = "";
        }
    </script>
</body>
</html>
