---
name: grind
description: Rewrite a document over many rounds until it is as persuasive as possible without saying anything untrue. An editor revises, a read-only honesty auditor blocks any claim the sources don't support, and a read-only grader plays the intended reader and scores the draft, looping until both targets pass. Use for CVs against a job description, cover letters, application answers, marketing copy, landing pages and pitches, or when the user says "grind on this", "optimise X for Y without lying", "tailor my CV to this job" or "/grind".
argument-hint: "<document> for <goal and reader>, using <sources>"
---

# grind

Three roles take turns on one document:

1. **Editor** (`grind-editor` agent) edits the document each round.
2. **Honesty auditor** (`grind-auditor` agent, read-only) checks every claim
   against the sources. One fabricated, misleading or constraint-breaking claim
   blocks the version.
3. **Grader** (`grind-grader` agent, read-only) plays the reader and scores the
   version against a rubric. It sees what the reader would see (the document,
   the job description) and never the sources or earlier scores.

The workflow script `grind.js`, next to this file, runs the loop. Your part is
the setup before it and the report after it.

A run is ordinary work on a branch. The editor edits the document's real files
in a git worktree and commits once per round, so each version is a commit and
git keeps every earlier one. The only other files are the notes the agents hand
each other (brief, facts, rubric, diffs, rendered pages), in a `.grind/` folder
that git ignores.

## 1. Set up

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

Make a worktree on a new branch from `HEAD`, so unpushed commits come along:

```sh
git -C <repo> worktree add -b grind/<slug> <repo>-grind-<slug> HEAD
mkdir <repo>-grind-<slug>/.grind && echo '*' > <repo>-grind-<slug>/.grind/.gitignore
```

Then call `EnterWorktree` with that `path`, so the Workflow tool can load its
script from `.grind/` and the agents can write without permission prompts. The
user's checkout and its uncommitted changes stay as they are. If the document
isn't in git, copy it into a new folder, `git init` and commit there, and copy
the winner back at the end.

Commit anything you add to the branch during setup (a new entry file, copied
snippets) and take `start` after that. `start` is v00, and the first round
stashes whatever isn't committed.

The document is every file it is built from: for a Typst CV, the `.typ` file,
the template and each snippet it pulls in. A rendered document's look is in
scope, so include its styling files. For a PDF with no source (Typst, LaTeX,
Markdown), extract the text to Markdown, commit it, and say so.

Other documents may share some of these files (snippets that several CVs use).
Unless the user wants the edits to reach those documents too, add a constraint
naming the shared files: to change one, the editor first copies it to a path of
this document's own (`snippets/<document>/<name>.yaml`) and points the document
at the copy.

Write `.grind/brief.yaml`:

```yaml
document:              # every file the document is built from, relative to the worktree, entry file first
  - resume/resumes/ai-safety.typ
  - resume/template.typ
  - resume/snippets/2026-mats.yaml
goal: |-
  Get an interview for the role below.
audience: |-
  The hiring manager for the Research Engineer role: skims the CV for ten
  seconds against the job description, reads fully if it looks relevant.
audience_context:      # files the reader has in front of them; the grader reads these
  - /abs/path/job-description.md
sources:               # ground truth, in the main checkout so mid-run fixes are seen; the grader never reads these
  - /abs/path/to/main-checkout/resume   # the original document counts when its owner wrote it
  - /abs/path/to/repo-about-me
voice: /abs/path/to/writing-voice.md   # optional: how the owner writes, with quotes and example posts
constraints:           # breaking any of these blocks a version
  - Fits on two pages when rendered.
render: null           # or a command run from the worktree root, with {out}: typst compile --root=resume resume/resumes/ai-safety.typ {out}
```

If there is a render command, render the original to
`.grind/rendered/v00<render_ext>`.

When the document speaks for its owner (a CV, a cover letter, an application
answer), it should sound like they wrote it. Point `voice` at a guide to their
writing: traits, each with a quote from their own posts or hand-written text,
and links to a few example posts. If none exists, write one from their writing
before launching and keep it with their other notes for later runs. The editor
writes in it, and the grader reads it too: readers spot language-model prose
fast, and a line that doesn't sound like the owner costs credibility.

Every constraint blocks a version, so keep `constraints` to hard rules: length,
format, and what the user explicitly required. Don't turn caution into
constraints ("state the result no more strongly than the abstract"): one such
rule blocked a draft for dropping the word "standard". Put cautions and
preferences in `.grind/owner-answers.md`, where the auditor applies its
"defensible, not lies" bar.

If the user gives a rubric, save it as `.grind/rubric.yaml`, with a `reader`
persona and `criteria` items of `name`, `weight`, `measures` and `anchors`.
Otherwise the workflow writes one. Write the user's answers and preferences
(the title they want, how to credit collaborators, how much puffing is fine) to
`.grind/owner-answers.md` and list it first under `sources`; every agent treats
it as first-hand and newest.

