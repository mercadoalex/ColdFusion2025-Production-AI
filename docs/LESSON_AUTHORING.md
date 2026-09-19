# Lesson Authoring Pattern

The canonical pattern for writing `unit-1.md` content in this course. Every lesson
follows this structure to give students a consistent, comfortable experience — a
catchy hook, progressive concept sections, activities at every step, and abundant
hint boxes so nobody feels lost.

Reference lessons to study:
- [`course-advanced/module-1/0.lesson-bridge/unit-1.md`](../course-advanced/module-1/0.lesson-bridge/unit-1.md) — strongest intro storytelling
- [`course-advanced/module-1/1.lesson-cicd/unit-1.md`](../course-advanced/module-1/1.lesson-cicd/unit-1.md) — best activity + hint box density
- [`course-advanced/module-4/1.lesson-ollama-api/unit-1.md`](../course-advanced/module-4/1.lesson-ollama-api/unit-1.md) — good multi-task pacing
- [`course-advanced/module-2/1.lesson-java-integration/unit-1.md`](../course-advanced/module-2/1.lesson-java-integration/unit-1.md) — full pattern with 6 sections

---

## File structure

Every lesson is three files:

```
module-N/
  Y.lesson-name/
    index.md       ← kind: lesson  — frontmatter only: metadata, tasks, challenge refs
    unit-1.md      ← kind: unit    — all readable content lives here
    __static__/    ← images for this lesson (PNG, named with -vN suffix)
      .gitkeep
```

`index.md` and `unit-1.md` are strictly separated — no content in `index.md`,
no task definitions in `unit-1.md`.

---

## The anatomy of unit-1.md

### 1. Frontmatter

```yaml
---
kind: unit

title: Your Lesson Title

name: your-lesson-slug-unit-1
---
```

Three fields, nothing else. `kind: unit` is required exactly as written.

---

### 2. Opening hook (the "catchy introduction")

The first section has no section number. It is **not** named "Introduction" — it has
a short, punchy headline that answers "why should I care?" before any code appears.

**Pattern:**

```markdown
## [Surprising fact, bold claim, or "you already X" framing]

[1–3 short paragraphs that connect the student's existing knowledge to the new topic.
Make it personal. Use "you". Tell a tiny story or reveal something unexpected.]

::image-box
---
:src: __static__/concept-overview-v1.png
:alt: [Full alt text describing every element in the image for screen readers]
:max-width: 860px
---
_[Caption explaining what the diagram shows and why it matters.]_
::

[A table summarising the "when to use this" decision — 2 columns, 5–8 rows.]

::hint-box
---
:summary: [Reassurance or context-setting question the nervous student is thinking]
---
[Answer it directly. End the reader's doubt before the first activity.]
::
```

**What makes a good hook:**
- Reveals a surprising truth (`"every .cfm file you've ever written was compiled to Java bytecode"`)
- Connects to what the student already knows (`"In the Foundations course you built X — this lesson picks up exactly where that ended"`)
- Ends anxiety before it starts (`"Do I need to know Java to use this lesson? No."`)

---

### 3. Content sections

Each section is numbered (`## 1.`, `## 2.`, etc.) and covers one concept.
Target 4–6 sections per lesson. Each section follows this internal structure:

```
[Concept explanation — 1–3 paragraphs or a table]
[Code block — annotated with comments]
[::hint-box — explains the non-obvious thing in the code]
[Activity — a copy-pasteable terminal command or file to create]
[::simple-task — the verification for the activity]
```

Not every section needs a `::simple-task` — only sections where the student
produces something verifiable. Aim for 3–5 tasks per lesson total.

---

### 4. Image boxes

Every major concept section should have at least one diagram. Images appear
**before** the code block they illustrate, never after.

```markdown
::image-box
---
:src: __static__/filename-v1.png
:alt: [Detailed description — what panels exist, what labels say, what arrows connect]
:max-width: 860px
---
_[Caption: what the diagram shows + why it matters in one sentence.]_
::
```

**Naming convention:** `<concept>-<descriptor>-v<N>.png`
- `cfml-jvm-bridge-v1.png`
- `java-stdlib-cfml-v1.png`
- `cicd-pipeline-overview-v1.png`

