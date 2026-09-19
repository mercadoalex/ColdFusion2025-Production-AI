---
kind: challenge

title: 'Build a CI/CD Pipeline for a ColdFusion Microservice'

description: |
  Create a Dockerfile that packages a ColdFusion microservice and a GitHub Actions
  workflow that builds and pushes the image automatically on every push to main.

categories:
  - programming

tagz:
  - coldfusion
  - github-actions
  - docker

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  create_dockerfile:
    machine: cf-dev
    user: laborant
    run: |
      FILE="/home/laborant/microservice/Dockerfile"
      if [ ! -f "${FILE}" ]; then
        echo "Dockerfile not found at ${FILE}"
        exit 1
      fi
      if ! grep -qi "FROM\|EXPOSE 8500\|acceptEULA" "${FILE}"; then
        echo "Dockerfile does not look like a ColdFusion Dockerfile"
        exit 1
      fi
      echo "ColdFusion Dockerfile found ✓"

  create_workflow:
    machine: cf-dev
    user: laborant
    needs:
      - create_dockerfile
    run: |
      WORKFLOW=$(find /home/laborant/microservice -path "*/.github/workflows/*.yml" \
                   -o -path "*/.github/workflows/*.yaml" 2>/dev/null | head -1)
      if [ -z "${WORKFLOW}" ]; then
        echo "No GitHub Actions workflow found under .github/workflows/"
        exit 1
      fi
      if ! grep -qi "docker\|push\|build" "${WORKFLOW}"; then
        echo "Workflow does not contain docker build/push steps"
        exit 1
      fi
      echo "GitHub Actions workflow with docker steps found ✓"

  verify_health_endpoint:
    machine: cf-dev
    user: laborant
    needs:
      - create_workflow
    run: |
      APP_DIR="/home/laborant/microservice/app"
      if [ ! -d "${APP_DIR}" ]; then
        echo "No app/ directory found in microservice project"
        exit 1
      fi
      HEALTH=$(find "${APP_DIR}" -name "health.cfm" 2>/dev/null | head -1)
      if [ -z "${HEALTH}" ]; then
        echo "health.cfm not found — add a health check endpoint"
        exit 1
      fi
      echo "health.cfm found ✓"
---

## Build a CI/CD Pipeline for a ColdFusion Microservice

Your task is to create a standalone ColdFusion microservice project at `/home/laborant/microservice/` that is ready for automated CI/CD.

### Requirements

1. Create a `Dockerfile` at `/home/laborant/microservice/Dockerfile` that:
   - Uses `adobecoldfusion/coldfusion2025:latest` as the base image
   - Sets `acceptEULA=YES`
   - Copies an `app/` directory into the CF webroot
   - Exposes port `8500`

2. Create a GitHub Actions workflow at `/home/laborant/microservice/.github/workflows/deploy.yml` that:
   - Triggers on push to `main`
   - Contains steps to build and push a Docker image

3. Create a health check endpoint at `/home/laborant/microservice/app/health.cfm`

### Hints

- Use `mkdir -p` to create all the required directories at once
- The workflow file must end in `.yml` or `.yaml`
- The Dockerfile must contain `FROM`, `acceptEULA`, and `EXPOSE 8500`

::simple-task
---
:tasks: tasks
:name: create_dockerfile
---
#active
Create `/home/laborant/microservice/Dockerfile` with a ColdFusion base image and port 8500 exposed.

#completed
ColdFusion Dockerfile found. ✓
::

::simple-task
---
:tasks: tasks
:name: create_workflow
---
#active
Create a GitHub Actions workflow under `.github/workflows/` with Docker build and push steps.

#completed
GitHub Actions workflow found. ✓
::

::simple-task
---
:tasks: tasks
:name: verify_health_endpoint
---
#active
Create `app/health.cfm` inside your microservice project.

#completed
health.cfm found. ✓
::
