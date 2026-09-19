# syntax=docker/dockerfile:1
# =============================================================================
# ColdFusion Training Rootfs Image
# Base: Ubuntu 24.04 LTS  (matches iximiuz most-used microVM base)
#
# Layers:
#   1. Ubuntu 24.04 base  — systemd, networking, SSH, sysadmin tools
#   2. ColdFusion 2025    — pre-installed via ZIP, port 8500
#   3. CommandBox + Lucee — box CLI, lucee dev server port 8888
#   4. iximiuz examiner   — task engine daemon
#   5. lab user (laborant) + code-server IDE
# =============================================================================

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG LAB_USER=laborant
ARG ARKADE_BIN_DIR=/usr/local/bin
ARG BTOP_VERSION=1.4.4
ARG CFSSL_VERSION=1.6.5
ARG WEBSOCAT_VERSION=1.14.0
ARG COMMANDBOX_VERSION=6.3.4
ARG LUCEE_VERSION=7.0.4.34

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ColdFusion install dir — JRE 21 is bundled inside the ZIP at /opt/coldfusion2025/jre
ENV CF_HOME=/opt/coldfusion2025
ENV JAVA_HOME=/opt/coldfusion2025/jre
ENV PATH=/opt/coldfusion2025/jre/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# CommandBox
ENV COMMANDBOX_HOME=/opt/commandbox
ENV BOX_HOME=/opt/commandbox

# =============================================================================
# LAYER 1 — Base OS  (mirrors iximiuz 100.rootfs-ubuntu-24-04 pattern)
# =============================================================================
RUN <<EOF
set -eu

# Pin apt to only use main/restricted/universe/security — skip backports.
# noble-backports has a GPG key issue under QEMU (amd64 build on Apple Silicon).
cat > /etc/apt/preferences.d/no-backports <<'APT'
Package: *
Pin: release a=noble-backports
Pin-Priority: -1
APT

apt-get update
apt-get upgrade -y

apt-get install -y \
  bash-completion \
  bzip2 \
  ca-certificates \
  curl \
  dbus \
  dnsutils \
  dos2unix \
  file \
  gettext-base \
  git \
  gnupg \
  htop \
  iproute2 \
  iptables \
  iputils-ping \
  kmod \
  locales \
  lsb-release \
  lsof \
  make \
  man \
  mtr \
  netcat-openbsd \
  net-tools \
  nftables \
  psmisc \
  procps \
  ripgrep \
  socat \
  sudo \
  systemd \
  traceroute \
  tree \
  udev \
  unzip \
  vim \
  wget \
  xmlstarlet \
  zip

