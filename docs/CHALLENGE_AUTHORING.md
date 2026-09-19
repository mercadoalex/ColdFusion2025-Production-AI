# iximiuz Labs — Challenge Authoring Rules

Lessons learned the hard way. Follow these rules exactly or the challenge will
show "Couldn't load the challenge" on the platform.

---

## Three independent files across two directories

```
challenges/
  <name>/
    index.md                    ← kind: challenge  (standalone, independent of any lesson)

course-foundations/
  module-X/
    Y.lesson-name/
      index.md                  ← kind: lesson     (references the challenge slug)
      unit-1.md                 ← kind: unit       (embeds the ::card at the bottom)
```

The `challenges/` directory is completely independent from `course-foundations/`.
The challenge exists on its own — it is linked into a lesson by slug reference,
not by file proximity.

---

## 1. Lesson `index.md` — how to reference a challenge

The lesson `index.md` is `kind: lesson`. The complete structure — based on a
real working example:

```yaml
---
kind: lesson

title: Multimedia Content Integration
description: |
  Embed and manage video, audio and other multimedia in ColdFusion applications.

name: multimedia-content-integration
slug: multimedia-content-integration

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- html5
- multimedia

# cover: __static__/cover.png

playground:
  name: cf-alex-edcdf975

challenges:
  multimedia-2ed52176: {}

tasks:
  verify_media_page:
    machine: dev-machine
    user: laborant
    run: |
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8500/media_demo.cfm)
      if [ "${STATUS}" != "200" ]; then
        echo "media_demo.cfm not found (got ${STATUS})"
        exit 1
      fi
      echo "media_demo.cfm is accessible"

  verify_lesson_complete:
    machine: dev-machine
    user: laborant
    needs:
      - verify_media_page
    run: |
      echo "Lesson complete — well done!"
---
```

**Rules:**
- `kind: lesson` — never `kind: challenge`
- `challenges:` comes BEFORE `tasks:`
- The challenge slug value is always `{}` — no extra config
- The slug must exactly match what the platform assigned (`labctl content create` prints it)
- `# cover: __static__/cover.png` is optional — comment it out if no cover image exists
- Tasks are bash scripts — exit 0 = pass, exit 1 = fail
- `needs:` creates a dependency chain — task only runs after its dependency passes

---

## 2. Lesson `unit-1.md` — structure and challenge card

### Frontmatter

```yaml
---
kind: unit

title: Your Lesson Title

name: your-lesson-name-unit-1
---
```

**Critical observations — missing or wrong fields cause silent failures:**

| Field | Required | Notes |
|---|---|---|
| `kind: unit` | ✅ | Must be exactly `unit` — not `lesson`, not `chapter` |
| `title:` | ✅ | Human-readable title shown at the top of the lesson |
| `name:` | ✅ | Unique identifier — convention is `<lesson-slug>-unit-1` |

**There is no `tagz:`, no `playground:`, no `tasks:` in `unit-1.md`** — those all live in `index.md`.

### Body content

The body is everything after the closing `---`. It contains all the readable
lesson content: prose, code blocks, images, hint boxes, simple-task blocks.

### ::card block — always at the very end

The `::card` block embeds the challenge card. It must be the **last thing** in
the file, after the final `::simple-task` and after any closing prose:

```markdown
## Now Prove It

The challenge below asks you to...

::card
---
:challenge: challenges.<platform-slug>
---
::
```

**The slug in `::card` must exactly match:**
- The slug in `challenges:` in the lesson `index.md`
- The slug the platform assigned when you ran `labctl content create`

**Common mistakes:**

| Mistake | Result |
|---|---|
| Wrong slug in `:challenge:` | "Couldn't load the challenge" |
| `::card` not at the end of the file | Challenge card may not render |
| Using `kind: lesson` instead of `kind: unit` | Unit content not rendered by platform |
| `name:` missing from frontmatter | Platform cannot register the unit |
| Using `tags:` instead of `tagz:` | Tags silently ignored (note: `tagz` with a z) |

---

