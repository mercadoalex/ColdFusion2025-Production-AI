---
kind: unit

title: Cloud Deployment with Docker and AWS

name: cloud-deployment-docker-aws-unit-1
---

## From single-server to cloud

Traditional ColdFusion deployments run on a single, manually configured server. Cloud deployment means packaging your app and its dependencies as an immutable image, then running that image on any cloud provider. Docker is the packaging format; AWS is one deployment target.

::image-box
---
:src: __static__/docker-compose-cf-architecture-v1.png
:alt: Docker Compose architecture diagram showing three containers — cf-app (ColdFusion 2025, port 8500), db (MySQL 8, port 3306), and nginx (reverse proxy, port 80) — connected on a shared docker bridge network labelled app-network, with the developer laptop on the left connecting to nginx
:max-width: 900px
---
_A Docker Compose multi-container stack: ColdFusion + MySQL + Nginx on one host._
::

| Concept | Traditional | Docker |
|---|---|---|
| Dependency tracking | "Works on my machine" | Image contains exact versions |
| Environment parity | Dev ≠ Prod | Identical image everywhere |
| Scaling | Buy bigger server | Add more containers |
| Rollback | Restore backup | `docker run image:previous-tag` |

---

## 1. Docker Compose — multi-container ColdFusion stack

`docker-compose.yml` describes your entire application stack as code. A single `docker compose up` starts ColdFusion, a database, and any other services your app needs.

**Activity:** Create your compose file:

```bash
mkdir -p /home/laborant/cf-cloud
cd /home/laborant/cf-cloud
```

Create `/home/laborant/cf-cloud/docker-compose.yml`:

```bash
tee /home/laborant/cf-cloud/docker-compose.yml << 'EOF'
version: "3.9"

services:

  # ── ColdFusion 2025 application ────────────────────────────────────
  cf-app:
    image: adobecoldfusion/coldfusion2025:latest
    ports:
      - "8500:8500"
    environment:
      acceptEULA: "YES"
      password: "admin"
      datasource_name: training_db
      datasource_driver: mysql
      datasource_host: db
      datasource_port: "3306"
      datasource_database: training
      datasource_username: cfuser
      datasource_password: cfpass
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./app:/opt/coldfusion2025/cfusion/wwwroot
    networks:
      - app-network

  # ── MySQL 8 database ───────────────────────────────────────────────
  db:
    image: mysql:8
    environment:
      MYSQL_DATABASE: training
      MYSQL_USER: cfuser
      MYSQL_PASSWORD: cfpass
      MYSQL_ROOT_PASSWORD: rootpass
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

volumes:
  db_data:

networks:
  app-network:
    driver: bridge
EOF
```

::hint-box
---
:summary: What does depends_on with condition: service_healthy do?
---
`depends_on` with `condition: service_healthy` tells Docker Compose not to start `cf-app` until the `db` service passes its health check (in this case, `mysqladmin ping`). Without this, ColdFusion would start before MySQL is ready and fail to create its datasource connection pool.

Always add a `healthcheck` to database services in Compose files.
::

::simple-task
---
:tasks: tasks
:name: verify_compose_file
---
#active
Create a `docker-compose.yml` file under `/home/laborant/` that references ColdFusion on port 8500.

#completed
docker-compose.yml found and references ColdFusion. ✓
::

---

## 2. Environment variables in Application.cfc

In cloud deployments, configuration is injected via environment variables — never hardcoded. ColdFusion reads environment variables through Java's `System.getenv()`.

::image-box
---
:src: __static__/cf-env-variables-v1.png
:alt: Application.cfc open in VS Code showing this.datasource configured from environment variables using createObject("java","java.lang.System").getenv() calls for DB_HOST, DB_NAME, DB_USER, and DB_PASS — with a fallback to localhost for local development
:max-width: 860px
---
_Reading environment variables in Application.cfc — the twelve-factor app pattern for ColdFusion._
::

