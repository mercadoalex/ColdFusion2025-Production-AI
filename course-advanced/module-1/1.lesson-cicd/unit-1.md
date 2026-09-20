---
kind: unit

title: DevOps for ColdFusion

name: cicd-pipelines-coldfusion-unit-1
---

## Your next deploy should be a `git push`

You've deployed ColdFusion applications before. Maybe you SSH'd into the server, stopped CF, FTP'd the new files over, restarted, and hoped for the best. Maybe you got lucky and it worked first time. Maybe you didn't, and you spent an hour restoring files from a backup at midnight.

That workflow is not a pipeline — it's a prayer. This lesson replaces it.

**DevOps** is the set of practices and tools that turns deployment from a nerve-wracking manual process into a boring, automated event. By the end of this lesson you will have a working pipeline: push code to a Git repository, and a CI/CD engine builds a Docker image, pushes it to a local registry, and deploys it to your production VM — automatically, every time, with a full audit trail and one-command rollback.

::image-box
---
:src: __static__/cf-before-after-devops-v1.png
:alt: Side-by-side comparison. Left column labelled Before DevOps — Manual FTP era shows six red steps: SSH into server, stop ColdFusion, FTP new cfm files, start ColdFusion, something is broken, restart CF again — with notes about no audit trail and no rollback. Right column labelled After DevOps shows six green steps: git commit, git push origin main, pipeline builds Docker image and runs tests, pipeline pushes image to registry, pipeline SSH deploys to cf-prod, rollback equals docker run image colon previous sha — ten seconds no guessing.
:max-width: 960px
---
_Six manual error-prone steps replaced by one command. The pipeline does the rest._
::

By the end of this lesson you will have:

- A **Gitea** self-hosted Git repository running locally on `cf-dev`
- A **Dockerfile** that packages your CF app as a portable container image
- A **Gitea Actions** workflow that builds, pushes, and deploys automatically on every push
- A complete local toolchain — no internet, no external accounts, no surprises

::hint-box
---
:summary: Coming from the Foundations course? Here's where we left off.
---
In **ColdFusion 2025: Foundations** (Module 4 — CI/CD for CFML Applications) you built your first pipeline: a `box.json`-managed project packaged with CommandBox, a `Dockerfile` for the application, and a GitHub Actions workflow that built a Docker image on every push.

That lesson established the basics: version-controlled code, a reproducible Docker build, and an automated trigger. **This lesson picks up exactly where that ended** — and goes further:

| Foundations covered | This lesson adds |
|---|---|
| `box.json` + CommandBox packaging | Multi-stage deployment to a real `cf-prod` VM |
| Single `Dockerfile` | Full Gitea Actions workflow with SSH deploy step |
| Local `docker build` | Local image registry + commit-SHA tagging |
| Concept of CI/CD | The DevOps culture and loop behind the tools |

If you haven't completed the Foundations CI/CD lesson, you can still follow along — everything is built from scratch here.
::

::hint-box
---
:summary: Do I need to know Docker to start this lesson?
---
No prior Docker experience is required. You will write a four-line `Dockerfile` and run two Docker commands (`build` and `push`). The concepts are explained inline.

If you want deeper Docker knowledge alongside this lesson, the bridge lesson in this module covers containers from first principles. But for the CI/CD pipeline you're building here, those four lines are all you need.
::

---

## 1. The DevOps loop — why the eight stages matter

**DevOps** is a culture, a set of practices, and a toolchain that breaks down the wall between software **development** (Dev) and IT **operations** (Ops). The goal: ship better software, faster, with fewer failures — by automating everything that can be automated and making collaboration the default.

::image-box
---
:src: __static__/devops-infinity-loop-v1.png
:alt: DevOps infinity loop diagram showing the eight stages — Plan, Code, Build, Test, Release, Deploy, Operate, Monitor — arranged as a continuous figure-eight, with DEV on the left and OPS on the right, and CI/CD at the centre crossing point
:max-width: 860px
---
_The DevOps lifecycle: eight stages flowing continuously from development through operations and back again._
::

