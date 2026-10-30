---
name: grind
description: Rewrite a document over many rounds until it is as persuasive as possible without saying anything untrue. An editor revises, a read-only honesty auditor blocks any claim the sources don't support, and a read-only grader plays the intended reader and scores the draft, looping until both targets pass. Use for CVs against a job description, cover letters, application answers, marketing copy, landing pages and pitches, or when the user says "grind on this", "optimise X for Y without lying", "tailor my CV to this job" or "/grind".
argument-hint: "<document> for <goal and reader>, using <sources>"
---

# grind

Three roles take turns on one document:

1. **Editor** (`grind-editor` agent) writes a new draft each round.
2. **Honesty auditor** (`grind-auditor` agent, read-only) checks every claim
   against the sources. One fabricated, misleading or constraint-breaking claim
   blocks the draft.
3. **Grader** (`grind-grader` agent, read-only) plays the reader and scores the
   draft against a rubric. It sees what the reader would see (the draft, the job
   description) and never the sources or earlier scores.

The workflow script `grind.js`, next to this file, runs the loop. Your part is
the setup before it and the report after it.

## 1. Set up the run

Fill in the brief from the user's request. Ask only when the document, the goal
or the sources are missing. If the user says they will paste something (a job
description, a brief), wait for it rather than searching for it. Infer the
rest: a job description implies a hiring manager for that role at that
company; a product brief implies its target customer.

Your setup job is to find where the truth lives, not to check claims: other
repositories, paper folders, reviews, earlier applications, notes. List them
all under `sources`; the facts agent reads them and the auditor checks every
claim. Check a claim yourself only when the answer changes the brief, for
example a constraint on how an authorship or a result may be described.

Each draft is either one text file or a folder of files:

- One file: copy it to `drafts/v00<ext>`.
- Built from several files (a Typst CV that pulls in snippet YAML files, say):
  copy every file the document is built from into `drafts/v00/`, keeping their
  paths relative to the project root, and set `ext` to `""`. Each round the
  editor copies the whole folder and may change any file in it. Don't flatten
  it into one file.
- A PDF: find its source (Typst, LaTeX, Markdown). If there is none, extract
  the text to Markdown and say so.

Put the run directory with the work it belongs to: an existing application or
campaign folder if there is one, otherwise `grind-<slug>/` next to the
document. Create `drafts/` (and `rendered/` if there is a render command), copy
in the original as above, render it to `rendered/v00<render_ext>` if needed,
and write `brief.yaml`:

```yaml
document: /abs/path/to/original.yaml
goal: |-
  Get an interview for the role below.
audience: |-
  The hiring manager for the Research Engineer role: skims the CV for ten
  seconds against the job description, reads fully if it looks relevant.
audience_context:      # files the reader has in front of them; the grader reads these
  - /abs/path/job-description.md
sources:               # ground truth about the subject; the editor and auditor read these, the grader never does
  - /abs/path/to/repo-about-me
trust_original: true   # the original document's own claims count as a source
constraints:           # breaking any of these blocks a draft
  - Fits on two pages when rendered.
  - Keep every {{...}} redaction marker exactly as written.
render: null           # or a command with {draft} and {out}, e.g. typst compile --root={draft} {draft}/resumes/ai-safety.typ {out}
```

For a folder draft, `{draft}` is the folder, so the render command must work
from inside the copy (copy the template and anything else it imports too).

If the user gives a rubric, save it as `rubric.yaml` in the run directory, with
a `reader` persona and `criteria` items of `name`, `weight`, `measures` and
`anchors`. Otherwise the workflow writes one. If the run directory is in a git
repository, commit it before launching.

## 2. Launch the workflow

Copy `grind.js` from this skill's directory into the run directory, then call
the Workflow tool with `scriptPath` set to that copy. The tool only loads
scripts from the working directory, and the copy records which version of the
loop produced the run. If the run directory is outside the working directory,
read `grind.js` and pass its contents as `script` instead. Otherwise there is
no need to read it: the table below is its whole interface. Just before the
call, tell the user to approve the "Run a dynamic workflow?" prompt, since the
run waits on it. Pass these `args` as a JSON object:

