---
kind: lesson

title: CI/CD Pipelines for ColdFusion
description: |
  Build automated CI/CD pipelines for ColdFusion applications using GitHub Actions
  and Docker. Package, test, and deploy CF apps automatically on every push.

name: cicd-pipelines-coldfusion
slug: cicd-pipelines-coldfusion

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming
- ci-cd

tagz:
- coldfusion
- github-actions
- docker
- ci-cd

playground:
  name: cf-training-advanced-7442b9e0

challenges:
  cicd-pipelines-9fa2ce74: {}

tasks:
  verify_dockerfile_exists:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -f "/home/laborant/app/Dockerfile" ]; then
        echo "Dockerfile not found at /home/laborant/app/Dockerfile"
        exit 1
      fi
      echo "Dockerfile found ✓"

  verify_github_actions_workflow:
    machine: cf-dev
    user: laborant
    needs:
      - verify_dockerfile_exists
    run: |
      FILE=$(find /home/laborant/app -path "*/.github/workflows/*.yml" -o -path "*/.github/workflows/*.yaml" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No GitHub Actions workflow file found under .github/workflows/"
        exit 1
      fi
      echo "GitHub Actions workflow found at ${FILE} ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_github_actions_workflow
    run: |
      echo "CI/CD lesson complete ✓"
---
