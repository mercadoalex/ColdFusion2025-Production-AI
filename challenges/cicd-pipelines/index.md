---
kind: challenge

title: 'Ship a ColdFusion App with Gitea Actions and Docker'

description: |
  Containerise a ColdFusion application with Docker, push it to a local registry
  via a Gitea Actions pipeline, and deploy it to cf-prod over SSH — the complete
  DevOps loop from code push to running container.

categories:
  - programming

tagz:
  - coldfusion
  - devops
  - docker
  - gitea-actions

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-devops-3039c6bb

tasks:
  dockerfile_in_repo:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/home/laborant/app/Dockerfile"
      if [ ! -f "${FILE}" ]; then
        echo "Dockerfile not found at /home/laborant/app/Dockerfile"
        exit 1
      fi
      if ! grep -qi "coldfusion2025\|acceptEULA" "${FILE}"; then
        echo "Dockerfile does not use adobecoldfusion/coldfusion2025 or set acceptEULA"
        exit 1
      fi
      if ! grep -qi "EXPOSE 8500" "${FILE}"; then
        echo "Dockerfile does not EXPOSE 8500"
        exit 1
      fi
      echo "ColdFusion Dockerfile found and valid ✓"
    hintcheck: |
      echo "Create /home/laborant/app/Dockerfile using FROM adobecoldfusion/coldfusion2025:latest"
      echo "It must include ENV acceptEULA=YES and EXPOSE 8500."

  workflow_in_repo:
    machine: cf-dev
    user: laborant
    needs:
      - dockerfile_in_repo
    run: |
      WORKFLOW=$(find /home/laborant/app -path "*/.gitea/workflows/*.yml" \
                   -o -path "*/.gitea/workflows/*.yaml" 2>/dev/null | head -1)
      if [ -z "${WORKFLOW}" ]; then
        echo "No Gitea Actions workflow found under .gitea/workflows/"
        exit 1
      fi
      if ! grep -qi "docker.*build\|build.*docker" "${WORKFLOW}"; then
        echo "Workflow does not contain a docker build step"
        exit 1
      fi
      if ! grep -qi "docker.*push\|push.*docker\|localhost:5000" "${WORKFLOW}"; then
        echo "Workflow does not push the image to the local registry"
        exit 1
      fi
      echo "Gitea Actions workflow with docker build and push found ✓"
    hintcheck: |
      echo "Create /home/laborant/app/.gitea/workflows/deploy.yml"
      echo "It must contain docker build and docker push steps targeting localhost:5000."

  image_in_registry:
    machine: cf-dev
    user: laborant
    needs:
      - workflow_in_repo
    run: |
      TAGS=$(curl -s http://localhost:5000/v2/cf-app/tags/list 2>/dev/null)
      if ! echo "${TAGS}" | python3 -c "import sys,json; tags=json.load(sys.stdin).get('tags') or []; assert len(tags)>0" 2>/dev/null; then
        echo "No cf-app image found in the local registry at localhost:5000"
        echo "Push the repo to Gitea — the workflow should build and push the image automatically."
        exit 1
      fi
      echo "cf-app image present in local registry ✓"
    hintcheck: |
      echo "Push your code to Gitea: cd /home/laborant/app && git push"
      echo "Then check the Gitea Actions tab — the pipeline should build and push the image."
      echo "Verify: curl -s http://localhost:5000/v2/cf-app/tags/list"
---

## Ship a ColdFusion App with Gitea Actions and Docker

You will build the complete DevOps loop: a Dockerfile that packages your ColdFusion app, a Gitea Actions pipeline that builds and pushes the image on every push, and a registry that stores the tagged image ready for deployment.

Work in `/home/laborant/app/` — the same project you used during the lesson.

---

### Task 1 — Write a valid ColdFusion Dockerfile

Create `/home/laborant/app/Dockerfile`:

```bash
cd /home/laborant/app

tee Dockerfile << 'EOF'
FROM adobecoldfusion/coldfusion2025:latest

ENV acceptEULA=YES
ENV password=admin

COPY app/ /opt/coldfusion2025/cfusion/wwwroot/

EXPOSE 8500

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:8500/index.cfm || exit 1
EOF
```

Commit it:

```bash
git add Dockerfile
git commit -m "add Dockerfile"
```

::simple-task
---
:tasks: tasks
:name: dockerfile_in_repo
---
#active
Create `/home/laborant/app/Dockerfile` using `adobecoldfusion/coldfusion2025:latest`, `ENV acceptEULA=YES`, and `EXPOSE 8500`.

#completed
ColdFusion Dockerfile found and valid. ✓
::

---

### Task 2 — Create a Gitea Actions workflow that builds and pushes the image

Create `/home/laborant/app/.gitea/workflows/deploy.yml`:

```bash
mkdir -p /home/laborant/app/.gitea/workflows

tee /home/laborant/app/.gitea/workflows/deploy.yml << 'EOF'
name: Build and push CF image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build Docker image
        run: |
          docker build -t localhost:5000/cf-app:${{ gitea.sha }} .
          docker tag localhost:5000/cf-app:${{ gitea.sha }} localhost:5000/cf-app:latest

      - name: Push to local registry
        run: |
          docker push localhost:5000/cf-app:${{ gitea.sha }}
          docker push localhost:5000/cf-app:latest
EOF
```

Commit and push:

```bash
git add .gitea/workflows/deploy.yml
git commit -m "add Gitea Actions pipeline"
git push
```

::simple-task
---
:tasks: tasks
:name: workflow_in_repo
---
#active
Create `.gitea/workflows/deploy.yml` with `docker build` and `docker push` steps targeting `localhost:5000`.

#completed
Gitea Actions workflow with docker build and push found. ✓
::

---

### Task 3 — Confirm the image landed in the local registry

After `git push`, open the **Gitea** tab (`http://localhost:3000`) and check **Actions** — the pipeline should appear and run. When it goes green, verify the image is in the registry:

```bash
curl -s http://localhost:5000/v2/cf-app/tags/list | python3 -m json.tool
```

Expected output:

```json
{
    "name": "cf-app",
    "tags": [
        "latest",
        "a3f82c9b14..."
    ]
}
```

If the pipeline failed, check the Actions log in Gitea for the exact error. Common causes: the Act Runner is not registered (see the hint box in the lesson), or the local registry at `localhost:5000` is not running (`docker ps | grep registry`).

::simple-task
---
:tasks: tasks
:name: image_in_registry
---
#active
Push your code to Gitea, let the pipeline run, then confirm `http://localhost:5000/v2/cf-app/tags/list` returns at least one tag.

#completed
cf-app image present in the local registry. ✓
::