| Stage | What happens | ColdFusion example |
|---|---|---|
| **Plan** | Define what to build | Jira tickets, GitHub issues |
| **Code** | Write the feature | CFML, CFCs, SQL |
| **Build** | Package the artefact | `docker build` |
| **Test** | Run automated tests | TestBox, integration tests |
| **Release** | Tag and version the build | `git tag v2.1.0` |
| **Deploy** | Ship to production | `docker run` on `cf-prod` |
| **Operate** | Run and maintain | CF Admin, datasources, logs |
| **Monitor** | Observe and alert | ELK stack, dashboards |

The loop is continuous — Monitor feeds back into Plan, which starts the next cycle. This is the DevOps idea made concrete: there is no "done", only the next iteration.

::hint-box
---
:summary: The traditional Dev vs Ops conflict — and why it matters
---
In a traditional organisation, developers write code and throw it "over the wall" to operations, who are responsible for keeping production stable. Developers want to ship fast; operations wants stability. These goals clash constantly.

DevOps resolves this by making both teams jointly responsible for the full software lifecycle — from writing code to running it in production. The team that builds it also deploys and monitors it. Incentives align: you don't ship something you can't support.
::

::hint-box
---
:summary: DevOps is not a job title — it's an organisational approach
---
You may have seen job adverts for "DevOps Engineers." That role is real, but it is not what DevOps means. DevOps is a change in how the whole team works — not a new specialist you hire to handle deployments while everyone else keeps coding the old way.

The tools (Docker, CI/CD, monitoring) are the easy part. The culture (shared ownership, blame-free postmortems, automated everything) is the hard part. This lesson teaches the tools; the bridge lesson in this module explains the culture.
::

---

## 2. Where ColdFusion fits — and why the old reputation is wrong

ColdFusion has a reputation as a technology that resists DevOps adoption. That reputation has historical roots: CF apps were deployed by copying `.cfm` files over FTP, environments were configured by hand through the CF Admin UI, and "works on my machine" was an accepted explanation for production failures.

::image-box
---
:src: __static__/cf-before-after-devops-v1.png
:alt: Side-by-side comparison showing the six-step manual FTP deployment on the left versus the six-step automated git push pipeline on the right, highlighting that FTP has no audit trail and no rollback while the pipeline has commit SHA tagging and one-command rollback.
:max-width: 960px
---
_The same six deployment steps — one done manually, one done automatically with full history and rollback._
::

That reputation is outdated. ColdFusion 2025 runs cleanly in Docker, supports CommandBox for dependency management and scripted server configuration, and integrates with any CI/CD platform that can run a shell command. Every DevOps practice covered in this lesson applies directly to a modern CF application.

::hint-box
---
:summary: Why does CF traditionally skip CI/CD?
---
ColdFusion's interpreted nature means there's no compile step — drop a `.cfm` file and it runs. This convenience historically made CI/CD feel unnecessary. But it creates real risks:

- Untested code ships directly to production
- Environments drift (CF Admin settings differ between dev and prod)
- Rollbacks require manual FTP gymnastics
- Nobody remembers what changed when production breaks at 2am

A proper CI/CD pipeline gives you: a record of every change, automatic tests before deployment, repeatable builds from a clean state, and one-command rollbacks. **The interpreted nature of CFML is not an excuse to skip the pipeline — it's a reason to be more careful about having one.**
::

::hint-box
---
:summary: Does ColdFusion 2025 run in Docker officially?
---
Yes. Adobe publishes the official Docker image on Docker Hub:

```
adobecoldfusion/coldfusion2025:latest
```

This image includes the full CF 2025 engine, accepts `ENV acceptEULA=YES` to bypass the interactive installer, and exposes port 8500. It is the `FROM` line in every `Dockerfile` you'll write in this module.

The image is maintained by Adobe and updated with each CF patch release. Using the official image means your pipeline always builds on a known, supported base.
::

---

## 3. CI/CD explained — the three stages

**Continuous Integration / Continuous Delivery (CI/CD)** is the practice of automating the build, test, and deployment cycle every time code is pushed. For ColdFusion shops still relying on manual FTP uploads, CI/CD is a transformative shift.

