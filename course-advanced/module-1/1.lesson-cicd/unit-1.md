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

::hint-box
---
:summary: Coming from the Foundations course? Here's where we left off.
---
In **ColdFusion 2025: Foundations** (Module 4 — CI/CD for CFML Applications) you built your first pipeline: a `box.json`-managed project packaged with CommandBox, a `Dockerfile` for the application, and a GitHub Actions workflow that built a Docker image on every push.

That lesson established the basics: version-controlled code, a reproducible Docker build, and an automated trigger. **This lesson picks up exactly where that ended** — and goes further:

| Foundations covered | This lesson adds |
|---|---|
| `box.json` + CommandBox packaging | Multi-stage deployment to a real `cf-prod` VM |
| Single `Dockerfile` | Full GitHub Actions workflow with SSH deploy step |
| Local `docker build` | GHCR image registry + commit-SHA tagging |
| Concept of CI/CD | The DevOps culture and loop behind the tools |

If you haven't completed the Foundations CI/CD lesson, you can still follow along — everything is built from scratch here.
::

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

This lesson uses a **fully local** toolchain — everything runs inside your lab VMs, no external accounts needed:

| Tool | Role | Where |
|---|---|---|
| **Git** | Version control | `cf-dev` |
| **Gitea** | Self-hosted Git server + CI/CD engine | `cf-dev:3000` |
| **Gitea Actions** | Workflow runner (GitHub Actions-compatible YAML) | `cf-dev` |
| **Docker** | Packages the app + CF runtime into a portable image | `cf-dev` |
| **Local registry** | Stores Docker images (`localhost:5000`) | `cf-dev` |
| `cf-prod` | Deployment target (production) | `cf-prod` |

::hint-box
---
:summary: Why Gitea instead of GitHub?
---
**Gitea** is a lightweight, self-hosted Git service — a single ~100 MB binary that provides a full Git server, pull requests, issue tracker, and a CI/CD engine (Gitea Actions) whose workflow YAML is fully compatible with GitHub Actions syntax.

Running Gitea locally means:
- **No internet dependency** — the full pipeline runs inside the lab network
- **No accounts needed** — admin credentials are set during setup
- **Real CI/CD** — workflows actually trigger and run, not just files that exist on disk
- **Transferable skills** — the YAML you write here works unchanged on GitHub, Gitea, or Forgejo

In production you would replace `localhost:3000` with your organisation's Gitea/GitHub/GitLab URL — the pipeline logic stays identical.
::

::hint-box
---
:summary: These tools are choices, not requirements — here are the alternatives
---
| Layer | This lesson uses | Common alternatives |
|---|---|---|
| **Version control** | Git | Subversion (SVN), Mercurial, Perforce |
| **Git server** | Gitea (self-hosted) | GitHub, GitLab, Bitbucket, Azure DevOps |
| **CI/CD engine** | Gitea Actions | GitHub Actions, Jenkins, CircleCI, GitLab CI, Drone |
| **Container runtime** | Docker | Podman, containerd, Buildah |
| **Image registry** | Local registry (`localhost:5000`) | GHCR, Docker Hub, AWS ECR, Azure ACR |
| **Production target** | `cf-prod` VM | AWS, Azure, GCP, DigitalOcean, bare-metal |
::

---

## 0. Set up Gitea — your local Git server

**Activity — Terminal (dev):** Install and configure Gitea on `cf-dev`. This takes about 60 seconds.

The purpose of this activity is to:
1. Download the Gitea binary (~100 MB)
2. Start it as a background service on port `3000`
3. Create an admin user and a repository for the CF app

Run the following in the **Terminal (dev)** tab:

```bash
# Download Gitea binary
GITEA_VERSION=1.22.3
sudo curl -fsSL \
  https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64 \
  -o /usr/local/bin/gitea
sudo chmod +x /usr/local/bin/gitea

# Create gitea user and directories
sudo useradd -m -s /bin/bash git 2>/dev/null || true
sudo mkdir -p /var/lib/gitea/{custom,data,log} /etc/gitea
sudo chown -R git:git /var/lib/gitea /etc/gitea
sudo chmod 750 /etc/gitea

# Write a minimal app.ini config
sudo tee /etc/gitea/app.ini > /dev/null << 'CONF'
[server]
HTTP_PORT = 3000
ROOT_URL  = http://localhost:3000/

[database]
DB_TYPE = sqlite3
PATH    = /var/lib/gitea/data/gitea.db

[security]
INSTALL_LOCK   = true
SECRET_KEY     = labsecretkey12345678

[log]
MODE  = console
LEVEL = Warn
CONF

# Start Gitea as a background process
sudo -u git /usr/local/bin/gitea web \
  --config /etc/gitea/app.ini \
  --work-path /var/lib/gitea &> /var/lib/gitea/log/gitea.log &

echo "Waiting for Gitea to start..."
sleep 8

# Create admin user
sudo -u git /usr/local/bin/gitea admin user create \
  --config /etc/gitea/app.ini \
  --username labadmin \
  --password labpassword \
  --email lab@localhost \
  --admin \
  --must-change-password=false

echo "Gitea is ready at http://localhost:3000 (user: labadmin / pass: labpassword)"
```

> ⏱️ The download takes ~30 seconds depending on network speed. Once you see "Gitea is ready" the **Gitea** tab in the lab will show the login page.

::simple-task
---
:tasks: tasks
:name: verify_gitea_running
---
#active
In the **Terminal (dev)** tab, run the setup script above. Once complete, confirm the **Gitea** tab loads the login page at `http://localhost:3000`.

