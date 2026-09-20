# Init Tasks — Troubleshooting Playbook

> **TL;DR** — If the playground is stuck at "Warming up playground… Init tasks completed: 0/N",
> the init task scripts have either timed out or the health check is polling something that
> boots too slowly. See the canonical patterns below.

---

## How the iximiuz platform boots a lesson

```
VM starts (microVM cold boot)
  └── systemd starts services
        ├── cf-server.service       → ColdFusion 2025 (port 8500, ~60–90 s cold boot)
        ├── lucee-server.service    → CommandBox/Lucee (port 8888, ~60–120 s)
        └── gitea.service           → Gitea (port 3000)

Platform task runner fires ALL init tasks in parallel
  ├── init_wait_for_cf  (machine: cf-dev)
  └── init_wait_for_solr / init_wait_for_lucee / init_wait_for_ollama (if present)

Playground UI shows "Warming up playground..."
  └── spinner stays until EVERY init task exits 0

Once all init tasks exit 0 → regular tasks start running → UI unlocks
```

**Key insight:** the platform fires all `init` tasks simultaneously the moment the VM is
reachable via SSH. ColdFusion has not started yet at that point. If an init task times out
(`timeout_seconds` exceeded) it exits non-zero and the spinner **never clears**.

---

## Canonical init task patterns

### `init_wait_for_cf` — ColdFusion on port 8500

```yaml
init_wait_for_cf:
  init: true
  machine: cf-dev
  user: laborant
  timeout_seconds: 300
  run: |
    until nc -z 127.0.0.1 8500 2>/dev/null; do
      echo "Waiting for ColdFusion on port 8500..."
      sleep 5
    done
    sleep 10
    echo "ColdFusion is up ✓"
```

**Rules:**
- Use `nc -z` (port open check), **not** an HTTP poll against `/CFIDE/administrator/`.
  The admin console is one of the last things CF deploys — polling it wastes 30–40 extra
  seconds from the timeout budget.
- The `sleep 10` after the port opens gives the JVM time to finish warmup before regular
  tasks start firing HTTP requests.
- `timeout_seconds: 300` — CF cold boot on a 2 GiB microVM takes 60–90 s.
  120 s was too tight; 300 s gives a safe margin.

### `init_wait_for_solr` — Solr on port 8983

```yaml
init_wait_for_solr:
  init: true
  machine: cf-dev
  user: laborant
  timeout_seconds: 300
  run: |
    sleep 30
    until nc -z 127.0.0.1 8983 2>/dev/null; do
      echo "Waiting for Solr on port 8983..."
      sleep 5
    done
    echo "Solr is up ✓"
```

**Rules:**
- Solr is spawned by ColdFusion as a child process. It cannot be up before CF is up.
  The `sleep 30` burns through the worst of the CF startup time before even trying.
- Because the task runner fires both `init_wait_for_cf` and `init_wait_for_solr`
  simultaneously, without the `sleep 30` you would waste the entire 300 s polling a port
  that doesn't open for another 90 s.
- `nc -z` is preferred over `curl http://localhost:8983/solr/` — the port opens before
  the Solr HTTP admin UI is fully ready.

### `init_wait_for_lucee` — Lucee/CommandBox on port 8888

```yaml
init_wait_for_lucee:
  init: true
  machine: cf-dev
  user: laborant
  timeout_seconds: 300
  run: |
    until curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/ | grep -q "200\|302"; do
      echo "Waiting for Lucee/CommandBox on port 8888..."
      sleep 5
    done
    echo "Lucee is up ✓"
```

**Note:** Lucee uses `curl` instead of `nc` because CommandBox/Lucee's HTTP layer
initialises slightly after the port opens. An HTTP 200/302 is the reliable signal here.
300 s timeout — first cold start downloads the Lucee engine if the CommandBox cache is cold.

### `init_wait_for_ollama` — Ollama on port 11434 (ollama VM)