::image-box
---
:src: __static__/cicd-pipeline-overview-v1.png
:alt: Diagram showing a CI/CD pipeline flow — developer pushes code to GitHub, GitHub Actions triggers a workflow that builds a Docker image, runs CFML tests, pushes the image to GHCR, and deploys to cf-prod via SSH, with a green checkmark at the end
:max-width: 900px
---
_A complete ColdFusion CI/CD pipeline: push → build → test → deploy._
::

| Stage | What happens | What it prevents |
|---|---|---|
| **CI — Continuous Integration** | Every push triggers automated build and tests | Broken code reaching production |
| **CD — Continuous Delivery** | Passing builds are packaged and ready to deploy | Manual packaging errors |
| **CD — Continuous Deployment** | Passing builds are automatically deployed | Human error in the deploy step |

Most teams start at Continuous Delivery (automated build + test, manual deploy trigger) and graduate to Continuous Deployment (fully automated) as they gain confidence in their test coverage.

::hint-box
---
:summary: CI vs CD — what's the actual difference?
---
**Continuous Integration (CI)** is the practice of merging developer branches into a shared main branch frequently — several times a day — with automated tests validating every merge. The goal: detect integration problems fast, before they compound.

**Continuous Delivery (CD)** extends CI: every merge that passes tests is automatically packaged into a deployable artefact (a Docker image in our case) and placed in a registry, ready to deploy. A human still clicks "Deploy to production."

**Continuous Deployment** removes the human — every passing build is automatically deployed to production. This requires high test coverage and confidence. It is not required to get the benefits of the pipeline; many teams use Continuous Delivery with a deliberate deploy step and that is perfectly sound practice.
::

---

## 4. Your local toolchain

This lesson uses a **fully local** toolchain — everything runs inside your lab VMs, no external accounts needed:

::image-box
---
:src: __static__/gitea-pipeline-flow-v1.png
:alt: End-to-end diagram of the local CI/CD toolchain. Top row shows Developer on cf-dev VM connecting via push to Gitea at localhost 3000 which triggers the Act Runner also on cf-dev. Below, four pipeline steps in boxes connected by arrows: Checkout using actions/checkout v3, docker build tagging with gitea.sha, docker push to localhost 5000, and SSH deploy to cf-prod. The docker push connects down to a Local Registry box at localhost 5000. The Local Registry has a pull arrow to the cf-prod VM box which shows docker run on port 8500. Legend: blue for pipeline trigger, green for deploy, purple dashed for image transfer. Caption: All components run on cf-dev — no internet required.
:max-width: 960px
---
_Every component in the toolchain runs on `cf-dev` — Gitea, Act Runner, and local registry all on the same VM._
::

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
| **CI/CD engine** | Gitea Actions | GitHub Actions, Jenkins, CircleCI, GitLab CI |
| **Container runtime** | Docker | Podman, containerd, Buildah |
| **Image registry** | Local registry (`localhost:5000`) | GHCR, Docker Hub, AWS ECR, Azure ACR |
| **Production target** | `cf-prod` VM | AWS, Azure, GCP, DigitalOcean, bare-metal |
::

---

## 5. Confirm Gitea is running

Gitea is **pre-installed** in this lab — it starts automatically when the VM boots. No download, no waiting.

**Activity — Terminal (dev):** Verify Gitea is up and open the web UI.

```bash
# Check the service status
systemctl status gitea --no-pager

# Confirm it's listening on port 3000
curl -sf http://localhost:3000 -o /dev/null && echo "Gitea is up"
```

Open the **Gitea** tab in the lab. You should see the Gitea homepage immediately.

::image-box
---
:src: __static__/gitea_ui_v1.png
:alt: Screenshot of the Gitea homepage as seen in the lab browser tab. The Gitea logo — a green teacup with a git branch icon — appears at the top, followed by the headline "Gitea: Git with a cup of tea" and subtitle "A painless, self-hosted Git service". Below are four feature cards: Easy to install, Cross-platform, Lightweight, and Open Source. The lab tab bar at the top shows Lucee (dev), Gitea, ColdFusion (prod), Ollama API, Terminal (dev), Terminal (prod), and Terminal (oll) tabs.
:max-width: 860px
---
_The Gitea tab in your lab — this is what you should see at `http://localhost:3000` after logging in._
::