#completed
Gitea is running and accessible. ✓
::

---

## 1. Create a repository and push your app

**Activity — Terminal (dev):** Create a Gitea repository and push the CF app into it.

```bash
# Create the repository via Gitea API
curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -u labadmin:labpassword \
  -H "Content-Type: application/json" \
  -d '{"name":"cf-app","description":"ColdFusion CI/CD lab","private":false,"auto_init":false}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Repo created:', d.get('full_name','error'))"

# Set up the app directory and init git
mkdir -p /home/laborant/app/app
cd /home/laborant/app

# Create a minimal index.cfm if it doesn't exist
[ -f app/index.cfm ] || echo '<cfoutput>ColdFusion CI/CD Lab — OK</cfoutput>' > app/index.cfm

# Initialise git and push to Gitea
git init
git config user.email "lab@localhost"
git config user.name "Lab Student"
git remote add origin http://labadmin:labpassword@localhost:3000/labadmin/cf-app.git
git add .
git commit -m "initial commit"
git push -u origin main
```

::simple-task
---
:tasks: tasks
:name: verify_repo_pushed
---
#active
In the **Terminal (dev)** tab, create the Gitea repository and push the initial commit. Confirm the **Gitea** tab shows the `cf-app` repository with files.

#completed
Repository pushed to Gitea. ✓
::

---

## 2. Dockerise your ColdFusion application

The first step is packaging your app as a Docker image so it can be built and run consistently anywhere.

::image-box
---
:src: __static__/dockerfile-cf-app-v1.png
:alt: A Dockerfile open in VS Code showing a multi-stage build — FROM adobecoldfusion/coldfusion2025 as base, COPY app/ to wwwroot, ENV acceptEULA=YES, EXPOSE 8500, and a HEALTHCHECK instruction pointing to /index.cfm
:max-width: 860px
---
_A minimal ColdFusion 2025 Dockerfile — the foundation of your CI/CD pipeline._
::

**Activity — Terminal (dev):** Create the Dockerfile and push it to Gitea.

```bash
cd /home/laborant/app

tee Dockerfile << 'EOF'
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

git add Dockerfile
git commit -m "add Dockerfile"
git push
```

::simple-task
---
:tasks: tasks
:name: verify_dockerfile_exists
---
#active
Create `/home/laborant/app/Dockerfile` with a ColdFusion `FROM` instruction and `EXPOSE 8500`, then push it to Gitea.

#completed
Dockerfile found at `/home/laborant/app/Dockerfile`. ✓
::

---

## 3. Create a Gitea Actions workflow

Gitea Actions workflows live in `.gitea/workflows/` and use the same YAML syntax as GitHub Actions. The workflow triggers on every push to `main`, builds the Docker image, pushes it to a local registry, and deploys it to `cf-prod` via SSH.

**Activity — Terminal (dev):** Create the workflow file and push it.

```bash
cd /home/laborant/app
mkdir -p .gitea/workflows

tee .gitea/workflows/deploy.yml << 'EOF'
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
        uses: actions/checkout@v3

      # ── 2. Build the Docker image ─────────────────────────────────────
      - name: Build image
        run: |
          docker build -t localhost:5000/cf-app:${{ gitea.sha }} .

      # ── 3. Push to local registry ─────────────────────────────────────
      - name: Push to local registry
        run: |
          docker push localhost:5000/cf-app:${{ gitea.sha }}

      # ── 4. Deploy to cf-prod via SSH ──────────────────────────────────
      - name: Deploy to cf-prod
        run: |
          ssh -o StrictHostKeyChecking=no laborant@cf-prod \
            "docker pull localhost:5000/cf-app:${{ gitea.sha }} && \
             docker stop cf-app 2>/dev/null || true && \
             docker run -d --name cf-app --rm \
               -p 8500:8500 \
               localhost:5000/cf-app:${{ gitea.sha }} && \
             echo Deploy OK"
EOF

git add .gitea/
git commit -m "add Gitea Actions workflow"
git push
```

::hint-box
---
:summary: Gitea Actions vs GitHub Actions — what's different?
---
The YAML syntax is nearly identical. The key differences in this lab:

| | GitHub Actions | Gitea Actions (this lab) |
|---|---|---|
| Context variable | `github.sha` | `gitea.sha` |
| Registry | `ghcr.io` | `localhost:5000` (local) |
| Secrets | GitHub repo settings | Gitea repo settings |
| Runner | GitHub-hosted cloud VM | Self-hosted Act Runner on `cf-dev` |

Everything else — `on:`, `jobs:`, `steps:`, `uses:`, `run:` — is identical syntax.
::

::simple-task
---
:tasks: tasks
:name: verify_github_actions_workflow
---
#active
Create `.gitea/workflows/deploy.yml` with an `on: push` trigger and push it to Gitea.

#completed
Gitea Actions workflow file found. ✓
::

---

## 4. The CI/CD workflow in practice

Here is the complete developer workflow once your pipeline is in place:

```
1. Write code on cf-dev
2. git commit -m "fix: resolve ticket query timeout"
3. git push origin main
4. Gitea Actions triggers automatically:
   a. Pulls fresh copy of the repo
   b. Builds Docker image from Dockerfile
   c. Pushes image to local registry (localhost:5000)
   d. SSHs into cf-prod and pulls + runs the new image
5. Pipeline shows ✅ green in the Gitea tab → Actions
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