```cfml
// Application.cfc — cloud-ready configuration
component {
  this.name = "CFCloudApp";

  // Helper function for reading env vars with a fallback
  private string function env(required string key, string defaultVal="") {
    val = createObject("java", "java.lang.System").getenv(arguments.key);
    return isNull(val) ? arguments.defaultVal : val;
  }

  this.datasource = {
    driver:   "MySQL",
    host:     env("DB_HOST", "localhost"),
    port:     val(env("DB_PORT", "3306")),
    database: env("DB_NAME", "training"),
    username: env("DB_USER", "cfuser"),
    password: env("DB_PASS", "cfpass")
  };
}
```

**Activity:** Create a health check endpoint that cloud load balancers (AWS ELB, etc.) can use:

```bash
mkdir -p /home/laborant/cf-cloud/app

sudo tee /home/laborant/cf-cloud/app/health.cfm << 'EOF'
<cfscript>
  cfheader(name="Content-Type", value="application/json");
  try {
    // Quick DB connectivity check
    queryExecute("SELECT 1", {}, {datasource: application.datasource ?: "training_db"});
    cfheader(statuscode=200, statustext="OK");
    writeOutput(serializeJSON({ "status": "ok", "ts": now() }));
  } catch (any e) {
    cfheader(statuscode=503, statustext="Service Unavailable");
    writeOutput(serializeJSON({ "status": "degraded", "error": e.message }));
  }
</cfscript>
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_compose_has_cf
---
#active
Ensure the `docker-compose.yml` references a ColdFusion image or port 8500.

#completed
docker-compose.yml references ColdFusion. ✓
::

---

## 3. Deploying to AWS Elastic Beanstalk

Elastic Beanstalk (EB) is AWS's managed platform-as-a-service for Docker applications. You push a `docker-compose.yml` (or a `Dockerrun.aws.json`) and EB handles provisioning, scaling, and load balancing.

**The deployment flow:**

```
1. Push image to Amazon ECR (or GHCR)
   docker tag cf-app:latest <account>.dkr.ecr.<region>.amazonaws.com/cf-app:latest
   docker push <account>.dkr.ecr.<region>.amazonaws.com/cf-app:latest

2. Create EB application
   eb init cf-helpdesk --platform docker --region us-east-1

3. Deploy
   eb deploy

4. Open in browser
   eb open
```

::hint-box
---
:summary: AWS Free Tier is enough for testing
---
AWS Free Tier includes 750 hours/month of `t2.micro` EC2 — enough to run one Elastic Beanstalk environment continuously. Create a free account at https://aws.amazon.com/free/ to try this in practice.

For the purposes of this lesson, configuring the Compose file and health endpoint is the hands-on goal. The `eb deploy` commands are shown for reference — you're not expected to have an AWS account in the lab.
::

---

## 4. Key production considerations

| Concern | Solution |
|---|---|
| **Secrets management** | AWS Secrets Manager or Parameter Store — never in `docker-compose.yml` |
| **Session persistence** | CF sessions need shared Redis/DB backing across instances |
| **Log aggregation** | Mount CF logs to CloudWatch or use a log forwarder sidecar |
| **SSL termination** | At the ALB level — CF serves plain HTTP behind the load balancer |
| **Datasource connection pool** | Tune `maxConnections` for RDS — start with 10, monitor |

---

## Key concepts reference

| Concept | Tool |
|---|---|
| Multi-container app | `docker-compose.yml` with `services:` |
| Service startup order | `depends_on: condition: service_healthy` + `healthcheck:` |
| Environment config | `System.getenv()` in Application.cfc |
| Health check endpoint | `health.cfm` returning 200/503 |
| AWS deployment | Elastic Beanstalk + ECR |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Docker Compose file is ready — hit **Check** to complete the lesson.

#completed
Cloud deployment lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"Learning is not the product of teaching. Learning is the product of the activity of learners."*
> — John Dewey

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.cloud-deployment-fe9fc951
---
::
