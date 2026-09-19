#!/bin/sh
set -eu

USER_ID=1001
USERNAME="${LAB_USER:-laborant}"
PASSWORD="${LAB_USER:-laborant}"

# Rocky Linux / RHEL / Fedora
if [ -f /etc/rocky-release ] || [ -f /etc/almalinux-release ] || [ -f /etc/fedora-release ]; then
  adduser --comment "" --uid "$USER_ID" "$USERNAME"
  SUDO_GROUP="wheel"
else
  adduser --disabled-password --gecos "" --uid "$USER_ID" "$USERNAME"
  SUDO_GROUP="sudo"
fi

echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG "$SUDO_GROUP" "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/"$USERNAME"
chmod 0440 /etc/sudoers.d/"$USERNAME"
