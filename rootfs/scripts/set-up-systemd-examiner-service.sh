#!/bin/sh
# Mirrors iximiuz labs-playgrounds/scripts/set-up-systemd-examiner-service.sh
set -eu

# If the examiner binary wasn't injected (local dev build without iximiuz
# build pipeline), create a stub so the image still builds.
if [ ! -f /usr/local/bin/examiner ]; then
  cat > /usr/local/bin/examiner <<'STUB'
#!/bin/sh
# examiner stub — real binary injected by iximiuz build pipeline
echo "[examiner-stub] No task engine binary present. Playground tasks will not work."
exec sleep infinity
STUB
  chmod +x /usr/local/bin/examiner
fi

cat <<EOF > /etc/systemd/system/examiner.service
[Unit]
Description=Examiner
After=network.target

[Service]
Type=simple
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin" "HOME=/root" "LAB_USER=${LAB_USER:-laborant}"
ExecStart=/usr/local/bin/examiner
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/examiner.service \
       /etc/systemd/system/multi-user.target.wants/examiner.service