> 🔑 Default credentials: **username** `labadmin` / **password** `labpassword`

::hint-box
---
:summary: Gitea is not responding — how do I start it?
---
If `systemctl status gitea` shows `inactive` or `failed`, start it manually:

```bash
sudo systemctl start gitea
sudo systemctl status gitea --no-pager
```

Gitea takes about 5 seconds to start. Once the status shows `active (running)`, the web UI at `http://localhost:3000` is ready.

If it fails to start, check the logs:
```bash
sudo journalctl -u gitea -n 30
```
::

::simple-task
---
:tasks: tasks
:name: verify_gitea_running
---
#active
Open the **Gitea** tab — confirm the login page loads at `http://localhost:3000`. Log in with `labadmin` / `labpassword`.

#completed
Gitea is running and accessible. ✓
::

---

## 6. Create a repository and push your app

With Gitea confirmed, create a repository and push your CF application into it.

**Activity — Terminal (dev):** Create the Gitea repository via API and push the initial commit.

```bash
# ── 1. Create the repo via Gitea API ─────────────────────────────────
curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -u labadmin:labpassword \
  -H "Content-Type: application/json" \
  -d '{"name":"cf-app","description":"ColdFusion CI/CD lab","private":false,"auto_init":false}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Repo created:', d.get('full_name','error'))"

# ── 2. Create the app directory and a minimal index.cfm ──────────────
mkdir -p /home/laborant/app/app
[ -f /home/laborant/app/app/index.cfm ] || echo '<cfoutput>ColdFusion CI/CD Lab — OK</cfoutput>' > /home/laborant/app/app/index.cfm

# ── 3. Initialise git and push to Gitea ──────────────────────────────
cd /home/laborant/app
git init -b main
git config user.email "lab@localhost"
git config user.name "Lab Student"
git remote add origin http://labadmin:labpassword@localhost:3000/labadmin/cf-app.git
git add .
git commit -m "initial commit"
git push -u origin main
```

After the push, switch to the **Gitea** tab and open `http://localhost:3000/labadmin/cf-app` — you should see the repository with your file.

::hint-box
---
:summary: Why git init -b main and not just git init?
---
Older versions of git default to `master` as the initial branch name. `git init -b main` explicitly names the branch `main` from the start, matching what Gitea expects and avoiding the "src refspec main does not match any" error on the first `git push -u origin main`.

If your git version doesn't support `-b`, use this instead:
```bash
git init
git checkout -b main
```

Both produce the same result.
::

::hint-box
---
:summary: Why use the Gitea API to create the repo instead of the web UI?
---
Two reasons. First, it's faster — one command versus five clicks. Second, it's scriptable — you can automate repository creation in your own onboarding scripts.

The Gitea API is a full REST API compatible with most GitHub API endpoints. `-u labadmin:labpassword` sends HTTP Basic Auth. The `-d` flag sends the repository settings as JSON. The `python3 -c` at the end pretty-prints the confirmation so you can see the `full_name` without wading through the full JSON response.
::

::simple-task
---
:tasks: tasks
:name: verify_repo_pushed
---
#active
Create the `cf-app` repository in Gitea and push at least one commit to it. Confirm the **Gitea** tab shows the `cf-app` repository with your files.

#completed
Repository pushed to Gitea. ✓
::

---

## 7. Dockerise your ColdFusion application

The Dockerfile is the heart of the pipeline. It tells Docker exactly how to build the environment your application needs — the CF runtime, your code, and the configuration — packaged as a single portable image.

