---
kind: unit

title: Cloud Deployment with Docker and AWS

name: cloud-deployment-docker-aws-unit-1
---

## From single-server to cloud

Traditional ColdFusion deployments run on a single, manually configured server. Cloud deployment means packaging your app and its dependencies as an immutable image, then running that image on any cloud provider. Docker is the packaging format; AWS is one deployment target.

::image-box
---
:src: __static__/docker-compose-architecture-v1.png
:alt: Docker Compose architecture diagram showing two containers — cf-app (ColdFusion 2025, port 8500) and db (MySQL 8, port 3306) — connected on a shared docker bridge network labelled app-network, with the developer laptop on the left connecting directly to cf-app
:max-width: 900px
---
_A Docker Compose multi-container stack: ColdFusion + MySQL on one host._
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
:summary: 'What does depends_on with condition: service_healthy do?'
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

::hint-box
---
:summary: The Twelve-Factor App — the methodology behind this pattern
---
The **Twelve-Factor App** is a methodology for building software-as-a-service applications, published by Adam Wiggins (Heroku) in 2012. It describes twelve practices that make an application portable, scalable, and maintainable in modern cloud environments. The full methodology is at [12factor.net](https://12factor.net).

**The twelve factors:**

| # | Factor | What it means in practice |
|---|---|---|
| I | **Codebase** | One codebase tracked in git, many deploys |
| II | **Dependencies** | Declare all dependencies explicitly (`box.json`, `pom.xml`) — never rely on system-wide packages |
| III | **Config** | Store config in environment variables — never in code |
| IV | **Backing services** | Treat databases, queues, and caches as attached resources, swappable via config |
| V | **Build/Release/Run** | Strictly separate build stage from release from runtime |
| VI | **Processes** | Execute the app as stateless processes — no local sticky sessions |
| VII | **Port binding** | Export services via port binding — `8500`, `80`, `11434` |
| VIII | **Concurrency** | Scale out via the process model, not by making processes bigger |
| IX | **Disposability** | Fast startup, graceful shutdown — containers should be replaceable in seconds |
| X | **Dev/Prod parity** | Keep development, staging, and production as similar as possible |
| XI | **Logs** | Treat logs as event streams — write to stdout, let the platform aggregate |
| XII | **Admin processes** | Run admin tasks (migrations, seeds) as one-off processes in the same environment |

**Which factors the `docker-compose.yml` + `Application.cfc` pattern above covers:**

- **III (Config)** — `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` come from environment variables, not hardcoded strings
- **IV (Backing services)** — the `db` service is an attached resource; swapping MySQL for RDS means changing one env var
- **VII (Port binding)** — ColdFusion binds to port 8500, Nginx to 80, MySQL to 3306 — each service owns its port
- **X (Dev/Prod parity)** — the same `docker-compose.yml` runs locally and in production; no "works on my machine" drift
- **XI (Logs)** — Docker captures stdout from all containers; a log aggregator (CloudWatch, Datadog) reads the stream

**The factor most ColdFusion apps violate:** Factor III. Datasource credentials hardcoded in `Application.cfc`, SMTP passwords in `cfmail` calls, API keys in `.cfm` files. The `System.getenv()` pattern above is the fix.

**Connection to SOLID:** Factor III (inject config from outside) and the Dependency Inversion Principle (inject dependencies from outside) are the same idea at two different levels — don't hardcode what can change, inject it.
::

::image-box
---
:src: __static__/application-cfc-env-vars-v1.png
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
    queryExecute("SELECT 1", {}, {datasource: "training_db"});
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

::hint-box
---
:summary: AWS is one option — the same pattern works on Azure, GCP, and beyond
---
This lesson uses AWS because it is the most widely used cloud provider and Elastic Beanstalk gives the shortest path from a `docker-compose.yml` to a running environment. The underlying pattern — build an image, push to a registry, deploy a compose file — is identical on every major cloud:

| Cloud | Managed container service | Image registry |
|---|---|---|
| **AWS** | Elastic Beanstalk / ECS / EKS | ECR |
| **Azure** | Azure App Service / AKS | Azure Container Registry |
| **Google Cloud** | Cloud Run / GKE | Artifact Registry |
| **IBM Cloud** | Code Engine / IKS | IBM Container Registry |
| **Oracle Cloud** | Container Instances / OKE | OCIR |

The `docker-compose.yml` and `Application.cfc` you built in sections 1 and 2 do not change regardless of where you deploy. The only differences are authentication commands and registry URLs — the structure is the same. Once you understand the AWS flow, reading the equivalent docs for any other provider takes minutes.
::

Elastic Beanstalk (EB) is AWS's managed platform-as-a-service for Docker applications. You give it a `docker-compose.yml` and it handles provisioning, load balancing, and scaling — no manual EC2 setup.

The deployment is four steps. Each one maps directly to something you already have:

**Step 1 — Tag and push your image to Amazon ECR**

ECR is AWS's private Docker registry. You tag your local image with the ECR address and push it — the same `docker push` you already know, pointed at AWS instead of Docker Hub.

```bash
# Authenticate the local Docker daemon with ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    <account>.dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag cf-app:latest <account>.dkr.ecr.us-east-1.amazonaws.com/cf-app:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/cf-app:latest
```

**Step 2 — Initialise the EB application**

`eb init` tells the EB CLI which region to use and that you are deploying a Docker application. It creates a local `.elasticbeanstalk/config.yml` — commit this alongside your `docker-compose.yml`.

```bash
eb init cf-helpdesk --platform docker --region us-east-1
```

**Step 3 — Deploy**

EB reads your `docker-compose.yml`, pulls the image from ECR, provisions an EC2 instance (or auto-scaling group), and starts the containers. The `health.cfm` endpoint you built in section 2 is what EB's load balancer polls to decide whether the environment is healthy.

```bash
eb deploy
```

**Step 4 — Open in browser**

```bash
eb open
```

::image-box
---
:src: __static__/aws-eb-console-v1.png
:alt: AWS Elastic Beanstalk console showing a cf-helpdesk environment with health status Ok, a green health indicator, the environment URL, and the running EC2 instance type t2.micro
:max-width: 960px
---
_The Elastic Beanstalk console after a successful `eb deploy` — environment health green, URL live._
::

::hint-box
---
:summary: You won't run eb deploy in the lab — and that's fine
---
The lab environment does not include an AWS account. The hands-on work in this lesson — the Compose file, the environment variable pattern, and the health endpoint — is what you would carry into a real deployment unchanged. The `eb` commands above are exactly what you would run; nothing else changes between the lab and production.

AWS Free Tier includes 750 hours/month of `t2.micro` EC2 — enough to run one Elastic Beanstalk environment continuously at no cost. When you're ready to try it for real: https://aws.amazon.com/free/
::

---

## What you built

You started with the fundamental problem — a ColdFusion app that only runs on one specific, hand-configured server — and worked through every layer of the solution:

1. **A `docker-compose.yml`** that captures the entire stack (ColdFusion + MySQL) as code, with a health check that ensures CF never starts before the database is ready.
2. **An `Application.cfc`** that reads all configuration from environment variables, so the same image runs in dev, staging, and production without modification.
3. **A `health.cfm` endpoint** that gives load balancers a reliable signal — 200 when the app is healthy, 503 when it isn't.
4. **An Elastic Beanstalk deployment flow** that takes those three artifacts and puts them on AWS with one command.

The pattern scales. Swap MySQL for RDS, add an ALB in front, store secrets in Parameter Store instead of environment variables — each of those is a configuration change, not a code change. That is exactly what the twelve-factor methodology buys you.

## Key concepts reference

| Concept | Tool |
|---|---|
| Multi-container app | `docker-compose.yml` with `services:` |
| Service startup order | `depends_on: condition: service_healthy` + `healthcheck:` |
| Environment config | `System.getenv()` in `Application.cfc` |
| Health check endpoint | `health.cfm` returning 200/503 |
| Image registry | Amazon ECR |
| AWS deployment | Elastic Beanstalk + `eb deploy` |

---

When all tasks above are green, this lesson is complete.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Runs automatically — turns green once all previous tasks pass.

#completed
Cloud deployment lesson complete. On to the next one! ✓
::

---

## Put It Into Practice

> *"The cloud is just someone else's computer — but someone else's computer that scales."*
> — Werner Vogels, CTO of Amazon

Apply what you have covered in this lesson with the challenge below.

::card
---
:challenge: challenges.cloud-deployment-fe9fc951
---
::

