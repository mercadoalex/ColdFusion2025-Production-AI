#!/bin/sh
set -eu
BTOP_VERSION="${BTOP_VERSION:-1.4.4}"
curl -fsSL "https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-x86_64-linux-musl.tbz" \
  | tar -xjC /usr/local --strip-components=1
