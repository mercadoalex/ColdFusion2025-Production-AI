---
kind: lesson

title: ColdFusion in Cloud Environments
description: |
  Deploy ColdFusion 2025 applications to cloud platforms.
  Understand architectural considerations, environment configuration,
  scalability, high availability, and integration with cloud services.

name: coldfusion-cloud-environments
slug: coldfusion-cloud-environments

createdAt: "2026-09-03"
updatedAt: "2026-09-03"

categories:
- programming

tagz:
- coldfusion
- docker
- aws

playground:
  name: cf-training-advanced-7442b9e0

tasks:
  verify_docker_running:
    machine: cf-dev
    user: laborant
    run: |
      if ! docker info > /dev/null 2>&1; then
        echo "Docker is not running"
        exit 1
      fi
      echo "Docker is running"

  verify_cf_container:
    machine: cf-dev
    user: laborant
    needs:
      - verify_docker_running
    run: |
      if ! docker ps 2>/dev/null | grep -q "coldfusion\|cfml\|lucee"; then
        echo "No ColdFusion/Lucee container is running"
        exit 1
      fi
      echo "ColdFusion/Lucee container is running"

  verify_env_config:
    machine: cf-dev
    user: laborant
    needs:
      - verify_cf_container
    run: |
      FILE=$(find /home/laborant /opt/coldfusion2025/cfusion/wwwroot -name ".env" -o -name "docker-compose.yml" 2>/dev/null | head -1)
      if [ -z "${FILE}" ]; then
        echo "No .env or docker-compose.yml found"
        exit 1
      fi
      echo "Environment configuration found at ${FILE}"
---

## Docker Compose for ColdFusion + MySQL

```yaml
# docker-compose.yml
version: "3.9"

services:
  cf:
    image: adobecoldfusion/coldfusion2025:latest
    ports:
      - "8500:8500"
    environment:
      - acceptEULA=YES
      - password=admin123
      - datasource_name=training_db
      - datasource_driver=mysql
      - datasource_host=db
      - datasource_port=3306
      - datasource_database=training
      - datasource_username=cfuser
      - datasource_password=cfpass
    depends_on:
      - db

  db:
    image: mysql:8
    environment:
      - MYSQL_DATABASE=training
      - MYSQL_USER=cfuser
      - MYSQL_PASSWORD=cfpass
      - MYSQL_ROOT_PASSWORD=rootpass
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
```

## Environment variables in Application.cfc

```cfml
component {
  this.name = "MyApp";
  this.datasource = {
    driver:   "MySQL",
    host:     createObject("java","java.lang.System").getenv("DB_HOST"),
    port:     createObject("java","java.lang.System").getenv("DB_PORT"),
    database: createObject("java","java.lang.System").getenv("DB_NAME"),
    username: createObject("java","java.lang.System").getenv("DB_USER"),
    password: createObject("java","java.lang.System").getenv("DB_PASS")
  };
}
```

## Health check for load balancer

```cfml
<!--- health.cfm — used by AWS ELB / ALB target group --->
<cfscript>
  try {
    queryExecute("SELECT 1", {}, {datasource:"training_db"});
    cfheader(statuscode=200, statustext="OK");
    writeOutput('{"status":"ok"}');
  } catch(any e) {
    cfheader(statuscode=503, statustext="Service Unavailable");
    writeOutput('{"status":"degraded"}');
  }
</cfscript>
```

