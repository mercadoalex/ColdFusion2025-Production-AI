# ColdFusion Training Rootfs — Build & Publish Journal

## Project Goal

Build a custom OCI rootfs image for an interactive ColdFusion training course
hosted on [iximiuz Labs](https://labs.iximiuz.com). The image boots as a
Firecracker microVM (not a container), with Adobe ColdFusion 2025 and
CommandBox/Lucee 7 pre-installed and ready on first boot.

Hungry Minds — ColdFusion 2025 Training Playground v.beta
https://labs.iximiuz.com/playgrounds/cf-alex-edcdf975

---

## Platform Understanding

### What iximiuz Labs Is

iximiuz Labs is an interactive learning platform that runs real Linux microVMs
(using [Firecracker](https://firecracker-microvm.github.io/)) in the browser.
Students get full SSH terminal access, a web IDE (code-server), and live HTTP
tabs that expose running web servers directly in the UI.

### Why Docker Is Used (But Is NOT the Runtime)

**Docker is only the build tool.** It assembles the filesystem layer by layer
and produces a standard OCI image. That image is pushed to a registry.

At runtime, iximiuz Labs pulls the OCI image, flattens its layers into an ext4
disk image, and hands that disk to Firecracker as the root drive. The VM boots
with its own Linux kernel, systemd as PID 1, and full hardware virtualization.

```
Build time (your Mac):
  docker build → OCI image → pushed to ghcr.io

Runtime (iximiuz Firecracker):
  OCI layers → ext4 disk → Firecracker VM → systemd → CF starts
```

This is why the Dockerfile installs `systemd`, `udev`, `kmod`, configures
`getty@ttyS0` for serial console access, and resets `machine-id` — these are
VM boot requirements, not container requirements.

---

## OS Choice: Why Ubuntu 24.04 (Not Rocky Linux)

### Initial Choice: Rocky Linux 9

The project started with Rocky Linux 9 because ColdFusion is traditionally
deployed on RHEL-family servers in enterprise environments. It seemed like the
"authentic" production match.

### Problems Encountered with Rocky Linux

- `dnf` is slower and more complex than `apt`
- SELinux had to be explicitly disabled (`SELINUX=disabled`)
- Package names differ from Ubuntu (`nc`, `bind-utils`, `gnupg2`, `procps-ng`)
- The first build error was a `dnf` failure due to package name mismatches
- Fewer iximiuz tutorial examples use Rocky Linux — less battle-tested

### Switch to Ubuntu 24.04

Ubuntu 24.04 LTS is the most-used base in the iximiuz platform catalog. It is:

- **Faster to build** — `apt-get` is faster and better cached
- **Smaller** — no SELinux overhead, no epel-release
- **Better tested** — majority of iximiuz official playgrounds use it
- **More familiar** to students
- **`dos2unix` included** — needed for fixing Windows CRLF line endings in the
  CF ZIP installer

The switch was a one-line change (`FROM ubuntu:24.04`) plus swapping `dnf` for
`apt-get` in the two base OS layers.

---

## ColdFusion Installer: ZIP vs GUI vs Silent

### What Adobe Provides

The Adobe ColdFusion download page offers:

| Installer | Description |
|---|---|
| `ColdFusion_2025_GUI_WWEJ_linux64.bin` | GUI wizard installer (~1.9 GB) |
| `ColdFusion_2025_WWEJ_linux64.zip` | ZIP installer (~280 MB) |

### Why the ZIP Installer Was Chosen

The GUI installer launches a wizard that requires `$DISPLAY` (a graphical
environment) — incompatible with `docker build`. The silent mode (`.bin -i
silent`) is fragile and installer-version-dependent.

The ZIP installer is a **pre-extracted installation tree** — 2,269 files
including:
- Bundled JRE 21 at `ColdFusion/jre/`
- The `cfusion/` instance with all binaries and config files
- The `coldfusion` control script (`cfusion/bin/coldfusion start|stop`)

Installation is pure file extraction — no wizard, no silent properties file.

### ZIP Structure

```
ColdFusion_2025_WWEJ_linux64.zip          ← outer signed wrapper
  └── ColdFusion_WWEJ_linux64.zip         ← actual payload (2,269 files)
        └── ColdFusion/                   ← extracted to /opt/coldfusion2025/
              ├── jre/                    ← bundled JRE 21 (no system Java needed)
              └── cfusion/
                    ├── bin/coldfusion    ← main control script
                    ├── bin/jvm.config    ← JVM heap settings
                    └── lib/             ← XML config files
```

### Post-Extraction Configuration

After extraction, four files are overwritten to pre-configure the training environment:

| File | Change |
|---|---|
| `password.properties` | Pre-set admin password hash (avoids first-boot wizard) |
| `adminconfig.xml` | `runsetupwizard=false` (skip the setup wizard entirely) |
| `neo-datasource.xml` | Pre-configured H2 embedded datasource (`training_db`) |
| `jvm.config` | Reduced heap from `-Xmx1024m` to `-Xmx512m` for microVM |

### Key Discovery: JDK Version

ColdFusion 2025 requires **JDK 21** (not 17, not 11). The ZIP bundles JRE 21
inside at `/opt/coldfusion2025/jre/`. No system Java installation is needed —
this saves ~180 MB from the image.

The `JAVA_HOME` and `PATH` environment variables are set in the Dockerfile to
point at the bundled JRE so CommandBox can also use it.

---

## Apple Silicon Build Issue: `--platform linux/amd64`

### Problem

The iximiuz Firecracker VMs run on `amd64` (x86_64) servers. Building on an
Apple Silicon Mac (ARM64) without specifying a platform produces an `arm64`
image that won't run on the platform.

The symptom was:
```
rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2
Trace/breakpoint trap
```

CommandBox installed fine but its binary was `x86_64` — Rosetta couldn't
translate it inside the QEMU build environment.

### Fix

Add `--platform linux/amd64` to the `docker build` command in the Makefile:

```makefile
docker build \
    --platform linux/amd64 \
    ...
```

Docker Desktop on Apple Silicon uses QEMU to emulate `amd64`. It's ~2x slower
than a native build but produces a correct image that boots on iximiuz VMs.

---

## Ubuntu noble-backports GPG Error

### Problem

When building `amd64` under QEMU on Apple Silicon, the second `apt-get update`
(for the SSH layer) failed with:

```
E: The repository 'http://archive.ubuntu.com/ubuntu noble-backports InRelease'
   is not signed.
```

This is a known bug with QEMU emulation + Ubuntu 24.04's GPG key handling.

### Fix

Pin apt to skip the `noble-backports` repository entirely by creating
`/etc/apt/preferences.d/no-backports` in the first layer:

```
Package: *
Pin: release a=noble-backports
Pin-Priority: -1
```

---

## CommandBox Installation

### Problem 1: Wrong Download URL

The initial script tried to download a tarball:
```
https://downloads.ortussolutions.com/ortussolutions/commandbox/6.1.0/commandbox-bin-6.1.0.tar.gz
```
This returned HTTP 404.

### Solution: Official APT Repository

CommandBox has an official Debian/Ubuntu APT repository:

```bash
curl -fsSL https://downloads.ortussolutions.com/debs/gpg \
  | gpg --dearmor -o /usr/share/keyrings/ortus-commandbox.gpg

echo "deb [signed-by=/usr/share/keyrings/ortus-commandbox.gpg] \
https://downloads.ortussolutions.com/debs/noarch /" \
  > /etc/apt/sources.list.d/commandbox.list

apt-get update && apt-get install -y commandbox
```

### Problem 2: Lucee 5 No Longer Free on Maven

The initial Lucee version was `5.4.6.9`. During build, CommandBox tried to
download it from Sonatype Maven and got HTTP 402 (payment required):

```
java.io.IOException: Server returned HTTP response code: 402 for URL:
https://oss.sonatype.org/.../lucee-5.4.6.9.jar
```

Lucee 5.x moved behind a paywall on the Maven repository.

### Solution: Upgrade to Lucee 7

**Lucee 7.0.4.34** is the current stable release, available free from
`downloads.ortussolutions.com`. Updated in `Dockerfile`, `Makefile`, and
`server.json`.

### Problem 3: Lucee Pre-warm Hangs Under QEMU

The script originally tried to pre-bake the Lucee engine at build time:
```bash
HOME=/root box install "lucee@7.0.4.34" --verbose
```

Under QEMU emulation on Apple Silicon, this network download would start but
never complete — the build hung indefinitely.

### Solution: Local File Cache

Download the Lucee engine ZIP manually on the Mac and place it in `downloads/`:
```bash
curl -L -o downloads/lucee-engine-7.0.4.34.zip \
  https://downloads.ortussolutions.com/lucee/lucee/7.0.4.34/cf-engine-7.0.4.34.zip
```

The install script detects the file and copies it into the CommandBox engine
cache at `/root/.CommandBox/engine/cfml/server/lucee_7.0.4.34/`. No download
occurs at build time or on first student use.

---

## code-server (VS Code in Browser)

### Problem: Partial Download Under QEMU

The code-server install script downloads a 228 MB `.deb` from GitHub. Under
QEMU, the download cut off at 78% with:
```
curl: (18) Transferred a partial file
```

### Solution: Pre-download Locally

Download the `.deb` on the Mac and place it in `downloads/`:
```bash
curl -L -o downloads/code-server_4.135.0_amd64.deb \
  https://github.com/coder/code-server/releases/download/v4.135.0/code-server_4.135.0_amd64.deb
```

The install script checks for the local file first:
```sh
LOCAL_DEB="/tmp/cf-downloads/code-server_4.135.0_amd64.deb"
if [ -f "$LOCAL_DEB" ]; then
  sudo apt-get install -y "$LOCAL_DEB"
else
  curl -fsSL https://code-server.dev/install.sh | sh
fi
```

**Pattern established:** For any large download that might fail under QEMU,
pre-download it on the Mac and place it in `downloads/`. The Dockerfile
`COPY downloads/ /tmp/cf-downloads/` makes all files available during build.

---

## Permission Error: Welcome File

### Problem

After creating the `laborant` user, the Dockerfile switched to `USER laborant`
and tried to `cp` a file into `/home/laborant/` — but the directory was owned
by root from an earlier `COPY` instruction:

```
cp: cannot create regular file '/home/laborant/.welcome': Permission denied
```

### Fix

Do all root-owned file operations **before** the `USER laborant` switch:

```dockerfile
# As root — chown the whole home directory
COPY rootfs/rootfs/welcome /home/${LAB_USER}/.welcome
RUN chown ${LAB_USER}:${LAB_USER} /home/${LAB_USER}/.welcome && \
    chown -R ${LAB_USER}:${LAB_USER} /home/${LAB_USER}

USER ${LAB_USER}
# Now all operations run as laborant in a directory they own
```

---

## Build Context: Project Root vs rootfs/

### Problem

The Makefile originally set the Docker build context to `rootfs/`:
```makefile
docker build -f rootfs/Dockerfile rootfs/
```

This meant `downloads/` (at the project root) was outside the build context
and `COPY downloads/ /tmp/cf-downloads/` failed:
```
"/downloads": not found
```

### Fix

Set the build context to the **project root** and prefix all `COPY` paths with
`rootfs/`:

```makefile
docker build -f /path/to/rootfs/Dockerfile /path/to/project/root
```

```dockerfile
# All COPY paths now relative to project root
COPY rootfs/scripts/install-coldfusion.sh /tmp/
COPY rootfs/cf-config/neo-datasource.xml  /tmp/
COPY downloads/ /tmp/cf-downloads/
```

---

## Publishing to iximiuz Labs

### 1. Push Image to GitHub Container Registry

```bash
# Create GitHub Personal Access Token with write:packages scope
echo "ghp_..." | docker login ghcr.io -u mercadoalex --password-stdin

make push REGISTRY=ghcr.io/mercadoalex
```

### 2. Make the Package Public

GitHub packages are private by default. iximiuz needs to pull it:

- github.com → Packages → cf-training → Package settings
- Change visibility → Public

### 3. Playground Manifest: Lessons Learned

Several iterations were needed to get the manifest right.

**Wrong: `accessControl` at top level**
```yaml
# WRONG — causes "must contain at least one role" error
accessControl:
  canList:
    - owner
```

**Wrong: invalid principal names**
```yaml
canList:
  - role:registered  # invalid
  - role:author      # invalid
```

**Wrong: `network` as a string**
```yaml
network: default  # invalid — causes YAML unmarshal error
```

**Correct: everything inside `playground:`, correct principal names, network as object**
```yaml
playground:
  accessControl:
    canList:
      - owner
    canRead:
      - owner
    canStart:
      - owner

  machines:
    - name: cf-server
      drives:
        - name: rootfs
          image: ghcr.io/mercadoalex/cf-training:dev
      users:
        - name: laborant
          default: true
      network:
        interfaces:
          - network: local
```

Valid principals: `owner`, `anyone`, `authenticated`, `user:<id>`,
`student:<training-name>`

### 4. Create the Playground

```bash
labctl playground create \
  -f playground/playground.yaml \
  -b flexbox \
  cf-alex
```

Result:
```
Playground URL: https://labs.iximiuz.com/playgrounds/cf-alex-bf83b2b8
```

---

## Final Image Contents

| Component | Details |
|---|---|
| Base OS | Ubuntu 24.04 LTS (`linux/amd64`) |
| ColdFusion 2025 | Extracted from ZIP to `/opt/coldfusion2025/`, port 8500 |
| Bundled JRE | JRE 21 at `/opt/coldfusion2025/jre/` (no system Java) |
| CommandBox | 6.3.4 via Ortus APT repo, `box` CLI on PATH |
| Lucee engine | 7.0.4.34 pre-baked in CommandBox cache, port 8888 |
| code-server | 4.135.0 with CFML extension, port 50061 |
| Init system | systemd (PID 1), serial console on `ttyS0` |
| SSH | openssh-server, keys generated at first VM boot |
| iximiuz examiner | Task engine daemon (stub if binary not injected) |
| Lab user | `laborant` (uid 1001), passwordless sudo |
| Tools | arkade, jq, yq, task, just, btop, fzf, ripgrep, vim |

**Compressed image size:** ~650 MB  
**RAM at runtime:** ~1 GB peak (CF JVM 512 MB + Lucee 256 MB + OS)  
**Recommended playground resources:** 2 vCPU, 2 GiB RAM

---

## Downloads Required (Not in Git)

These files must be in `downloads/` before running `make build-with-cf`:

| File | Source | Size |
|---|---|---|
| `ColdFusion_2025_WWEJ_linux64.zip` | Adobe download page (Trial Edition → Linux ZIP) | ~280 MB |
| `lucee-engine-7.0.4.34.zip` | `https://downloads.ortussolutions.com/lucee/lucee/7.0.4.34/cf-engine-7.0.4.34.zip` | ~65 MB |
| `code-server_4.135.0_amd64.deb` | `https://github.com/coder/code-server/releases/download/v4.135.0/code-server_4.135.0_amd64.deb` | ~228 MB |

All three are in `.gitignore`. The build works without them (stub/download
fallback) but pre-downloading eliminates QEMU network flakiness.

---

## Quick Reference: Full Build Sequence

```bash
# 1. Clone / enter project
cd ~/Desktop/coldfusion_training

# 2. Place downloads (see table above)
ls downloads/
# ColdFusion_2025_WWEJ_linux64.zip
# lucee-engine-7.0.4.34.zip
# code-server_4.135.0_amd64.deb

# 3. Build (first build ~30 min on Apple Silicon, cached rebuilds ~2 min)
make build-with-cf REGISTRY=ghcr.io/mercadoalex

# 4. Login and push
echo "ghp_..." | docker login ghcr.io -u mercadoalex --password-stdin
make push REGISTRY=ghcr.io/mercadoalex

# 5. Create playground
labctl playground create \
  -f playground/playground.yaml \
  -b flexbox \
  cf-alex

# 6. Open in browser
open https://labs.iximiuz.com/playgrounds/cf-alex-<suffix>
```

### Problem: No Root Drive Found

After creating the playground the UI showed:
```
Playground error: invalid play config: machine `cf-server` has invalid drives
config (in): no root drive found.
```

The `drives` entry was missing the `mount` field. The platform needs to know
which drive is the root filesystem.

**Fix:** Add `mount: /` to the drive definition:
```yaml
drives:
  - name: rootfs
    image: ghcr.io/mercadoalex/cf-training:dev
    mount: /
```


---

## Playground Update: Two More Manifest Errors

### Problem 1: Unknown Drive Source (missing `oci://` scheme)

```
request failed with status 400: {"error":"Invalid playground manifest:
Machine cf-server has an unknown drive source: ghcr.io/mercadoalex/cf-training:dev."}
```

iximiuz requires the `oci://` scheme prefix on drive `source` values. A bare
registry path is rejected.

**Fix:** Prefix the image reference with `oci://`:
```yaml
drives:
  - mount: /
    source: oci://ghcr.io/mercadoalex/cf-training:dev
```

### Problem 2: Duplicate Tab IDs

```
request failed with status 400: {"error":"Invalid playground manifest:
Tab IDs must be unique."}
```

Both HTTP-port tabs had the same `id: http-port-cf-server`. All tab IDs in a
playground manifest must be unique.

**Fix:** Give each tab a distinct ID:
```yaml
- id: http-cf-8500
  kind: http-port
  name: ColdFusion 2025
  machine: cf-server
  number: 8500
- id: http-cf-8888
  kind: http-port
  name: Lucee Dev Server
  machine: cf-server
  number: 8888
```

---

## First Boot Debugging: Four Runtime Failures

### Problem 1: ColdFusion EULA not accepted

CF refused to start with:
```
To start the server, you must accept the EULA. Run cfinstall script and accept the EULA terms and conditions.
```

The ZIP installer ships with `EULA_ACCEPTED=` (empty) in
`/opt/coldfusion2025/cfusion/lib/licenseinfo.properties`. There is no
`cfinstall` binary in the ZIP — the check is purely file-based.

**Fix in `install-coldfusion.sh`:** Set `EULA_ACCEPTED=true` at build time:
```bash
sed -i 's/EULA_ACCEPTED=/EULA_ACCEPTED=true/' "${CF_LIB}/licenseinfo.properties"
```

**Hot-patch for running VM:**
```bash
sudo sed -i 's/EULA_ACCEPTED=/EULA_ACCEPTED=true/' \
  /opt/coldfusion2025/cfusion/lib/licenseinfo.properties
sudo systemctl start cf-server.service
```

---

### Problem 2: `lucee-server.service` — wrong `box` path (status=127)

The service used `ExecStart=/usr/bin/env box` but the Ortus APT package
installs `box` at `/usr/local/bin/box`, not `/usr/bin/box`.

**Fix in `lucee-server.service`:**
```
ExecStart=/usr/local/bin/box server start --console
ExecStop=/usr/local/bin/box server stop
```

---

### Problem 3: `lucee-server.service` — `java` not found

After fixing the `box` path, the service failed with:
```
/usr/local/bin/box: 72: exec: java: not found
```

The service environment had no `JAVA_HOME` and no JRE on `PATH`. The system
has no standalone Java — only CF's bundled JRE at `/opt/coldfusion2025/jre`.

**Fix in `lucee-server.service`:** Add `JAVA_HOME` and prepend the JRE to PATH:
```
Environment="JAVA_HOME=/opt/coldfusion2025/jre"
Environment="PATH=/opt/coldfusion2025/jre/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

---

### Problem 4: CommandBox home owned by root — `laborant` can't write

CommandBox needs to create `jsr223-webroot` and other runtime directories
inside `/opt/commandbox/` at startup. The directory was owned by `root`
(created during `docker build` which runs as root), but `lucee-server.service`
runs as `laborant`.

Error:
```
file or directory [/opt/commandbox/engine/cfml/cli/lucee-server/jsr223-webroot] does not exist
```

**Fix in `install-commandbox.sh`:** Chown the entire CommandBox home to the lab user:
```bash
chown -R "${LAB_USER}:${LAB_USER}" "${CB_HOME}"
```

**Hot-patch for running VM:**
```bash
sudo chown -R laborant:laborant /opt/commandbox
sudo systemctl restart lucee-server.service
```

---

### Problem 5: Lucee bound to `127.0.0.1` — iximiuz tab showed blank

After Lucee started successfully, the browser tab in iximiuz was blank.
The port was listening but only on loopback:
```
LISTEN 0  1000  [::ffff:127.0.0.1]:8888
```

iximiuz proxies the HTTP tab through the VM's external interface, so
loopback-only binds are unreachable from the browser.

**Fix in `server.json`:** Add `"host": "0.0.0.0"` to the web config:
```json
"web": {
  "http": { "port": 8888, "enable": true },
  "host": "0.0.0.0",
  "ssl": { "enable": false }
}
```

Also added `"openbrowser": false` to suppress the harmless but noisy
`Could not find web browser` / `No X11 DISPLAY` errors in the journal.

---

### Summary: Changes Required for Clean First Boot

| File | Change |
|---|---|
| `install-coldfusion.sh` | Pre-set `EULA_ACCEPTED=true` in `licenseinfo.properties` |
| `lucee-server.service` | Use `/usr/local/bin/box`; add `JAVA_HOME` and JRE to PATH |
| `install-commandbox.sh` | `chown -R laborant /opt/commandbox`; add `host: 0.0.0.0` and `openbrowser: false` to `server.json` |

---

## Datasource Configuration: neo-datasource.xml Deep Dive

### Problem: Wrong WDDX format crashes the SQL package

Our initial `neo-datasource.xml` used a plain `<struct>` at the top level.
CF 2025's SQL package expects a specific WDDX array format and crashes on startup
with a cascade of errors depending on what we put in the file:

| Format tried | Error |
|---|---|
| `<struct>` (plain) | `Struct cannot be cast to Vector` |
| `<struct type='coldfusion.server.ConfigMap'>` | `ConfigMap cannot be cast to Vector` |
| `<array length='0'>` | `0 >= 0` (bounds error) |
| `<array length='3'>` with settings structs | `intValue() null` / `extraData null` |
| `<array length='2'>` with `maxcachecount: 1200` | `intValue() null` |

### Solution: Extract the real file from the official Docker image

```bash
docker run --rm --platform linux/amd64 \
  -e acceptEULA=YES \
  -v /tmp/cf-extract:/extract \
  --entrypoint cp \
  adobecoldfusion/coldfusion:latest-2025 \
  /opt/coldfusion/cfusion/lib/neo-datasource.xml /extract/
```

The real default file is `<array length='2'>` with `maxcachecount: 100.0` — not
1200, and only two structs (not three like `neo-drivers.xml`).

### The correct empty format

```xml
<wddxPacket version='1.0'>
<header/>
<data>
<array length='2'>
<struct type='coldfusion.server.ConfigMap'>
</struct>
<struct type='coldfusion.server.ConfigMap'>
<var name='maxcachecount'><number>100.0</number></var>
</struct>
</array>
</data>
</wddxPacket>
```

### Datasource entry format

CF 2025 writes datasource entries into the first struct. The exact format was
captured by registering `training_db` through the Admin UI and reading back
what CF wrote. Key fields:

- `DRIVER` — path to the JDBC jar (not the driver class name)
- `CLASS` — the JDBC driver class
- `NAME` — datasource name (uppercase)
- `ISJ2EE` — must be `false` for non-J2EE datasources
- `urlmap` — nested struct with many optional fields, all required to be present
- Empty string fields must use `<string></string>` — **not** multiline with newlines
  (newlines get encoded as `<char code='0a'/>` which breaks CF's parser)

### Problem: CF 2025 ships with zero JDBC drivers

No H2, no Derby, no MySQL — nothing. The H2 jar must be downloaded and placed
in `/opt/coldfusion2025/cfusion/lib/` before the datasource will work.

**Fix in `install-coldfusion.sh`:** Download H2 2.2.224 from Maven at build time:
```bash
curl -fsSL -o "${CF_HOME}/cfusion/lib/h2-2.2.224.jar" \
  https://repo1.maven.org/maven2/com/h2database/h2/2.2.224/h2-2.2.224.jar
```

### Help Desk seed schema

Four tables pre-populated at build time via `seed-db.cfm`:

| Table | Rows | Purpose |
|---|---|---|
| `hd_departments` | 4 | IT, Dev, HR, Finance |
| `hd_users` | 6 | admin, agents, end users |
| `hd_tickets` | 10 | Mixed status/priority/category |
| `hd_comments` | 9 | Thread replies, internal notes |

Access: `http://<vm>:8500/seed-db.cfm` (safe to re-run — skips if data exists)
View: `http://<vm>:8500/db-test.cfm`

---

## iximiuz Labs Course Content: Critical Schema Rules

**Date discovered:** 2026-09-04 — cost ~5 hours of debugging.

---

### Problem 1: Lesson body content not rendering ("Lesson not found" / blank after frontmatter)

**Symptom:** Clicking "Start Lesson" either showed "Lesson not found" or the lesson opened but rendered nothing below the `tagz:` frontmatter field. Tasks were not visible.

**Root cause:** The iximiuz platform does **not** render content written in the body of `index.md` (after the closing `---`). The lesson body **must** live in a separate `unit-1.md` file.

**The correct lesson structure:**

```
course-foundations/
  module-1/
    0.index.md               ← kind: module  (frontmatter only, no body)
    1.lesson-introduction/
      index.md               ← kind: lesson  (frontmatter + tasks only, NO body text)
      unit-1.md              ← kind: unit    (ALL the readable content goes here)
```

**`index.md` — frontmatter + tasks only, body must be empty:**
```yaml
---
kind: lesson
title: Introduction to ColdFusion
name: introduction-to-coldfusion
slug: introduction-to-coldfusion
createdAt: 2026-09-03
updatedAt: 2026-09-03
categories:
- programming
tagz:
- coldfusion
playground:
  name: cf-alex-edcdf975
tasks:
  verify_cf_running:
    machine: dev-machine
    user: laborant
    run: |
      ...
---
```
← file ends here, nothing after the closing `---`

**`unit-1.md` — all readable content:**
```yaml
---
kind: unit
title: Introduction to ColdFusion
name: introduction-to-coldfusion-unit-1
---

## What is ColdFusion?

All lesson prose, code blocks, tables, and diagrams go here.
```

---

### Problem 2: Modules showing as empty (`modules: {}`) after push

**Symptom:** `labctl content list` showed `learning: modules: {}` for the course. Lessons pushed fine but the course had no module structure. Clicking any lesson showed "Lesson not found".

**Root cause:** Every `0.index.md` module file was missing the `name:` field. Without it the platform cannot register the module.

**Fix — add `name: module-N` to every `0.index.md`:**
```yaml
---
kind: module
title: CFML Fundamentals
name: module-1          # ← THIS IS REQUIRED
description: |
  ...
createdAt: 2026-09-03
updatedAt: 2026-09-03
---
```

---

### Problem 3: `labctl content push` skipping all files silently

**Symptom:** Push output showed `Skipping...` for every file with warning `huh: could not open a new TTY`.

**Root cause:** `labctl` detected files were already on the server and prompted interactively for confirmation. No TTY available so it skipped everything.

**Fix:** Always use `-f` (force) flag when pushing updates:
```bash
labctl content push -f course <course-name> -d <dir>
```

---

### Problem 4: Playground name mismatch

**Symptom:** Lessons referenced a playground that didn't exist, causing "playground not found" errors.

**Root cause:** `playground.yaml` and all lesson `index.md` files had the old playground name (`cf-alex-697a46bc`) instead of the real one (`cf-alex-edcdf975`).

**Fix:** Check the real playground name with:
```bash
labctl playground list
labctl playground manifest <name>
```
Then update `playground/playground.yaml` and all lesson files:
```bash
find course-foundations course-advanced -name "index.md" | \
  xargs sed -i '' 's/old-name/new-name/g'
```

---

### Quick reference: full working push sequence

```bash
export PATH=$PATH:/Users/alexmarket/.iximiuz/labctl/bin

# Push entire course (force overwrite)
labctl content push -f course ColdFusion-2025-Foundations-5151cba6 -d course-foundations

# Push a single lesson only
labctl content push -f course ColdFusion-2025-Foundations-5151cba6 -d course-foundations \
  --file module-1/1.lesson-introduction/index.md \
  --file module-1/1.lesson-introduction/unit-1.md

# Verify what the platform actually has
labctl content pull course ColdFusion-2025-Foundations-5151cba6 -d /tmp/cf-pull
```

---

### Challenge slugs (platform-assigned hashes)

| Directory | Platform slug |
|---|---|
| application-lifecycle | `application-lifecycle-84261e98` |
| caching | `caching-10837ff1` |
| cfml-syntax | `cfml-syntax-0b4b2335` |
| charts | `charts-0e333dfe` |
| cicd-pipeline | `cicd-pipeline-6f98584e` |
| commandbox-server | `commandbox-server-9bac5899` |
| datasource-verify | `datasource-verify-be971bb2` |
| health-endpoint | `health-endpoint-a895d35e` |
| hello-cfml | `hello-cfml-9cc7ac40` |
| html5-page | `html5-page-5ef19f87` |
| lucee | `lucee-5db89516` |
| multimedia | `multimedia-c7c70611` |
| oop-cfc | `oop-cfc-88277abe` |
| orm-entity | `orm-entity-4c08a96a` |
| performance | `performance-9b4234b3` |
| scope-inspector | `scope-inspector-5e09720b` |
| security | `security-c2586cd1` |
| soap-webservices | `soap-webservices-8f4e8ae9` |
| sql-query | `sql-query-9af1b639` |
| student-api | `student-api-7309bb97` |
| testing | `testing-8f70b2b0` |
| websockets | `websockets-6e5e8d19` |

### Tutorial slugs (platform-assigned hashes)

| Directory | Platform slug |
|---|---|
| application-cfc | `application-cfc-7ff3dd6a` |
| building-json-api | `building-json-api-a164dcdd` |
| caching | `caching-6e1de2c6` |
| cf-admin-walkthrough | `cf-admin-walkthrough-32331eea` |
| cfml-forms | `cfml-forms-7cb92987` |
| cfml-hello-world | `cfml-hello-world-e1f5ffe6` |
| cfml-syntax-tags-script | `cfml-syntax-tags-script-8030387a` |
| charts | `charts-f5aac72d` |
| cicd-docker | `cicd-docker-894766b4` |
| commandbox-quick-start | `commandbox-quick-start-f662a678` |
| html5-cfml | `html5-cfml-1b6822c7` |
| jvm-performance | `jvm-performance-a3fe404e` |
| lucee-vs-adobe | `lucee-vs-adobe-8d09f288` |
| multimedia-upload | `multimedia-upload-77a00540` |
| orm-entity | `orm-entity-4af23db8` |
| production-health | `production-health-bc319635` |
| querying-h2-database | `querying-h2-database-d42dc6fc` |
| security | `security-6bd5e168` |
| soap-webservices | `soap-webservices-e2862a3d` |
| sql-cfqueryparam | `sql-cfqueryparam-402def62` |
| testing-debugging | `testing-debugging-bb188957` |
| variables-scopes | `variables-scopes-c0eb022e` |
| websockets | `websockets-22418e02` |

---

### Budget Exceeded
Oh no! It looks like you've gone over your budget allowance of 350 Bobcoins. You can manage your subscription to update your plan and continue.

---