## 2. Launch

Copy `grind.js` from this skill's directory into `.grind/` and call the
Workflow tool with `scriptPath` set to that copy; the tool only loads scripts
from the working directory. There is no need to read it: the table below is
its whole interface. Just before the call, tell the user to approve the "Run a
dynamic workflow?" prompt, since the run waits on it. Pass these `args` as a
JSON object:

| Argument               | Default | Meaning                                                          |
| ---------------------- | ------- | ---------------------------------------------------------------- |
| `repo`                 |         | absolute path of the worktree                                    |
| `start`                |         | v00: `git rev-parse HEAD` in the worktree, once setup is committed |
| `honesty_min`          | 90      | lowest honesty score that passes, on top of no blocking findings |
| `effectiveness_target` | 85      | grader score that ends the run                                   |
| `max_rounds`           | 6       | editing rounds after the baseline                                |
| `patience`             | 3       | stop after this many rounds without a better passing version     |
| `render_ext`           | none    | output extension of the render command, e.g. `.pdf`              |
| `rubric`               | none    | path to an existing rubric; skips writing one                    |
| `facts`                | none    | path to an existing `facts.yaml`; skips collecting facts         |

Pass `rubric` and `facts` from an earlier run to resume it or compare against
it; scores are only comparable under the same rubric. When the user is short
of time (a deadline today), use `max_rounds: 2` and `patience: 1`; a full run
can take most of an hour. Each round costs three agents, plus five at the start
and two for each confirmation, so the defaults spend at most about 27.

Tell the user it has started. They can follow it in `/workflows`, which shows
each version's scores and the auditor's questions for them as they come up, and
with `git log` on the branch, where each version is a commit `grind vNN: ...`.
They can answer questions while the run goes: write the answers to
`.grind/owner-answers.md`; later rounds read them.

How the loop decides:

- Honesty is computed from the audit: 100, minus 25 per fabrication, 15 per
  misleading claim or broken constraint, 5 per stretch and 1 per nit. A version
  passes with no fabrication, misleading claim or broken constraint, and
  honesty at or above `honesty_min`.
- Effectiveness is the mean of the grader's per-criterion scores, weighted by
  the rubric.
- The baseline audit checks every claim. After that, each round's audit is
  incremental: the auditor checks only changed claims (and unchanged ones the
  edit puts in a new light), from the editor's diff in `.grind/diffs/`, and
  carries over the base version's findings that still apply.
- The auditor and grader score every version in parallel. The editor only sees
  the grade of a version that passed the audit; a blocked version goes back
  with its audit alone.
- The editor repairs a blocked version, but after two blocked versions in a
  row it goes back to the best passing one with `git revert`, in a commit of
  its own, and edits from there.
- A version that hits the target is checked again by a fresh auditor, auditing
  every claim from scratch, and a fresh grader. The run ends only if it still
  passes and the mean of the two grades still reaches the target.

## 3. Report

When the workflow finishes:

1. If the best version isn't the last commit, go back to it:
   `git -C <worktree> revert --no-commit <best commit>..HEAD`, then commit
   `grind: back to vNN`.
2. Tell the user:
   - the status (`target met`, `plateau`, `max rounds` or `no honest draft`)
     and the best version with both scores;
   - the frontier as a table of version, commit, honesty, effectiveness and
     passed;
   - the main changes, from
     `git -C <worktree> diff --word-diff <main branch>...HEAD`;
   - the non-blocking audit findings left in the best version;
   - `questions_for_owner`, each quoting the draft's whole sentence and the time
     it talks about, because the user doesn't have the draft open. Each answer
     can unlock a claim the auditor had to block. If the user answers, add them
     to `.grind/owner-answers.md` and run
     again from the branch's current commit, with the same `rubric` and a fresh
     `facts.yaml`.
3. Merging is the user's call, and they may prefer to copy parts across by hand.
   When they say so, call `ExitWorktree` with `keep` first, because git refuses
   the main checkout from inside the worktree. Then run
   `git -C <repo> merge grind/<slug>`. If their uncommitted changes touch the
   same files, stop and ask. If other documents share the edited files, rebuild
   them and tell the user what changed, such as a new page count.
4. Clean up only when the user is done with the branch: run
   `git -C <repo> worktree remove <repo>-grind-<slug>` and
   `git -C <repo> branch -d grind/<slug>`, and drop any stash the run left. The
   `.grind/` notes go with the worktree, including the rendered versions, so
   copy out anything the user wants to keep.

With `no honest draft`, say so plainly and list the blocking findings that kept
recurring.

## Without the Workflow tool

Run the same loop by hand with the Agent tool. Use the three agent types, the
prompts and scoring rules in `grind.js`, and the same rule that a blocked
version goes back to the editor with its audit alone.

`bun grind.test.mjs` checks the loop's control flow against scripted agents.
Run it after changing `grind.js`.