```yaml
init_wait_for_ollama:
  init: true
  machine: ollama
  user: laborant
  timeout_seconds: 300
  run: |
    until curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags | grep -q "200"; do
      echo "Waiting for Ollama on port 11434..."
      sleep 5
    done
    echo "Ollama is up ✓"
```

**Note:** Ollama runs on its own dedicated VM (`ollama`), independent of `cf-dev`.
The `/api/tags` endpoint is the correct health check — it returns 200 only when the
model registry is ready (not just when the port opens). 300 s covers model loading time.

---

## What the "Warming up playground" UI actually means

| Platform state | What you see |
|---|---|
| VMs booting | "Warming up playground… Init tasks completed: 0/N" |
| Init tasks running (polling in loop) | Same — still 0/N |
| One init task exits non-zero (timeout) | Stuck forever at 0/N — **this is the bug** |
| All init tasks exit 0 | Spinner clears, regular tasks start, UI unlocks |

There is no platform-side timeout on the "warming up" phase visible to the student.
A single failing init task hangs the entire lesson indefinitely.

---

## Common failure modes

### `timeout_seconds` too low
- **Symptom:** "Init tasks completed: 0/2" forever, even after 3+ minutes.
- **Cause:** CF cold boot takes 60–90 s; old value was `timeout_seconds: 120`.
  The poll loop ate the budget.
- **Fix:** Use `timeout_seconds: 300` on all init tasks.

### Polling a slow HTTP endpoint instead of a port
- **Symptom:** Init task hangs close to the timeout, then fails.
- **Cause:** `/CFIDE/administrator/` requires full CF admin app deployment (~90 s).
  Port 8500 opens at ~60 s.
- **Fix:** Use `nc -z 127.0.0.1 8500` as primary check.

### Solr init fires before CF has started
- **Symptom:** `init_wait_for_solr` times out even with 300 s.
- **Cause:** Solr is a CF child process. Polling port 8983 at t=0 polls nothing.
- **Fix:** `sleep 30` at the top of the `init_wait_for_solr` run block.

### Two init tasks compete for the same resource budget
- **Symptom:** Both init tasks timeout at the same time.
- **Cause:** The task runner fires them in parallel, not sequentially. If both are
  polling the same slow service, both burn down their timeouts together.
- **Fix:** The tasks are independent by design — `init_wait_for_cf` polls CF,
  `init_wait_for_solr` polls Solr. Use `sleep 30` in the Solr task as a stagger.

---

## Checklist before pushing a lesson

- [ ] Every `init` task uses `timeout_seconds: 300` (never 120)
- [ ] `init_wait_for_cf` uses `nc -z 127.0.0.1 8500`, not an HTTP URL
- [ ] `init_wait_for_cf` has `sleep 10` after the port check
- [ ] `init_wait_for_solr` starts with `sleep 30` before its poll loop
- [ ] `init_wait_for_lucee` is only present in lessons that actually use Lucee
- [ ] `init_wait_for_ollama` runs on `machine: ollama`, not `cf-dev`
- [ ] Regular task at top of `needs:` chain does NOT use `needs: [init_wait_for_cf]` —
  the platform guarantees regular tasks only run after all init tasks pass, no explicit
  `needs` wiring to init tasks is required or supported

---

## Background — what lives where

| Service | Port | VM | Started by | Time to ready (cold) |
|---|---|---|---|---|
| ColdFusion 2025 | 8500 | cf-dev, cf-prod | `cf-server.service` | 60–90 s |
| Apache Solr 8.x | 8983 | cf-dev | CF child process | 90–120 s |
| CommandBox/Lucee | 8888 | cf-dev | `lucee-server.service` | 60–120 s |
| Gitea | 3000 | cf-dev | `gitea.service` | 10–20 s |
| Ollama | 11434 | ollama | `ollama.service` | 20–40 s |

Solr is **not separately installed** — it ships bundled inside the ColdFusion 2025 ZIP
at `/opt/coldfusion2025/cfusion/solr/`. It starts automatically when CF starts.
No separate `apt install` or Docker image layer is needed.

---

*Last updated after fixing eternal "Warming up" spinner across all 21 lessons — commit 53644e9.*