apt-get clean
rm -rf /var/lib/apt/lists/*

# microVM boot requirements
rm -f /.dockerenv
mkdir -p /boot

# Reset machine-id — platform generates a real one at VM boot
echo "" > /etc/machine-id
mkdir -p /var/lib/dbus/
echo "" > /var/lib/dbus/machine-id

# Serial console (ttyS0) — required for iximiuz playground terminal access
mkdir -p /etc/systemd/system/getty.target.wants
ln -sf /usr/lib/systemd/system/getty@.service \
       /etc/systemd/system/getty.target.wants/getty@ttyS0.service

# Suppress noisy systemd units that don't apply inside a microVM image build
systemctl mask systemd-machine-id-commit.service 2>/dev/null || true

# root password
echo "root:root" | chpasswd
EOF

# =============================================================================
# LAYER 2 — SSH server  (required for iximiuz platform SSH/terminal access)
# =============================================================================
RUN <<EOF
set -eu

apt-get update -o APT::Get::List-Cleanup=0
apt-get install -y openssh-server
apt-get clean
rm -rf /var/lib/apt/lists/*

cat >> /etc/ssh/sshd_config <<EOT
HostKey /etc/ssh/ssh_host_ed25519_key
AuthenticationMethods publickey
PrintLastLog no
AddressFamily inet
UseDNS no
MaxAuthTries 50
EOT

systemctl disable ssh.socket   2>/dev/null || true
systemctl enable  ssh.service  2>/dev/null || true

# Keys are generated at VM first boot, not baked into the image
rm -f /etc/ssh/ssh_host_*
EOF

# =============================================================================
# LAYER 3 — ColdFusion 2025 (pre-installed from ZIP, NOT downloaded at runtime)
# =============================================================================
# The ZIP (downloads/ColdFusion_2025_WWEJ_linux64.zip) is copied into the build,
# extracted to /opt/coldfusion2025/, then the ZIP is deleted from this layer.
# CF's bundled JRE 21 lives at /opt/coldfusion2025/jre — no system Java needed.
# --------------------------------------------------------------------------
COPY rootfs/scripts/install-coldfusion.sh /tmp/install-coldfusion.sh
COPY rootfs/cf-config/neo-datasource.xml  /tmp/neo-datasource.xml
COPY downloads/ /tmp/cf-downloads/
RUN bash /tmp/install-coldfusion.sh && \
    rm -rf /tmp/cf-downloads

# =============================================================================
# LAYER 4 — CommandBox CLI + Lucee 5
# =============================================================================
COPY rootfs/scripts/install-commandbox.sh /tmp/install-commandbox.sh
RUN bash /tmp/install-commandbox.sh

# =============================================================================
# LAYER 5 — Seed app and wwwroot
# =============================================================================
COPY rootfs/app/         /home/${LAB_USER}/app/
COPY rootfs/app/wwwroot/ /tmp/cf-wwwroot/

# =============================================================================
# LAYER 6 — Systemd services
# =============================================================================
COPY rootfs/scripts/cf-server.service          /etc/systemd/system/cf-server.service
COPY rootfs/scripts/lucee-server.service       /etc/systemd/system/lucee-server.service
COPY rootfs/scripts/cf-readiness-probe.service /etc/systemd/system/cf-readiness-probe.service
COPY rootfs/scripts/cf-readiness-probe.sh      /usr/local/bin/cf-readiness-probe
COPY rootfs/scripts/lucee-inject-h2.sh         /usr/local/bin/lucee-inject-h2
RUN chmod +x /usr/local/bin/cf-readiness-probe \
             /usr/local/bin/lucee-inject-h2 && \
    systemctl enable cf-server.service && \
    systemctl enable lucee-server.service && \
    systemctl enable cf-readiness-probe.service

# =============================================================================
# LAYER 7 — iximiuz examiner daemon
# Place rootfs/examiner + rootfs/examinerctl for production builds.
# The setup script creates a stub automatically if they are absent.
# =============================================================================
COPY rootfs/scripts/set-up-systemd-examiner-service.sh /tmp/
RUN --mount=type=bind,source=rootfs,target=/build-ctx \
    cp /build-ctx/examiner    /usr/local/bin/examiner    2>/dev/null || true && \
    cp /build-ctx/examinerctl /usr/local/bin/examinerctl 2>/dev/null || true && \
    chmod +x /usr/local/bin/examiner /usr/local/bin/examinerctl 2>/dev/null || true
RUN bash /tmp/set-up-systemd-examiner-service.sh

# =============================================================================
# LAYER 8 — System-wide tools  (mirrors iximiuz base pattern)
# =============================================================================
COPY rootfs/scripts/get-arkade.sh     /tmp/
COPY rootfs/scripts/get-common-tools.sh /tmp/
COPY rootfs/scripts/get-btop.sh       /tmp/
COPY rootfs/scripts/get-cfssl.sh      /tmp/
COPY rootfs/scripts/get-websocat.sh   /tmp/

RUN bash /tmp/get-arkade.sh
RUN bash /tmp/get-common-tools.sh
RUN bash /tmp/get-btop.sh
RUN bash /tmp/get-cfssl.sh
RUN bash /tmp/get-websocat.sh
RUN curl -fsSL https://fx.wtf/install.sh | sh

# root user dotfiles
COPY rootfs/scripts/get-fzf.sh           /tmp/
COPY rootfs/scripts/customize-bashrc.sh  /tmp/
COPY rootfs/scripts/customize-git.sh     /tmp/
COPY rootfs/scripts/customize-vimrc.sh   /tmp/
RUN bash /tmp/get-fzf.sh && \
    bash /tmp/customize-bashrc.sh && \
    bash /tmp/customize-git.sh && \
    bash /tmp/customize-vimrc.sh

# =============================================================================
# LAYER 9 — Lab user  (uid 1001, username = laborant)
# =============================================================================
COPY rootfs/scripts/add-lab-user.sh /tmp/
RUN bash /tmp/add-lab-user.sh

# Do all root-owned file operations before switching user
COPY rootfs/rootfs/welcome /home/${LAB_USER}/.welcome
RUN chown ${LAB_USER}:${LAB_USER} /home/${LAB_USER}/.welcome && \
    chown -R ${LAB_USER}:${LAB_USER} /home/${LAB_USER} && \
    chown -R ${LAB_USER}:${LAB_USER} ${COMMANDBOX_HOME} && \
    mv /tmp/cf-wwwroot/* ${CF_HOME}/cfusion/wwwroot/ 2>/dev/null || true && \
    chown -R ${LAB_USER}:${LAB_USER} ${CF_HOME}/cfusion/wwwroot/

USER ${LAB_USER}
ENV HOME=/home/${LAB_USER}

# Per-user tools
COPY rootfs/scripts/get-code-server.sh /tmp/
COPY rootfs/scripts/get-fzf.sh         /tmp/
RUN bash /tmp/get-code-server.sh
RUN bash /tmp/get-fzf.sh
RUN bash /tmp/customize-bashrc.sh && \
    bash /tmp/customize-git.sh && \
    bash /tmp/customize-vimrc.sh

# CFML syntax highlighting in the IDE
RUN code-server --install-extension KamasamaK.vscode-cfml 2>/dev/null || true

# =============================================================================
# Metadata
# =============================================================================
USER root
LABEL org.opencontainers.image.title="cf-training" \
      org.opencontainers.image.description="ColdFusion 2025 + Lucee training rootfs for iximiuz Labs" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.base.name="ubuntu:24.04"
