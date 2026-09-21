---
kind: lesson

title: DevOps for ColdFusion
description: |
  Understand DevOps culture and practices, then apply them to ColdFusion.
  Build CI/CD pipelines with GitHub Actions and Docker, containerise CF apps,
  and automate deployments to production — replacing manual FTP workflows forever.

name: cicd-pipelines-coldfusion
slug: cicd-pipelines-coldfusion

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming
- ci-cd

tagz:
- coldfusion
- devops
- github-actions
- docker

playground:
  name: cf-training-devops-3039c6bb

challenges:
  cicd-pipelines-9fa2ce74: {}

tasks:
  verify_gitea_running:
    machine: cf-dev
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
      if [ "${STATUS}" != "200" ]; then
        echo "Gitea is not responding at http://localhost:3000 (HTTP ${STATUS})"
        exit 1
      fi
      echo "Gitea is running ✓"
    hintcheck: |
      echo "Gitea starts automatically. If not ready yet, wait 30 s, then:"
      echo "  curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000"

  verify_repo_pushed:
    machine: cf-dev
    user: laborant
    needs:
      - verify_gitea_running
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -u labadmin:labpassword \
        http://localhost:3000/api/v1/repos/labadmin/cf-app)
      if [ "${STATUS}" != "200" ]; then
        echo "Repository labadmin/cf-app not found in Gitea (HTTP ${STATUS})"
        exit 1
      fi
      echo "Repository cf-app exists in Gitea ✓"
    hintcheck: |
      echo "Create and push the repo with: cd ~/app && git remote add origin ... && git push"
      echo "Then verify: curl -u labadmin:labpassword http://localhost:3000/api/v1/repos/labadmin/cf-app"

  verify_dockerfile_exists:
    machine: cf-dev
    user: laborant
    needs:
      - verify_repo_pushed
    run: |
      if [ ! -f "/home/laborant/app/Dockerfile" ]; then
        echo "Dockerfile not found at /home/laborant/app/Dockerfile"
        exit 1
      fi
      echo "Dockerfile found ✓"
    hintcheck: |
      echo "Create ~/app/Dockerfile — follow the Activity in the Containerisation section."

  verify_github_actions_workflow:
    machine: cf-dev
    user: laborant
    needs:
      - verify_dockerfile_exists
    run: |
      FILE=$(find /home/laborant/app -path "*/.gitea/workflows/*.yml" -o -path "*/.gitea/workflows/*.yaml" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No Gitea Actions workflow file found under .gitea/workflows/"
        exit 1
      fi
      echo "Gitea Actions workflow found at ${FILE} ✓"
    hintcheck: |
      echo "Create .gitea/workflows/deploy.yml — follow the CI/CD Pipeline Activity."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_github_actions_workflow
    run: |
      echo "DevOps lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
