---
kind: unit

title: DevOps for ColdFusion

name: cicd-pipelines-coldfusion-unit-1
---

## What is DevOps?

**DevOps** is a culture, a set of practices, and a toolchain that breaks down the wall between software **development** (Dev) and IT **operations** (Ops). The goal is simple: ship better software, faster, with fewer failures — by automating everything that can be automated and making collaboration the default.

::image-box
---
:src: __static__/devops-infinity-loop-v1.png
:alt: DevOps infinity loop diagram showing the eight stages — Plan, Code, Build, Test, Release, Deploy, Operate, Monitor — arranged as a continuous figure-eight, with DEV on the left and OPS on the right, and CI/CD at the centre crossing point
:max-width: 860px
---
_The DevOps lifecycle: eight stages flowing continuously from development through operations and back again._
::

::hint-box
---
:summary: The traditional Dev vs Ops conflict — and why it matters
---
In a traditional organisation, developers write code and throw it "over the wall" to operations, who are responsible for keeping production stable. Developers want to ship fast; operations wants stability. These goals clash constantly.

DevOps resolves this by making both teams jointly responsible for the full software lifecycle — from writing code to running it in production. The team that builds it also deploys and monitors it. Incentives align: you don't ship something you can't support.
::

The three pillars of DevOps are:

| Pillar | What it means |
|---|---|
| **People & Culture** | Shared ownership, blame-free postmortems, cross-functional teams |
| **Process** | Lean workflows, small frequent releases, infrastructure as code |
| **Tools** | Version control, CI/CD pipelines, containers, monitoring |

DevOps is not a job title and not a single tool — it is an organisational approach that changes how teams work together.

---

## Where does ColdFusion fit?

ColdFusion has a reputation as a technology that resists DevOps adoption. There are historical reasons for this: CF apps were often deployed by copying `.cfm` files over FTP, environments were configured by hand through the CF Admin UI, and "works on my machine" was an accepted explanation for production failures.

That reputation is outdated. ColdFusion 2025 runs cleanly in Docker, supports CommandBox for dependency management and scripted server configuration, and integrates with any CI/CD platform that can run a shell command. Every DevOps practice covered in this lesson applies directly to a modern CF application.

---

## What is CI/CD and why does it matter for ColdFusion?

**Continuous Integration / Continuous Delivery (CI/CD)** is the practice of automating the build, test, and deployment cycle every time code is pushed. For ColdFusion shops still relying on manual FTP uploads and click-through deploys, CI/CD is a transformative shift.

::image-box
---
:src: __static__/cicd-pipeline-overview-v1.png
:alt: Diagram showing a CI/CD pipeline flow — developer pushes code to GitHub, GitHub Actions triggers a workflow that builds a Docker image, runs CFML tests, pushes the image to GHCR, and deploys to cf-prod via SSH, with a green checkmark at the end
:max-width: 900px
---
_A complete ColdFusion CI/CD pipeline: push → build → test → deploy._
::

| Stage | What happens |
|---|---|
| **CI — Continuous Integration** | Every push triggers an automated build and test run |
| **CD — Continuous Delivery** | Passing builds are automatically packaged and ready to deploy |
| **CD — Continuous Deployment** | Passing builds are automatically deployed to production |

::hint-box
---
:summary: 💡 Why does CF traditionally skip CI/CD?
---
ColdFusion's interpreted nature means there's no compile step — drop a `.cfm` file and it runs. This convenience historically made CI/CD feel unnecessary. But it creates real risks: untested code ships, environments drift, rollbacks require manual FTP gymnastics, and nobody remembers what changed when production breaks at 2am.

A proper CI/CD pipeline gives you: a record of every change, automatic tests before deployment, repeatable builds from a clean state, and one-command rollbacks.
::

---

## Your CI/CD toolchain

This lesson uses tools already available in your environment:

| Tool | Role |
|---|---|
| **Git + GitHub** | Source control and trigger for CI runs |
| **GitHub Actions** | CI/CD workflow engine (free for public repos) |
| **Docker** | Packages the app + CF runtime into a portable image |
| **GHCR** | GitHub Container Registry — stores your Docker images |
| `cf-dev` | Build and development machine |
| `cf-prod` | Deployment target (production) |

---

## 1. Dockerise your ColdFusion application

The first step is packaging your app as a Docker image so it can be built and run consistently anywhere.

::image-box
---
:src: __static__/dockerfile-cf-app-v1.png
:alt: A Dockerfile open in VS Code showing a multi-stage build — FROM adobecoldfusion/coldfusion2025 as base, COPY app/ to wwwroot, ENV acceptEULA=YES, EXPOSE 8500, and a HEALTHCHECK instruction pointing to /index.cfm
:max-width: 860px
---
_A minimal ColdFusion 2025 Dockerfile — the foundation of your CI/CD pipeline._
::

**Activity:** In the **Terminal (dev)** tab, create your project directory and Dockerfile:

```bash
mkdir -p /home/laborant/app
cd /home/laborant/app
```

Create `/home/laborant/app/Dockerfile`:

```bash
tee /home/laborant/app/Dockerfile << 'EOF'
FROM adobecoldfusion/coldfusion2025:latest

# Accept the EULA — required for non-interactive installs
ENV acceptEULA=YES
ENV password=admin

# Copy application code into the CF webroot
COPY app/ /opt/coldfusion2025/cfusion/wwwroot/

# Expose the CF HTTP port
EXPOSE 8500

# Health check — CF is ready when /index.cfm returns 200
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:8500/index.cfm || exit 1
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_dockerfile_exists
---
#active
Create `/home/laborant/app/Dockerfile` containing a ColdFusion `FROM` instruction and an `EXPOSE 8500` line.

#completed
Dockerfile found at `/home/laborant/app/Dockerfile`. ✓
::

---

## 2. Create a GitHub Actions workflow

GitHub Actions workflows live in `.github/workflows/` and are triggered by git events (push, pull request, tag). A workflow file is YAML that defines jobs and steps.

::image-box
---
:src: __static__/github-actions-workflow-v1.png
:alt: GitHub Actions workflow YAML file open in VS Code — showing the on push trigger, a build job with steps for docker login, docker build, docker push, and an SSH deploy step using appleboy/ssh-action
:max-width: 860px
---
_A complete GitHub Actions workflow for building and deploying a ColdFusion Docker image._
::

**Activity:** Create the workflow directory and file:

```bash
mkdir -p /home/laborant/app/.github/workflows
```

Create `/home/laborant/app/.github/workflows/deploy.yml`:

```bash
tee /home/laborant/app/.github/workflows/deploy.yml << 'EOF'
name: Build and Deploy ColdFusion App

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      # ── 1. Check out the code ─────────────────────────────────────────
      - name: Checkout
        uses: actions/checkout@v4

      # ── 2. Log in to GitHub Container Registry ────────────────────────
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # ── 3. Build and push the Docker image ────────────────────────────
      - name: Build and push image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

      # ── 4. Deploy to cf-prod via SSH ──────────────────────────────────
      - name: Deploy to cf-prod
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.PROD_HOST }}
          username: laborant
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            docker pull ghcr.io/${{ github.repository }}:${{ github.sha }}
            docker stop cf-app || true
            docker run -d --name cf-app --rm \
              -p 8500:8500 \
              ghcr.io/${{ github.repository }}:${{ github.sha }}
            curl -sf http://localhost:8500/index.cfm && echo "Deploy OK"
EOF
```

::hint-box
---
:summary: What are GitHub Actions secrets?
---
Secrets like `PROD_HOST` and `PROD_SSH_KEY` are encrypted values stored in your GitHub repository settings under **Settings → Secrets and variables → Actions**. They are never visible in logs and are injected as environment variables during the workflow run.

For this lab exercise, the workflow file structure is what matters — you won't actually run it against GitHub. The task just verifies the workflow file exists and is valid YAML.
::

::simple-task
---
:tasks: tasks
:name: verify_github_actions_workflow
---
#active
Create a GitHub Actions workflow file under `.github/workflows/` (`.yml` or `.yaml` extension).

#completed
GitHub Actions workflow file found. ✓
::

---

## 3. Build and test locally

Before pushing to GitHub, validate the Dockerfile builds cleanly on `cf-dev`:

```bash
cd /home/laborant/app

# Build the image (this will pull the CF base image ~1.5 GB on first run)
docker build -t cf-app:local .

# Smoke test — run locally and curl
docker run -d --name cf-test -p 8501:8500 cf-app:local
sleep 30   # wait for CF to start
curl -sf http://localhost:8501/index.cfm && echo "Local build OK"

# Clean up
docker stop cf-test && docker rm cf-test
```

::hint-box
---
:summary: Docker not available in the lab?
---
The lab VM has Docker installed but you may need to start the daemon first:

```bash
sudo systemctl start docker
sudo systemctl enable docker
# Add laborant to the docker group (takes effect on next login)
sudo usermod -aG docker laborant
```

If you get a "permission denied" error on `docker build`, log out and back in so the group change takes effect, or prefix commands with `sudo`.
::

---

## 4. The CI/CD workflow in practice

Here is the complete developer workflow once your pipeline is in place:

```
1. Write code on cf-dev
2. git commit -m "fix: resolve ticket query timeout"
3. git push origin main
4. GitHub Actions triggers automatically:
   a. Pulls fresh copy of the repo
   b. Builds Docker image from Dockerfile
   c. Pushes image to GHCR with the commit SHA as tag
   d. SSHs into cf-prod and pulls + runs the new image
5. Receive Slack/email notification: ✅ Deployed abc1234 to cf-prod
```

| Benefit | Traditional FTP | CI/CD pipeline |
|---|---|---|
| Repeatability | ❌ Manual, varies per person | ✅ Same steps every time |
| Audit trail | ❌ Who uploaded what, when? | ✅ Every deploy linked to a commit |
| Rollback | ❌ Restore from backup manually | ✅ `docker pull image:previous-sha` |
| Testing | ❌ "Looks good on my machine" | ✅ Automated tests block bad deploys |

---

## Key concepts reference

| Term | Meaning |
|---|---|
| **Workflow** | A YAML file in `.github/workflows/` that defines when and what to run |
| **Job** | A set of steps that runs on the same runner machine |
| **Step** | A single command or Action (reusable workflow unit) |
| **Runner** | The VM that executes your workflow (Ubuntu in this lesson) |
| **Secret** | Encrypted variable stored in GitHub, injected at runtime |
| **GHCR** | GitHub Container Registry — `ghcr.io/<owner>/<repo>:<tag>` |
| **SHA tag** | Using the git commit hash as the Docker image tag for traceability |

---

When both tasks above are green, this lesson is complete. You have applied the core DevOps loop to a ColdFusion application: code → build → test → deploy, automated end to end.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Both the Dockerfile and workflow file are in place — hit **Check** to complete the lesson.

#completed
DevOps lesson complete. On to the next one! ✓
::

---

## Now Prove It

Apply what you've learned in the challenge below. You'll wire together a Dockerfile and a GitHub Actions workflow for a ColdFusion microservice.

::card
---
:challenge: challenges.cicd-pipelines-9fa2ce74
---
::
