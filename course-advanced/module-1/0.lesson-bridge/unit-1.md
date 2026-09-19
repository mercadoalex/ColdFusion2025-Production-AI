---
kind: unit

title: From Developer to DevOps Engineer

name: from-developer-to-devops-unit-1
---

## You know ColdFusion. Now what?

In the Foundations course you built real things: CFML pages, database queries, REST APIs, CFCs with inheritance. You ran them on a single VM and they worked. 

That's the easy part.

The hard part is making them work **reliably**, for real users, across multiple environments, deployed by multiple people, without breaking at 2am. That's what this module is about — and it requires a different way of thinking.

This lesson doesn't have any commands. It has stories. Read them carefully — they are the "why" behind every tool you'll use in Module 1.

---

## The world your CF app lives in

When you pressed **Run** in the Foundations lab, you had:

- One machine
- One CF installation
- One person (you)
- No users depending on uptime

Real production looks like this:

| Reality | What it means |
|---|---|
| **Multiple environments** | Dev, staging, production — each slightly different |
| **Multiple developers** | Everyone deploys differently, nobody documents their steps |
| **Real users** | A broken deploy at 2pm affects paying customers |
| **Change is constant** | New features, bug fixes, security patches — every day |
| **Things fail** | Servers crash, deployments go wrong, databases get corrupted |

The gap between "it works on my machine" and "it works reliably in production" is where DevOps lives.

---

## The three problems DevOps solves

### Problem 1 — "Who broke it?"

It's 2am. Production is down. Your CF app is returning 500 errors. You check the server and find that someone deployed 4 hours ago — but the deployment was done by copying files over FTP, with no log of what changed, no version tag, and no way to roll back quickly.

You spend 2 hours figuring out what changed instead of fixing the problem.

**DevOps answer:** Every change is a git commit. Every deployment is tagged with the exact commit SHA. Rollback means `git revert` + one command. The audit trail is automatic.

---

### Problem 2 — "It works on my machine"

Your CF app uses a specific version of a third-party JAR, a datasource named `helpdesk`, and a custom CF mapping defined in the Admin UI. Works perfectly on your dev machine.

On staging: different CF version, no JAR, datasource named differently, mapping missing. Half the features break.

The operations team spends a day recreating your machine by hand, from memory, probably wrong.

**DevOps answer:** Package your app *and its entire runtime* into a container image. One image, same everywhere — dev, staging, production. If it runs in the container on your laptop, it runs identically in production.

