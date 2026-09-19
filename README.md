# ColdFusion 2025: Production & AI

Advanced ColdFusion 2025 training published on
[iximiuz Labs](https://labs.iximiuz.com/courses/ColdFusion-2025-Production-and-AI-6124d4b3).
Covers DevOps, CI/CD, cloud deployment, Java integration, and AI-powered
applications with Ollama. Students get a real Linux multi-VM environment —
no local setup required.

> **Prerequisites:** Completion of
> [ColdFusion 2025: Foundations](https://labs.iximiuz.com/courses/ColdFusion-2025-Foundations-5151cba6)
> or equivalent experience with CFML, REST APIs, and databases.

---

## Lab Environment

Three microVMs boot together for every session:

| VM | Image tag | Services | Purpose |
|---|---|---|---|
| `cf-dev` | `:advanced` | CF 2025, Lucee 7, VS Code | Development workstation |
| `cf-prod` | `:advanced` | CF 2025 | Production promotion target |
| `ollama` | `:latest` (cf-ollama) | Ollama + phi3:mini | Local LLM for AI exercises |

---

## Repository Layout

```
.
├── Makefile                            # Build, tag, push targets
├── README.md
├── course-advanced/                    # iximiuz course content
│   ├── index.md                        # Course manifest (kind: course)
│   ├── module-1/  CI/CD & Production
│   ├── module-2/  Java, XML, Cloud, CF Admin
│   ├── module-3/  Scheduling, Integration, Solr
│   ├── module-4/  Complementary tools
│   └── module-5/  AI with Ollama & ColdBox MVC
├── challenges/
│   └── advanced/                       # Challenge content (kind: challenge)
├── playground/
│   ├── playground.yaml                 # Advanced course playground manifest
│   └── playground-foundations.yaml    # Foundations course playground manifest
├── rootfs/
│   ├── Dockerfile                      # cf-training:advanced image
│   ├── Dockerfile.ollama               # cf-ollama:latest image
│   ├── app/                            # Starter app (CF 2025 + Lucee)
│   ├── cf-config/                      # CF silent-install & datasource config
│   └── scripts/                        # Install & systemd unit scripts
├── docs/
│   ├── BUILD_JOURNAL.md                # Build decisions & lessons learned
│   └── CHALLENGE_AUTHORING.md         # iximiuz challenge authoring rules
├── tutorials/
└── downloads/                          # CF installer binaries (git-ignored)
```

---

## Prerequisites

- Docker with BuildKit enabled (`DOCKER_BUILDKIT=1`)
- Push access to an OCI registry (e.g. `ghcr.io/<you>`)
- Adobe ColdFusion 2025 ZIP installer — see [Download Instructions](#download-cf-installer)

---

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/mercadoalex/curso-avanzado-coldfusion.git
cd curso-avanzado-coldfusion
export REGISTRY=ghcr.io/mercadoalex
```

### 2. Download the ColdFusion installer

```bash
make downloads   # prints exact instructions
```

Place the ZIP at `downloads/ColdFusion_2025_WWEJ_linux64.zip`.

> Adobe ColdFusion 2025 Developer Edition is **free** — 2 CPUs, 2 instances,
> no expiry. Download at https://helpx.adobe.com/coldfusion/using/download-coldfusion.html

### 3. Build the images

```bash
# Build cf-training:advanced (CF dev + prod node)
make build-with-cf REGISTRY=ghcr.io/mercadoalex

# Build cf-ollama:latest (Ollama AI node — downloads phi3:mini ~2.3 GB)
make build-ollama REGISTRY=ghcr.io/mercadoalex
```

> Use `make build` (no CF installer) for layout/CI testing in stub mode.

### 4. Tag and push

```bash
# Tag the dev build as :advanced and push
make tag-advanced REGISTRY=ghcr.io/mercadoalex

# Push the Ollama image
make push-ollama REGISTRY=ghcr.io/mercadoalex
```

### 5. Publish the course

```bash
# Push course content to iximiuz Labs
labctl content push -f course ColdFusion-2025-Production-and-AI-6124d4b3 -d course-advanced
```

See [`docs/CHALLENGE_AUTHORING.md`](docs/CHALLENGE_AUTHORING.md) for the full
challenge → lesson → course push workflow.

---

## Image Details

### `cf-training:advanced` (cf-dev and cf-prod nodes)

| Component | Details |
|---|---|
| **Base OS** | Ubuntu 24.04 LTS (amd64) |
| **ColdFusion 2025** | Developer Edition, `/opt/coldfusion2025`, port **8500** |
| **CommandBox + Lucee 7** | `box` CLI on PATH, Lucee dev server on port **8888** |
| **Init system** | systemd (PID 1), serial console on `ttyS0` |
| **Online IDE** | code-server (VS Code in browser) with CFML syntax extension |
| **Datasources** | H2 embedded (`training_db`) + MySQL stub |
| **Task engine** | iximiuz `examiner` daemon |

### `cf-ollama:latest` (Ollama AI node)

| Component | Details |
|---|---|
| **Base OS** | Ubuntu 24.04 LTS (amd64) |
| **Ollama** | Latest release, port **11434** |
| **Model** | `phi3:mini` (~2.3 GB, baked into image at build time) |
| **Init system** | systemd (PID 1) |

---

## CF Admin Credentials

| Field | Value |
|---|---|
| URL | `http://<cf-dev>:8500/CFIDE/administrator/` |
| Username | `admin` |
| Password | `training` |

Pre-set in [`rootfs/cf-config/neo-security.xml`](rootfs/cf-config/neo-security.xml).

---

## Makefile Targets

| Target | Description |
|---|---|
| `make build` | Build `cf-training` image (stub mode if no CF ZIP found) |
| `make build-with-cf` | Build with real ColdFusion installer (errors if missing) |
| `make build-ollama` | Build `cf-ollama` image (pulls phi3:mini at build time) |
| `make tag-advanced` | Tag current dev build as `:advanced` and push |
| `make tag-fundamentals` | Tag current dev build as `:fundamentals` and push |
| `make push-ollama` | Build and push the Ollama image |
| `make run` | Run image locally as a container (filesystem inspection only) |
| `make shell` | Open a shell in the built image |
| `make inspect` | Show image layers and size |
| `make update-playground` | Patch `playground/playground.yaml` with current image tag |
| `make downloads` | Print CF installer download instructions |
| `make clean` | Remove local image artifacts |

---

## iximiuz OCI Rootfs Requirements

| Requirement | How it's met |
|---|---|
| Boots as a microVM | systemd as PID 1, `udev`, `kmod` installed |
| Serial console (`ttyS0`) | `getty@ttyS0.service` enabled |
| Valid OCI image | Standard `docker build` → `docker push` |
| `amd64` / `linux` | Ubuntu 24.04 x86_64, built with `--platform linux/amd64` |
| SSH access | `openssh-server` enabled, host keys generated on first boot |
| iximiuz task engine | `examiner` binary installed, `examiner.service` enabled |

---

## Platform Slugs Reference

| Item | Slug |
|---|---|
| **Course — Advanced** | `ColdFusion-2025-Production-and-AI-6124d4b3` |
| **Course — Foundations** | `ColdFusion-2025-Foundations-5151cba6` |
| **Playground — Advanced** | `cf-training-advanced-7442b9e0` |
| **Playground — Foundations** | `cf-alex-edcdf975` |

---

## Key Docs

- [`docs/BUILD_JOURNAL.md`](docs/BUILD_JOURNAL.md) — full build history,
  platform gotchas, and lessons learned
- [`docs/CHALLENGE_AUTHORING.md`](docs/CHALLENGE_AUTHORING.md) — step-by-step
  guide for authoring and publishing challenges on iximiuz Labs

---

## Download CF Installer

1. Go to https://helpx.adobe.com/coldfusion/using/download-coldfusion.html
2. Select **ColdFusion 2025 Trial Edition → Linux 64-bit ZIP installer**
3. Place the file at `downloads/ColdFusion_2025_WWEJ_linux64.zip`

> `downloads/` is git-ignored — do not commit the binary.

---

## About Me
Soy Alex