## 3. Challenge `index.md` — the standalone challenge file

Lives in `challenges/<name>/index.md`. This is `kind: challenge` and is a
completely separate file from the lesson. It has two sections:

```
[frontmatter with kind: challenge]
---
[body content with ::simple-task blocks]
```

### Frontmatter

```yaml
---
kind: challenge

title: 'Your Challenge Title'

description: |
  One paragraph description shown in the challenge card.

categories:
  - programming

tagz:
  - coldfusion
  - cfml

difficulty: easy   # easy | medium | hard

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  task_name_1:
    machine: dev-machine
    user: laborant
    run: |
      echo "ok"

  task_name_2:
    machine: dev-machine
    user: laborant
    needs:
      - task_name_1
    run: |
      echo "ok"
---
```

**Critical rules:**
- NO `name:` field — the platform assigns the slug at creation time
- `playground.name` must exactly match `labctl playground list`
- Task names: lowercase, underscores only, no hyphens

### Body content

**Every task in the frontmatter MUST have a matching `::simple-task` in the
body** — without this the platform shows "Couldn't load the challenge":

```markdown
## Challenge title

Instructions for the student.

::simple-task
---
:tasks: tasks
:name: task_name_1
---
#active
Waiting for task_name_1 to pass...

#completed
Task 1 complete. ✓
::

::simple-task
---
:tasks: tasks
:name: task_name_2
---
#active
Waiting for task_name_2 to pass...

#completed
Task 2 complete. ✓
::
```

---

## 4. Full workflow — creating a new challenge

### Step 1 — Create the challenge on the platform (first time only)

```bash
labctl content create challenge <local-name> -d challenges/<local-name> --no-open -q
```

Prints the platform-assigned slug, e.g. `my-challenge-a1b2c3d4`. **Save it.**

### Step 2 — Write the challenge content

Edit `challenges/<local-name>/index.md` with the correct frontmatter and body.

### Step 3 — Push the challenge

```bash
labctl content push -f challenge <platform-slug> -d challenges/<local-name>
```

### Step 4 — Update the lesson `index.md`

Add the slug under `challenges:` before `tasks:`:

```yaml
challenges:
  <platform-slug>: {}
```

### Step 5 — Update the lesson `unit-1.md`

Add at the very end:

```markdown
::card
---
:challenge: challenges.<platform-slug>
---
::
```

### Step 6 — Push the course

```bash
labctl content push -f course ColdFusion-2025-Foundations-5151cba6 -d course-foundations
```

**Both the challenge AND the course must be pushed every time.**

---

## 5. Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| "Couldn't load the challenge" | No `::simple-task` blocks in challenge body | Add a `::simple-task` for every task in frontmatter |
| "Couldn't load the challenge" | Wrong slug in `::card` or `challenges:` | Check with `labctl content list` |
| Challenge not visible in lesson | Course not pushed after lesson `index.md` change | Run `labctl content push -f course ...` |
| `labctl: Couldn't get content: not found` | Pushing before creating | Run `labctl content create` first |
| Challenge loads but tasks don't run | `needs:` chain broken | Verify task names match exactly in frontmatter and `::simple-task` |

---

## 6. Checking slugs

```bash
# List all content (shows published items)
labctl content list

# Pull what the platform has for a specific slug (works for drafts too)
labctl content pull challenge <slug> -d /tmp/check-pull
```

Note: `labctl content list` only shows **published** content. Draft/author-only
challenges won't appear but can still be pulled and are accessible to the author.

---

## 7. Slugs reference

### Challenges

| Local directory | Platform slug |
|---|---|
| `challenges/multimedia` | `multimedia-2ed52176` |

### Courses

| Course | Platform slug |
|---|---|
| ColdFusion 2025: Foundations | `ColdFusion-2025-Foundations-5151cba6` |
| ColdFusion 2025: Production & AI | `ColdFusion-2025-Production-and-AI-6124d4b3` |

### Playground

| Name | Slug |
|---|---|
| Foundations (Course 1) | `cf-alex-edcdf975` |