::hint-box
---
:summary: What is a container, really?
---
A container is a packaged, isolated process. Think of it like a self-contained box that includes:
- The operating system layer your app needs
- The runtime (in CF's case: JVM + CF engine)
- Your application code
- All configuration and dependencies

When you run a container, you get an identical environment every time, on any machine that has a container runtime installed. The container doesn't know or care whether it's running on your laptop, a VM in AWS, or a server in a data centre.

For ColdFusion this means: a `Dockerfile` that installs CF 2025, copies your `.cfm` files into the webroot, and exposes port 8500. Build the image once, run it anywhere.
::

---

### Problem 3 — "The 2am deploy"

Deploying your CF app requires:
1. SSH into the server
2. Stop CF
3. FTP the new files over
4. Restart CF
5. Check if it works
6. If not, FTP the old files back
7. Restart CF again

Steps 3–7 are manual, error-prone, and stress-inducing at any hour. At 2am they are catastrophic.

**DevOps answer:** Automation. A CI/CD pipeline does steps 1–7 for you, every time, consistently, triggered by a single `git push`. If the automated tests fail, the deploy never happens. If the deploy fails, rollback is one command.

---

## The environment problem — visualised

Every CF application lives in at least three environments. The classic failure mode is when those environments drift apart:

| Environment | Purpose | Who uses it |
|---|---|---|
| **Development** (`cf-dev`) | Write and test new code | Developers |
| **Staging** | Test before release, mirrors production | QA, product team |
| **Production** (`cf-prod`) | Live system, real users | Everyone |

::hint-box
---
:summary: Why environments drift — and why it hurts
---
Environment drift happens slowly. Someone manually tweaks a CF Admin setting in production to fix a bug. Someone installs a JAR on the staging server and forgets to document it. Someone upgrades CF on dev but not production.

Six months later: a feature works perfectly in dev and staging, but silently fails in production because of a configuration difference nobody remembers making.

**Containers eliminate drift** by making the environment part of the code. The `Dockerfile` is the authoritative description of the environment. If you change the environment, you change the file, commit it, and the pipeline rebuilds the image. There is no undocumented manual state.
::

---

## What is Infrastructure as Code?

In the Foundations course, you configured ColdFusion through the Admin UI — clicking through screens to set up datasources, mappings, and mail servers. That configuration lives in XML files on the server and exists only as "things someone clicked once."

**Infrastructure as Code (IaC)** means describing your infrastructure — servers, configuration, networking — in files that are version-controlled, reviewed, and applied automatically. Instead of clicking through the CF Admin UI, you write a `CFConfig` file. Instead of setting up a server by hand, you write a `Dockerfile`.

The benefits are the same as using version control for code:

- **Reproducible** — spin up an identical environment in minutes
- **Auditable** — every change is a commit with a message and an author
- **Testable** — infrastructure changes go through the same review process as code

In this module you will practise IaC by writing a `Dockerfile` that fully describes your CF application environment, and a CI/CD workflow file that describes your deployment process.

---

## Your lab environment — two VMs, one network

This module uses two VMs on a shared private network:

| VM | What's installed | Role |
|---|---|---|
| `cf-dev` | ColdFusion 2025, Lucee, VS Code, Docker, Gitea | Development + CI/CD runner |
| `cf-prod` | ColdFusion 2025 | Production deployment target |

`cf-dev` and `cf-prod` can communicate with each other over the private network. `cf-dev` can SSH into `cf-prod`. This is the minimal topology of a real deployment setup — one machine where you develop and build, one machine where the app runs for users.

::hint-box
---
:summary: Why two VMs and not one?
---
Having a separate `cf-prod` VM matters because it forces you to think about the deployment step explicitly. If dev and prod were the same machine, you could never truly test "does this deploy work?" — you'd just be running files locally.

The two-VM setup mirrors what you'll encounter in every real organisation: a machine you build on, and machines you deploy to. The network between them is the deployment path.
::

---

## What you'll build in Module 1

By the end of this module you will have a complete, working DevOps pipeline for a ColdFusion application:

```
You write code on cf-dev
      ↓
git push → Gitea (local Git server on cf-dev:3000)
      ↓
Gitea Actions triggers automatically
      ↓
Pipeline: build Docker image → push to local registry → SSH deploy to cf-prod
      ↓
Your ColdFusion app is live on cf-prod, automatically, every time you push
```

Every piece of this pipeline is described in files — the `Dockerfile`, the workflow YAML, the git history. Nothing is manual. Nothing is undocumented. Everything can be replicated.

---

## Before you continue — verify your environment

Two quick checks to confirm your lab is ready. No new tools, no setup — just confirming what you already have from the Foundations course.

**Activity — Terminal (dev):** Confirm ColdFusion is running:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8500/CFIDE/administrator/
# Expected: 200 or 302
```

::simple-task
---
:tasks: tasks
:name: verify_cf_running
---
#active
In the **Terminal (dev)** tab, run the curl command above and confirm ColdFusion is responding on port 8500.

#completed
ColdFusion is running on cf-dev. ✓
::

**Activity — Terminal (dev):** Confirm `cf-prod` is reachable via SSH:

```bash
ssh -o StrictHostKeyChecking=no laborant@cf-prod "echo cf-prod is reachable"
# Expected: cf-prod is reachable
```

::simple-task
---
:tasks: tasks
:name: verify_ssh_to_prod
---
#active
In the **Terminal (dev)** tab, SSH into `cf-prod` and confirm the connection succeeds.

#completed
cf-prod is reachable from cf-dev via SSH. ✓
::

---

When both checks are green you're ready for the next lesson — where you'll install Gitea, write a Dockerfile, and build your first real CI/CD pipeline.

::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
Both environment checks are green — hit **Check** to complete this lesson.

#completed
Bridge lesson complete. Time to build the pipeline! ✓
::