| Argument               | Default | Meaning                                                          |
| ---------------------- | ------- | ---------------------------------------------------------------- |
| `run_dir`              |         | absolute path of the run directory                               |
| `ext`                  | `""`    | the document's extension, with the dot; `""` for a folder draft  |
| `honesty_min`          | 90      | lowest honesty score that passes, on top of no blocking findings |
| `effectiveness_target` | 85      | grader score that ends the run                                   |
| `max_rounds`           | 6       | editing rounds after the baseline                                |
| `patience`             | 3       | stop after this many rounds without a better passing draft       |
| `render_ext`           | none    | output extension of the render command, e.g. `.pdf`              |
| `rubric`               | none    | path to an existing rubric; skips writing one                    |
| `facts`                | none    | path to an existing `facts.yaml`; skips collecting facts         |

Pass `rubric` and `facts` from an earlier run to resume it or compare against
it; scores are only comparable under the same rubric. When the user is short
of time (a deadline today), use `max_rounds: 2` and `patience: 1`; a full run
can take most of an hour. Each round costs three
agents, plus four at the start and two for each confirmation, so the defaults
spend at most about 26. Tell the user it has started, and how to follow it:

- `progress.sh <run_dir>` (in this skill's directory) reads the workflow's
  journal and writes `progress.yaml`: each draft's honesty and effectiveness,
  blocking findings, the grader's decision and weaknesses. It also prints a
  score table and the best passing draft so far, which is the one to send if
  the user has to stop early.
- `progress.sh <run_dir> diff vNN` shows a word diff of a draft against the one
  it was edited from.
- Each draft is on disk in `drafts/` (and `rendered/`) as soon as it is written.
- The auditor's `questions_for_owner` show up in `progress.yaml` from the
  baseline audit on. The user can answer them while the run goes: write the
  answers to `owner-answers.md` in the run directory and add it to `sources`
  in `brief.yaml`. Every agent reads the brief when it starts, so later rounds
  use the answers.

How the loop decides:

- Honesty is computed from the audit: 100, minus 25 per fabrication, 15 per
  misleading claim or broken constraint, 5 per stretch and 1 per nit. A draft
  passes with no fabrication, misleading claim or broken constraint, and
  honesty at or above `honesty_min`.
- Effectiveness is the weighted mean of the grader's per-criterion scores.
- The auditor and grader score every draft in parallel, so every draft lands on
  the frontier. The editor only sees the grade of a draft that passed the
  audit; a blocked draft goes back with its audit alone.
- The editor repairs a blocked draft, but after two blocked drafts in a row it
  starts again from the best passing one.
- A draft that hits the target is checked again by a fresh auditor and a fresh
  grader. The run ends only if it still passes and the mean of the two grades
  still reaches the target.

## 3. Report

When the workflow finishes:

1. Save its return value as `ledger.yaml` in the run directory. Write the JSON
   to the scratchpad, then convert it so multi-line strings use `|-`:
   `yq -P '(.. | select(tag == "!!str" and test("\n"))) style = "literal"' result.json > ledger.yaml`
2. Copy the best draft to `best<ext>` in the run directory (`cp -R` for a
   folder), and commit.
3. Tell the user:
   - the status (`target met`, `plateau`, `max rounds` or `no honest draft`)
     and the best version with both scores;
   - the frontier as a table of version, honesty, effectiveness and passed;
   - the main changes from the original, from
     `git diff --no-index --word-diff <original> <best>`;
   - the non-blocking audit findings left in the best draft;
   - `questions_for_owner`. Each answer can unlock a claim the auditor had to
     block. If the user answers, write the answers to `owner-answers.md` in the
     run directory, add it to `sources`, and run again with the same `rubric`
     and a fresh `facts.yaml`.
4. Never overwrite the original document. Offer to copy the changed files back.
   When a changed file is shared with other documents (a snippet other CVs also
   use), ask whether to overwrite it or keep a separate copy for this one.

With `no honest draft`, say so plainly and list the blocking findings that kept
recurring.

## Without the Workflow tool

Run the same loop by hand with the Agent tool. Use the three agent types, the
prompts and scoring rules in `grind.js`, and the same rule that a blocked draft
goes back to the editor with its audit alone.

`bun grind.test.mjs` checks the loop's control flow against scripted agents.
Run it after changing `grind.js`.