::image-box
---
:src: __static__/docker-build-deploy-v1.png
:alt: Three-column diagram. Left column cf-dev VM shows source files (app/index.cfm plus Dockerfile) flowing down through docker build into three stacked image layers — app code layer in blue, CF runtime layer in green, and OS base layer in purple — tagged cf-app colon a3f82c9. Middle column Local Registry at localhost 5000 shows three image tags: cf-app colon a3f82c9 as latest, cf-app colon b7c14d2 as yesterday, cf-app colon e91fa55 as 3 days ago, with a rollback annotation: rollback equals docker run image colon b7c14d2 — ten seconds no guessing. Right column cf-prod VM shows the running container on port 8500 with a HEALTHCHECK, user traffic routing to healthy container, and a note that every deploy equals a commit SHA.
:max-width: 960px
---
_Three image layers build once, run anywhere — and every image tag corresponds to an exact git commit SHA._
::

**Activity — Terminal (dev):** Create the Dockerfile and push it to Gitea.

```bash
cd /home/laborant/app

tee Dockerfile << 'DOCKEREOF'
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
DOCKEREOF

git add Dockerfile
git commit -m "add Dockerfile"
git push
```

**Activity — Terminal (dev):** Verify Docker is installed, then build the image locally to confirm the Dockerfile is valid before the pipeline runs it:

```bash
# ── 0. Confirm Docker is installed and running ────────────────────────
docker --version
docker info --format "Server Version: {{.ServerVersion}}" 2>/dev/null || echo "Docker daemon not running"

cd /home/laborant/app

# ── 1. Build the image — pulls CF 2025 on first run (~1–2 min) ────────
docker build -t localhost:5000/cf-app:local .

# ── 2. Confirm the image was created ─────────────────────────────────
docker images | grep cf-app
```

> ⏱️ The first `docker build` pulls the `adobecoldfusion/coldfusion2025:latest` base image — about 1–2 minutes on first run. Subsequent builds use the cached layer and take seconds.

::hint-box
---
:summary: docker --version works but docker info fails — what does that mean?
---
`docker --version` only checks the client binary is installed. `docker info` contacts the Docker **daemon** (the background service that actually runs containers). If `docker info` returns an error, the daemon is not running.

Start it:
```bash
sudo systemctl start docker
sudo systemctl status docker --no-pager
```

Then retry `docker info`. Once it shows a `Server Version`, you're ready to build.

If `docker --version` itself fails with `command not found`, Docker is not installed. In this lab Docker is pre-installed on `cf-dev` — if you're seeing this, confirm you are on the correct VM:
```bash
hostname   # should print cf-dev
```
::

::hint-box
---
:summary: What does each line of the Dockerfile do?
---
```dockerfile
FROM adobecoldfusion/coldfusion2025:latest
```
Starts with Adobe's official CF 2025 image as the base. This includes the full CF engine, JVM, and default configuration.

```dockerfile
ENV acceptEULA=YES
ENV password=admin
```
CF 2025's Docker image requires `acceptEULA=YES` to start without an interactive prompt. `password` sets the CF Administrator password. **Change this in production.**

```dockerfile
COPY app/ /opt/coldfusion2025/cfusion/wwwroot/
```
Copies your `.cfm` files into the CF webroot inside the container. The path `/opt/coldfusion2025/cfusion/wwwroot/` is where CF 2025 serves files by default.

```dockerfile
EXPOSE 8500
```
Documents that the container listens on port 8500. This is metadata — you still need `-p 8500:8500` when running `docker run` to actually map the port.

```dockerfile
HEALTHCHECK ...
```
Tells Docker to regularly check if CF is healthy. The `--start-period=60s` gives CF time to fully start before health checks begin.
::

::hint-box
---
:summary: ENV password=admin — is this safe?
---
Not in production. The `password=admin` ENV sets the CF Administrator password and is baked into the image. Anyone who can pull the image can see it.

For production, use a **Docker secret** or pass the password at runtime with `-e password=...` from an environment variable that is never stored in source code. In this lab, `admin` is fine — it's a local-only VM with no external access.
::

::simple-task
---
:tasks: tasks
:name: verify_dockerfile_exists
---
#active
Create `/home/laborant/app/Dockerfile` with `FROM adobecoldfusion/coldfusion2025:latest` and `EXPOSE 8500`, then push it to Gitea. Confirm `docker build -t localhost:5000/cf-app:local .` succeeds.

