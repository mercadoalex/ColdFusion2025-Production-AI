---
kind: challenge

title: 'Docker Compose Stack for ColdFusion + MySQL'

description: |
  Write a docker-compose.yml that runs ColdFusion 2025 and MySQL 8 together,
  with a health check and an Application.cfc that reads DB credentials from
  environment variables.

categories:
  - programming

tagz:
  - coldfusion
  - docker
  - docker-compose

difficulty: medium

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  compose_file_valid:
    machine: cf-dev
    user: laborant
    run: |
      FILE=$(find /home/laborant/cloud-challenge -name "docker-compose.yml" \
              -o -name "docker-compose.yaml" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No docker-compose.yml found under /home/laborant/cloud-challenge/"
        exit 1
      fi
      if ! grep -q "mysql\|MySQL" "${FILE}"; then
        echo "Compose file does not include a MySQL service"
        exit 1
      fi
      echo "docker-compose.yml with MySQL found ✓"

  healthcheck_present:
    machine: cf-dev
    user: laborant
    needs:
      - compose_file_valid
    run: |
      FILE=$(find /home/laborant/cloud-challenge -name "docker-compose.yml" \
              -o -name "docker-compose.yaml" 2>/dev/null | head -1)
      if ! grep -q "healthcheck" "${FILE}"; then
        echo "No healthcheck defined in docker-compose.yml"
        exit 1
      fi
      echo "healthcheck found in docker-compose.yml ✓"

  env_vars_in_app_cfc:
    machine: cf-dev
    user: laborant
    needs:
      - healthcheck_present
    run: |
      FILE=$(find /home/laborant/cloud-challenge -name "Application.cfc" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No Application.cfc found in cloud-challenge project"
        exit 1
      fi
      if ! grep -qi "getenv\|System\|env(" "${FILE}"; then
        echo "Application.cfc does not read environment variables"
        exit 1
      fi
      echo "Application.cfc reads environment variables ✓"
---

## Docker Compose Stack for ColdFusion + MySQL

Create a Docker Compose project at `/home/laborant/cloud-challenge/`.

### Requirements

1. **`docker-compose.yml`** with:
   - A `cf-app` service using `adobecoldfusion/coldfusion2025:latest` on port 8500
   - A `db` service using `mysql:8`
   - A `healthcheck` on the MySQL service
   - `depends_on` with `condition: service_healthy`

2. **`app/Application.cfc`** that reads database credentials from environment variables using `System.getenv()`.

3. **Optional bonus:** A `health.cfm` endpoint that verifies DB connectivity and returns 200/503.

::simple-task
---
:tasks: tasks
:name: compose_file_valid
---
#active
Create `docker-compose.yml` with a ColdFusion service and a MySQL service.

#completed
docker-compose.yml with MySQL found. ✓
::

::simple-task
---
:tasks: tasks
:name: healthcheck_present
---
#active
Add a `healthcheck` to your docker-compose.yml.

#completed
healthcheck found. ✓
::

::simple-task
---
:tasks: tasks
:name: env_vars_in_app_cfc
---
#active
Create `app/Application.cfc` that reads DB config from environment variables.

#completed
Application.cfc reads environment variables. ✓
::
