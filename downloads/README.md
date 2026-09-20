# downloads/

Place binary build assets here before running `make build-with-cf`.
All `.zip`, `.bin`, `.deb` files are gitignored — download them manually.

## Required files

| File | Source | Notes |
|---|---|---|
| `ColdFusion_2025_WWEJ_linux64.zip` | [Adobe ColdFusion Trial](https://helpx.adobe.com/coldfusion/using/download-coldfusion.html) → Linux 64-bit ZIP | Required for CF layer |
| `lucee-engine-7.0.4.34.zip` | [Lucee Downloads](https://download.lucee.org/) | Pre-bakes Lucee engine cache — avoids ~60s download on first VM boot |
| `coldbox-7.3.0.zip` | `curl -L -o downloads/coldbox-7.3.0.zip https://downloads.ortussolutions.com/ortussolutions/coldbox/7.3.0/coldbox-7.3.0.zip` | Pre-bakes ColdBox package cache — avoids ForgeBox download in Module 5 |

## Optional files

| File | Source | Notes |
|---|---|---|
| `code-server_4.135.0_amd64.deb` | [code-server releases](https://github.com/coder/code-server/releases) | Pre-bakes VS Code IDE — avoids download at build time |

## Quick download commands

```bash
# ColdFusion 2025 (download manually from Adobe — requires accepting licence)
# https://helpx.adobe.com/coldfusion/using/download-coldfusion.html

# Lucee engine
curl -L -o downloads/lucee-engine-7.0.4.34.zip \
  "https://cdn.lucee.org/lucee-light-7.0.4.34.zip"

# ColdBox
curl -L -o downloads/coldbox-7.3.0.zip \
  "https://downloads.ortussolutions.com/ortussolutions/coldbox/7.3.0/coldbox-7.3.0.zip"
```