#completed
Dockerfile found at `/home/laborant/app/Dockerfile`. ✓
::

---

## 8. Create the Gitea Actions workflow

Gitea Actions workflows live in `.gitea/workflows/` and use the same YAML syntax as GitHub Actions. The workflow triggers on every push to `main`, builds the Docker image, pushes it to a local registry, and deploys it to `cf-prod` via SSH.

**Activity — Terminal (dev):** Create the workflow file and push it.

```bash
cd /home/laborant/app
mkdir -p .gitea/workflows

tee .gitea/workflows/deploy.yml << 'WORKFLOWEOF'
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
            "docker pull localhost:5000/cf-app:${{ gitea.sha }} && docker stop cf-app 2>/dev/null || true && docker run -d --name cf-app --rm -p 8500:8500 localhost:5000/cf-app:${{ gitea.sha }} && echo Deploy OK"
WORKFLOWEOF

git add .gitea/
git commit -m "add Gitea Actions workflow"
git push
```

After the push, go to the **Gitea** tab → your repo → **Actions** tab. You should see the workflow running within a few seconds.

::hint-box
---
:summary: What is a job and what is a step? — reading the YAML
---
The workflow YAML has a clear hierarchy. Here's a map of every level:

```
workflow  (the whole file — "Build and Deploy ColdFusion App")
└── on:   (trigger — "push to main")
└── jobs: (one or more named jobs)
    └── build-and-deploy:    ← JOB NAME
        runs-on: ubuntu-latest  ← which runner executes this job
        steps:               ← ordered list of steps inside the job
            - name: Checkout         ← STEP 1
              uses: actions/checkout@v3
            - name: Build image      ← STEP 2
              run: docker build ...
            - name: Push to registry ← STEP 3
              run: docker push ...
            - name: Deploy to cf-prod ← STEP 4
              run: ssh ...
```

**Job** — a named group of steps that all run on the **same runner machine** in sequence. Jobs in the same workflow run in parallel by default; if you want them in order, use `needs:`. This workflow has one job (`build-and-deploy`), so order is not an issue.

**Step** — a single unit of work inside a job. Each step either:
- runs a shell command (`run: docker build ...`), or
- calls a reusable Action (`uses: actions/checkout@v3`).

Steps within a job always run **in order**, top to bottom. If a step fails (non-zero exit code), all subsequent steps are skipped and the job is marked failed.

**Why does this matter?** If your `Build image` step fails, the `Push to registry` and `Deploy` steps never run — broken code can never reach production. That ordering guarantee is the CI in CI/CD.
::

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

Everything else — `on:`, `jobs:`, `steps:`, `uses:`, `run:` — is identical syntax. Skills you build here transfer directly to GitHub Actions.
::

::hint-box
---
:summary: What is gitea.sha and why tag the image with it?
---
`gitea.sha` is the full git commit hash of the push that triggered the workflow — a 40-character string like `a3f82c9b14...`. Using it as the Docker image tag gives you:

1. **Traceability** — you can always answer "what exactly is running in production?" by checking the image tag
2. **Rollback** — to go back one release, run `docker run localhost:5000/cf-app:<previous-sha>`
3. **Reproducibility** — the same SHA always refers to the same exact code and the same image

Never use `latest` as your only tag in a pipeline. `latest` is overwritten on every build; you lose the ability to reproduce any previous state.
::

::hint-box
---
:summary: The SSH deploy command is one long line — why?
---
The SSH deploy step uses a single command string passed to the remote shell via `ssh ... "command"`. Shell heredocs and multi-line `run:` blocks work fine inside the YAML, but the string passed over SSH must be a single logical command (you can join lines with `&&`).

Breaking it down:
- `docker pull localhost:5000/cf-app:<sha>` — download the new image onto cf-prod
- `docker stop cf-app 2>/dev/null || true` — stop the old container if it's running (ignore error if it doesn't exist)
- `docker run -d --name cf-app --rm -p 8500:8500 ...` — start the new container in the background
- `echo Deploy OK` — final confirmation printed to the pipeline log