Use `v1`, `v2`, etc. when replacing an image — never overwrite; increment instead.

**When an image doesn't exist yet**, create a `.todo` file alongside the `.gitkeep`
describing exactly what the image should show:

```
__static__/concept-diagram-v1.png.todo
```

---

### 5. Hint boxes

Hint boxes are collapsible — the student sees only the `:summary:` label and
expands to read more. Use them heavily. They are the primary tool for making
students feel safe.

```markdown
::hint-box
---
:summary: [The question or doubt the student has right now]
---
[Answer it completely. Can include code blocks, tables, lists.]
::
```

**When to add a hint box:**
- After introducing a new syntax pattern — "Why does X work like this?"
- Before an activity — "What if I already have Y from the previous lesson?"
- After a code block with non-obvious behaviour — "Why do we need Z here?"
- Whenever a concept has a common beginner mistake — name it and defuse it
- Production gotchas that don't belong in the main flow (`reloadOnChange — leave it off in production`)

**Hint box density target:** one per major code block, minimum. 8–12 per lesson is normal.

**Good summary labels:**
- `Why call .init() after createObject()?`
- `Do I need to know Java to use this lesson?`
- `Coming from the Foundations course? Here's where we left off.`
- `currentTimeMillis() vs nanoTime() — which should I use?`
- `NullPointerException — the #1 beginner mistake`

**Bad summary labels (too vague):**
- `More info`
- `Details`
- `Note`
- `Tip`

---

### 6. Activities

Every section that produces a verifiable artefact ends with an Activity followed
immediately by a `::simple-task`.

**Activity format:**

```markdown
**Activity — Terminal (dev):** [One sentence: what the student is doing and why.]

[Optional: numbered purpose list for multi-step activities]
1. What this confirms
2. What this proves

```bash
# Comment explaining the command
actual-command --with args
```

```bash
# Verification command the student runs themselves
curl -s http://localhost:8500/result.cfm
```
```

**Rules:**
- Always name the tab: `Terminal (dev)`, `Terminal (prod)`, `Terminal (ollama)`, `Gitea`
- Paste-ready commands only — no placeholders like `<your-value>`
- Add inline comments (`# ...`) on the lines that need explanation
- If a multi-step activity, a numbered purpose list helps orient the student before they type

#### Writing CFML files from bash activities

Use `sudo tee` with a quoted heredoc — the same pattern used throughout all lessons:

```bash
sudo tee /opt/coldfusion2025/cfusion/wwwroot/example.cfm << 'EOF'
<cfscript>
  reply = svc.generate("Hello");
  writeOutput(reply);
</cfscript>
EOF
```

**The one rule:** every CFML statement inside the heredoc must fit on a **single line**. Multi-line string concatenations and multi-line `cfhttp(` attribute blocks cause CFML parse errors because the shell writes the newline literally. Keep each statement self-contained on one line and heredocs work identically to every other lesson in the course.

---

### 7. Simple-task blocks

One `::simple-task` per verifiable activity. The task name must exactly match a
task defined in the lesson `index.md`.

```markdown
::simple-task
---
:tasks: tasks
:name: verify_task_name
---
#active
[What the student should do to make this task pass. Present tense, imperative.]

#completed
[Confirmation message. Use ✓ at the end. Optionally add a small celebration or "on to the next one".]
::
```

**Active text:** be specific. Name the file, the URL, or the exact output to look for.
- Good: `In the **Terminal (dev)** tab, run the curl command above and confirm it prints 200.`
- Bad: `Complete the activity above.`

**Completed text:** short, positive, closes the loop.
- Good: `java_demo.cfm is accessible. ✓`
- Bad: `Done.`

**The final task in every lesson** is `verify_lesson_complete` and always reads:

```markdown
::simple-task
---
:tasks: tasks
:name: verify_lesson_complete
---
#active
All [N] tasks are green — hit **Check** to complete this lesson.

#completed
[Lesson topic] lesson complete. On to the next one! ✓
::
```

---

### 8. Key concepts reference table

Every lesson ends with a `## Key concepts reference` section — a two-column
table of term → syntax or explanation. This is the student's cheat sheet.

