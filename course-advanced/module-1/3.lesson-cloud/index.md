---
kind: lesson

title: Cloud Deployment with Docker and AWS
description: |
  Deploy ColdFusion applications to cloud environments. Build a Docker Compose
  multi-container stack, push images to a registry, and deploy to AWS using
  Elastic Beanstalk or EC2.

name: cloud-deployment-docker-aws
slug: cloud-deployment-docker-aws

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming
- ci-cd

tagz:
- coldfusion
- docker
- aws

playground:
  name: cf-training-devops-3039c6bb

challenges:
  cloud-deployment-fe9fc951: {}

tasks:
  verify_compose_file:
    machine: cf-dev
    user: laborant
    run: |
      FILE=$(find /home/laborant -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No docker-compose.yml found under /home/laborant"
        exit 1
      fi
      echo "docker-compose.yml found at ${FILE} ✓"
    hintcheck: |
      echo "Create ~/docker-compose.yml — follow the Activity in the Docker Compose section."

  verify_compose_has_cf:
    machine: cf-dev
    user: laborant
    needs:
      - verify_compose_file
    run: |
      FILE=$(find /home/laborant -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -1)
      if ! grep -qi "coldfusion\|cf-server\|8500" "${FILE}" 2>/dev/null; then
        echo "docker-compose.yml does not reference ColdFusion"
        exit 1
      fi
      echo "docker-compose.yml references ColdFusion ✓"
    hintcheck: |
      echo "Make sure docker-compose.yml has a 'coldfusion' service or port 8500 mapped."

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_compose_has_cf
    run: |
      echo "Cloud deployment lesson complete ✓"
    hintcheck: |
      echo "All previous tasks must be green before this turns green."
---
