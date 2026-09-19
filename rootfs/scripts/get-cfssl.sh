#!/bin/sh
set -eu
CFSSL_VERSION="${CFSSL_VERSION:-1.6.5}"
curl -fsSL "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64" \
  -o /usr/local/bin/cfssl && chmod +x /usr/local/bin/cfssl
curl -fsSL "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64" \
  -o /usr/local/bin/cfssljson && chmod +x /usr/local/bin/cfssljson