```markdown
## Key concepts reference

| Concept | Detail |
|---|---|
| Instantiate a Java class | `createObject("java", "pkg.ClassName").init()` |
| ... | ... |
```

---

### 9. Challenge card

The very last element. Always preceded by `## Now Prove It` and optionally
one sentence of context.

```markdown
---

## Now Prove It

::card
---
:challenge: challenges.<platform-slug>
---
::
```

See [`CHALLENGE_AUTHORING.md`](./CHALLENGE_AUTHORING.md) for slug rules.

---

## Complete section checklist

When reviewing a unit, confirm:

- [ ] Opening section has a punchy headline (not "Introduction")
- [ ] First hint box reassures the student before any code appears
- [ ] At least one `::image-box` in the intro and in each major section
- [ ] Each `::image-box` has detailed `:alt:` text and a caption
- [ ] Every non-obvious code pattern has a `::hint-box` immediately after
- [ ] Every activity names the terminal tab
- [ ] Every activity's commands are paste-ready with no placeholders
- [ ] Every activity is followed by a `::simple-task`
- [ ] Task names in `::simple-task` match task names in `index.md` exactly
- [ ] `verify_lesson_complete` is the last task
- [ ] `## Key concepts reference` table is present before the final task
- [ ] `## Now Prove It` + `::card` is the absolute last thing in the file
- [ ] Image files exist in `__static__/` (or `.todo` placeholders if not yet designed)

---

## Component syntax quick reference

### image-box

```markdown
::image-box
---
:src: __static__/filename-v1.png
:alt: Full description of the image
:max-width: 860px
---
_Caption text._
::
```

### hint-box (collapsible detail box)

```markdown
::hint-box
---
:summary: The label the student sees before expanding
---
Content revealed when expanded. Can contain code, tables, lists.
::
```

### simple-task (verification block)

```markdown
::simple-task
---
:tasks: tasks
:name: task_name_in_index_md
---
#active
What the student needs to do.

#completed
Confirmation message. ✓
::
```

### challenge card

```markdown
::card
---
:challenge: challenges.<platform-slug>
---
::
```

---

## Tone and voice

| Do | Don't |
|---|---|
| Use "you" throughout | Use "the student" or passive voice |
| Short sentences. One idea per sentence. | Run-on explanations |
| Name the surprising thing first, explain second | Explain first, reveal second |
| Acknowledge what's confusing before explaining it | Assume it's obvious |
| Bold the key term on first use | Introduce terms without emphasis |
| `> ⚠️ Reference only — do not paste this` for non-runnable blocks | Show non-runnable code without a warning |
| `> ⏱️ This can take 30–90 seconds` for slow operations | Leave the student wondering if it's stuck |

---

## Image alt text standard

Alt text must describe every meaningful element in the image — panels, labels,
arrows, colours, annotations. Screen-reader users and the image generation
pipeline both depend on it being complete.

**Format:** `[Subject] showing [what the diagram contains] — [labels/annotations]`

**Example:**
```
Architecture diagram showing ColdFusion CFML code on the left calling
createObject("java","java.util.ArrayList") with an arrow pointing through a
JVM boundary to the Java standard library on the right, with a label
"same JVM process — zero overhead"
```

---

## What makes students feel comfortable

The whole point of this pattern is comfort. Students in this course are
experienced ColdFusion developers learning unfamiliar territory. The design
choices that reduce anxiety:

1. **The hook removes the "why am I doing this?" doubt immediately.** Every lesson
   opens by connecting the new topic to something the student already knows and trusts.

2. **Hint boxes name the doubt before the student asks it.** The summary label is
   literally the question in the student's head. Seeing it acknowledged before they
   even type anything builds trust.

3. **Activities are paste-ready.** No placeholder values. No "fill in your server IP".
   Copy, paste, done. The student's terminal should succeed on the first try.

4. **Verification is immediate.** Every activity is followed within 2–3 lines by
   a `::simple-task` that gives the student a green checkmark. This creates a
   rhythm of small wins.

5. **Production gotchas are explicit, not hidden.** `reloadOnChange: false in
   production`, `set -Xmx to 60–70% of RAM`, `never store nanoTime() in a database`
   — say these things clearly, in hint boxes, right where they're relevant.
   Don't leave the student to discover them in production.