In production you'd replace this with a zero-downtime deployment tool (Watchtower, Traefik, Kubernetes), but this pattern is clear and works correctly for a lab.
::

::simple-task
---
:tasks: tasks
:name: verify_github_actions_workflow
---
#active
Create `.gitea/workflows/deploy.yml` with an `on: push` trigger and push it to Gitea. Confirm the **Gitea → Actions** tab shows the workflow run.

#completed
Gitea Actions workflow file found. ✓
::

---

## 9. The developer workflow — what happens after every push

Once the pipeline is in place, your daily workflow becomes this:

```
1. Write code on cf-dev
2. git add .  &&  git commit -m "fix: resolve ticket query timeout"
3. git push origin main
      ↓
4. Gitea detects the push — triggers the Act Runner automatically
      ↓
5. Act Runner executes deploy.yml step by step:
   a. Checkout — fresh copy of your code
   b. docker build — image tagged with gitea.sha
   c. docker push — image stored in local registry
   d. SSH to cf-prod — old container stopped, new container started
      ↓
6. Pipeline shows ✅ green in Gitea → Actions
7. Your app is live on cf-prod with the new code
```

| Benefit | Traditional FTP | CI/CD pipeline |
|---|---|---|
| Repeatability | ❌ Manual, varies per person | ✅ Same steps every time |
| Audit trail | ❌ Who uploaded what, when? | ✅ Every deploy linked to a commit |
| Rollback | ❌ Restore from backup manually | ✅ `docker run image:previous-sha` |
| Testing gate | ❌ "Looks good on my machine" | ✅ Broken tests block bad deploys |
| Downtime | ❌ CF down during file copy | ✅ Container swap — near zero-downtime |

::hint-box
---
:summary: How do I add automated tests to the pipeline?
---
Between the "Build image" and "Push to registry" steps, add a test step that runs inside the container:

```yaml
- name: Run tests
  run: |
    docker run --rm localhost:5000/cf-app:${{ gitea.sha }} \
      curl -sf http://localhost:8500/tests/index.cfm?reporter=junit \
      -o test-results.xml
    # Parse test-results.xml and fail if tests failed
```

For ColdFusion, TestBox is the standard testing framework. The `?reporter=junit` query string outputs JUnit XML that most CI systems can parse and display as a test report.

Alternatively, run a smoke test after deployment:
```yaml
- name: Smoke test
  run: |
    sleep 10
    curl -sf http://cf-prod:8500/index.cfm || exit 1
```

Start with a smoke test, then graduate to full TestBox runs as your test suite grows.
::

---

## Key concepts reference

| Term | Meaning |
|---|---|
| **DevOps** | Culture + practices + tools that unite Dev and Ops under shared ownership |
| **CI** | Continuous Integration — automated build and test on every code push |
| **CD** | Continuous Delivery / Deployment — automated packaging and deploy |
| **Workflow** | A YAML file in `.gitea/workflows/` that defines when and what to run |
| **Job** | A set of steps that runs on the same runner machine |
| **Step** | A single command or reusable Action within a job |
| **Runner** | The VM that executes your workflow (Act Runner on `cf-dev`) |
| **gitea.sha** | The git commit hash used to tag Docker images for traceability |
| **Local registry** | Docker image store at `localhost:5000` — no internet needed |
| **HEALTHCHECK** | Docker instruction that marks a container healthy/unhealthy |
| **Rollback** | `docker run localhost:5000/cf-app:<previous-sha>` — one command |
| **IaC** | Infrastructure as Code — the Dockerfile and workflow YAML are your environment |

---

## Now Prove It

Apply what you've learned in the challenge below. You'll wire together a Dockerfile and a Gitea Actions workflow for a ColdFusion microservice.

::card
---
:challenge: challenges.cicd-pipelines-9fa2ce74
---
::

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Dockerfile exists, repository pushed, and workflow file created — hit **Check** to complete the lesson.

#completed
DevOps lesson complete. On to the next one! ✓
::
