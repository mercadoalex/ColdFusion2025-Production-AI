#!/bin/sh
set -eu
WEBSOCAT_VERSION="${WEBSOCAT_VERSION:-1.14.0}"
curl -fsSL "https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.x86_64-unknown-linux-musl" \
  -o /usr/local/bin/websocat && chmod +x /usr/local/bin/websocat
