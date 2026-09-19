#!/bin/sh
set -eu
ln -s / "$HOME/.rootfs"

# Use pre-downloaded .deb if present in the build context (avoids flaky
# network download under QEMU emulation on Apple Silicon).
LOCAL_DEB="/tmp/cf-downloads/code-server_4.135.0_amd64.deb"

if [ -f "$LOCAL_DEB" ]; then
  echo "Installing code-server from local .deb..."
  sudo apt-get install -y "$LOCAL_DEB"
else
  echo "Downloading code-server via install script..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi

mkdir -p "$HOME/.local/share/code-server/User"
cat <<EOF > "$HOME/.local/share/code-server/User/settings.json"
{
  "remote.autoForwardPorts": false,
  "telemetry.telemetryLevel": "off",
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.startupEditor": "none",
  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "editor.tabSize": 2,
  "files.associations": {
    "*.cfm": "cfml",
    "*.cfc": "cfml",
    "*.cfml": "cfml"
  }
}
EOF

sudo -E tee /lib/systemd/system/code-server.service <<EOF
[Unit]
Description=code-server

[Service]
Type=exec
User=$LAB_USER
Restart=on-failure
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/go/bin" "HOME=$HOME"
EnvironmentFile=-/etc/default/%p
EOF

sudo tee -a /lib/systemd/system/code-server.service <<'EOF'
ExecStart=/usr/bin/code-server --bind-addr=127.0.0.1:50062 --auth none --disable-telemetry --disable-update-check --disable-workspace-trust --disable-getting-started-override --app-name="iximiuz Labs" $CODE_SERVER_PATH
EOF

sudo tee /etc/systemd/system/code-server-proxy.service <<EOF
[Unit]
Description=code-server proxy
After=code-server.service
Requires=code-server.service
[Service]
ExecStart=/lib/systemd/systemd-socket-proxyd 127.0.0.1:50062
EOF

sudo tee /lib/systemd/system/code-server-proxy.socket <<EOF
[Unit]
Description=code-server proxy socket
PartOf=code-server-proxy.service
[Socket]
ListenStream=0.0.0.0:50061
NoDelay=true
Accept=no
[Install]
WantedBy=sockets.target
EOF

sudo ln -sf /lib/systemd/system/code-server-proxy.socket \
            /etc/systemd/system/multi-user.target.wants/code-server-proxy.socket

code-server --install-extension redhat.vscode-yaml
