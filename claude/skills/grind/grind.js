export const meta = {
  name: 'grind',
  description: 'Rewrite a document until it is both honest and effective: editor, read-only honesty auditor, reader-persona grader',
  whenToUse: 'Launched by the grind skill once it has set up a grind/ worktree with .grind/brief.yaml',
  phases: [
    { title: 'Prepare', detail: 'collect supported facts and write the reader rubric' },
    { title: 'Baseline', detail: 'audit and grade the original' },
    { title: 'Grind', detail: 'edit, then audit and grade, until the targets pass' },
    { title: 'Confirm', detail: 'fresh audit and grade of a draft that hit the target' },
  ],
}

if (!args.repo || !args.start) throw new Error('grind needs args.repo (the worktree) and args.start (the commit of v00)')
const REPO = args.repo
const NOTES = `${REPO}/.grind`
const HONESTY_MIN = args.honesty_min ?? 90
const TARGET = args.effectiveness_target ?? 85
const MAX_ROUNDS = args.max_rounds ?? 6
const PATIENCE = args.patience ?? 3
const BRIEF = `${NOTES}/brief.yaml`
const FACTS = args.facts ?? `${NOTES}/facts.yaml`
const RUBRIC = args.rubric ?? `${NOTES}/rubric.yaml`

const PENALTY = { fabrication: 25, misleading: 15, constraint: 15, stretch: 5, nit: 1 }
const BLOCKING = ['fabrication', 'misleading', 'constraint']

const tag = n => `v${String(n).padStart(2, '0')}`
const renderedPath = n => (args.render_ext ? `${NOTES}/rendered/${tag(n)}${args.render_ext}` : null)
const diffPath = n => `${NOTES}/diffs/${tag(n)}.diff`
const versionNamed = n => `${tag(n)} of the document: the files the brief lists under \`document\`, as they are now in ${REPO}`

const AUDIT = {
  type: 'object',
  properties: {
    claims_checked: { type: 'integer' },
    violations: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: Object.keys(PENALTY) },
          quote: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'quote', 'problem', 'evidence', 'fix'],
      },
    },
    questions_for_owner: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['claims_checked', 'violations', 'questions_for_owner', 'summary'],
}

const GRADE = {
  type: 'object',
  properties: {
    criteria: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          score: { type: 'integer', minimum: 0, maximum: 100 },
          reason: { type: 'string' },
        },
        required: ['name', 'score', 'reason'],
      },
    },
    first_impression: { type: 'string' },
    decision: { type: 'string' },
    weaknesses: { type: 'array', items: { type: 'string' } },
    suggestions: { type: 'array', items: { type: 'string' } },
  },
  required: ['criteria', 'first_impression', 'decision', 'weaknesses', 'suggestions'],
}

const EDIT = {
  type: 'object',
  properties: {
    commit: { type: 'string' },
    changelog: { type: 'array', items: { type: 'string' } },
    new_claims: {
      type: 'array',
      items: {
        type: 'object',
        properties: { quote: { type: 'string' }, source: { type: 'string' } },
        required: ['quote', 'source'],
      },
    },
  },
  required: ['commit', 'changelog', 'new_claims'],
}

const COUNT = {
  type: 'object',
  properties: { entries: { type: 'integer' } },
  required: ['entries'],
}

const WEIGHTS = {
  type: 'object',
  properties: {
    criteria: {
      type: 'array',
      items: {
        type: 'object',
        properties: { name: { type: 'string' }, weight: { type: 'number' } },
        required: ['name', 'weight'],
      },
    },
  },
  required: ['criteria'],
}

phase('Prepare')
await parallel([
  ...(args.facts
    ? []
    : [
        () =>
          agent(
            `Read the brief at ${BRIEF}. Read every path under its \`sources\` (walk directories; skim what is irrelevant to the goal). Write ${FACTS} as YAML with three lists:\n` +
              `facts: each {claim, source (path:line or URL), quote (exact supporting text), edited, about, caveats (context a fair reader needs, or empty)}\n` +
              `limits: things a writer chasing this goal might be tempted to say that the sources do not support or contradict, each with the source that settles it.\n` +
              `conflicts: where sources disagree, each {claim, versions: [{says, source, edited}], current (the most recently edited version, which is the truth)}.\n` +
              `\`edited\` is the date (YYYY-MM-DD) the cited text last changed: \`git blame\` on the line for files in git, otherwise the file's modification time. ` +
              `\`about\` is the time the claim describes, read from the text: a past claim names its period ("before March 2024"), and a present-tense claim describes the day it was written ("as of 2025-06"), which can be earlier than \`edited\` if the line was touched later. ` +
              `Word each claim with its time, so an old fact can't read as current: "had no embedded experience before joining CubeSpace", not "has no embedded experience". Claims about different times are not conflicts. ` +
              `owner-answers.md is newer than everything.\n` +
              `Cover everything relevant to the goal and audience. Prefer specific, checkable facts: numbers, dates, names, roles, outcomes. ` +
              `Use block literal style (key: |-) for any string containing a newline. Return the number of facts.`,
            { schema: COUNT, phase: 'Prepare', label: 'facts' },
          ).then(r => r && log(`facts.yaml: ${r.entries} facts`)),
      ]),
  ...(args.rubric
    ? []
    : [
        () =>
          agent(
            `Read the brief at ${BRIEF}: its goal, audience and audience_context files. Do not read its sources. Write ${RUBRIC} as YAML:\n` +
              `reader: |- a concrete persona of the reader: role, the decision in front of them, time they spend, what they have seen too often, what makes them act\n` +
              `criteria: 4 to 7 items, each {name, weight (weights sum to 100), measures (what it judges for this reader), anchors: {30, 50, 70, 90} (what a draft at that level looks like)}\n` +
              `Judge effectiveness with this reader only; leave out factual accuracy, because a separate auditor gates on it. ` +
              `Include one criterion for credibility: specific, human and believable rather than generic or machine-written. ` +
              (args.render_ext ? `The document is rendered, so include one criterion for its look: layout, hierarchy, whitespace, typography and how fast it skims. ` : '') +
              `Return the number of criteria.`,
            { schema: COUNT, phase: 'Prepare', label: 'rubric' },
          ).then(r => r && log(`rubric.yaml: ${r.entries} criteria`)),
      ]),
])

const honestyOf = a => Math.max(0, 100 - a.violations.reduce((s, v) => s + PENALTY[v.severity], 0))
const blockingOf = a => a.violations.filter(v => BLOCKING.includes(v.severity))
const twice = async f => (await f()) ?? (await f())

const rubricWeights = await twice(() =>
  agent(`Read ${RUBRIC} and return the name and weight of each criterion, exactly as written.`, {
    schema: WEIGHTS,
    phase: 'Prepare',
    label: 'weights',
    effort: 'low',
  }),
)
if (!rubricWeights) throw new Error(`could not read the weights in ${RUBRIC}`)
const weightOf = c => rubricWeights.criteria.find(w => w.name === c.name)?.weight ?? 0
const effectivenessOf = g => {
  const w = g.criteria.reduce((s, c) => s + weightOf(c), 0)
  return w ? Math.round(g.criteria.reduce((s, c) => s + weightOf(c) * c.score, 0) / w) : 0
}

const incremental = (n, base) =>
  `\nThis draft was edited from ${base.version}, which has already been audited. The changes are in ${diffPath(n)} ` +
  `(if that file is missing, audit every claim). Audit incrementally: check every claim in ` +
  `changed or added text, and any unchanged claim whose meaning the changes alter (new context, order or juxtaposition). ` +
  `Don't re-verify the rest. Carry over each of ${base.version}'s findings whose quoted text is still present and unchanged, ` +
  `and drop those the edit fixed. ${base.version}'s findings:\n${JSON.stringify(base.audit.violations, null, 2)}\n`

const audit = (n, ph, label, base) =>
  twice(() =>
    agent(
      `Audit ${versionNamed(n)}, for honesty.\n` +
        (renderedPath(n) ? `Rendered: ${renderedPath(n)} (check length and rendering constraints against it).\n` : '') +
        `Brief: ${BRIEF}\nFacts index: ${FACTS} (pointers only; open the cited sources).` +
        (base?.audit ? incremental(n, base) : ''),
      { agentType: 'grind-auditor', schema: AUDIT, phase: ph, label: label ?? `audit ${tag(n)}` },
    ),
  )

const grade = (n, ph, label) => {
  const r = renderedPath(n)
  const target = r ? `the rendered document ${r} (if that file is missing, read ${versionNamed(n)})` : versionNamed(n)
  return twice(() =>
    agent(
      `Grade ${target} as its intended reader.\n` +
        `Rubric: ${RUBRIC}\nBrief: ${BRIEF} (read goal, audience and the audience_context files; never open its sources)`,
      { agentType: 'grind-grader', schema: GRADE, phase: ph, label: label ?? `grade ${tag(n)}` },
    ),
  )
}

const history = []
const questions = new Set()
const ask = a => a?.questions_for_owner.forEach(q => questions.has(q) || (questions.add(q), log(`Question for the owner: ${q}`)))

const evaluate = async (n, ph, edit, base) => {
  const [a, g] = await parallel([() => audit(n, ph, undefined, base), () => grade(n, ph)])
  const rec = { n, version: tag(n), commit: n === 0 ? args.start : edit.commit, edit: edit ?? null, audit: a, grade: g }
  rec.honesty = a ? honestyOf(a) : null
  rec.blocking = a ? blockingOf(a).length : null
  rec.pass = !!a && rec.blocking === 0 && rec.honesty >= HONESTY_MIN
  rec.effectiveness = g ? effectivenessOf(g) : null
  ask(a)
  history.push(rec)
  log(
    `${rec.version}: honesty ${rec.honesty ?? '?'}` +
      (rec.pass ? ' (passed)' : ` (blocked, ${rec.blocking ?? '?'} blocking)`) +
      `, effectiveness ${rec.effectiveness ?? '?'}`,
  )
  return rec
}

const bestOf = () =>
  history.filter(r => r.pass && r.effectiveness != null).reduce((b, r) => (!b || r.effectiveness > b.effectiveness ? r : b), null)

const confirm = async rec => {
  const [a, g] = await parallel([
    () => audit(rec.n, 'Confirm', `confirm audit ${rec.version}`),
    () => grade(rec.n, 'Confirm', `confirm grade ${rec.version}`),
  ])
  rec.confirm = { audit: a, grade: g }
  ask(a)
  if (a && blockingOf(a).length) {
    rec.pass = false
    rec.audit.violations.push(...blockingOf(a))
    rec.blocking = blockingOf(rec.audit).length
    rec.honesty = honestyOf(rec.audit)
    log(`${rec.version}: the confirming audit found ${blockingOf(a).length} blocking violations`)
    return false
  }
  if (a) rec.honesty = Math.min(rec.honesty, honestyOf(a))
  if (g) rec.effectiveness = Math.round((rec.effectiveness + effectivenessOf(g)) / 2)
  log(`${rec.version}: confirmed honesty ${rec.honesty}, mean effectiveness ${rec.effectiveness}`)
  return rec.effectiveness >= TARGET
}

const summaryLine = r => {
  const head = `${r.version}: honesty ${r.honesty ?? '?'}, effectiveness ${r.effectiveness ?? '?'}, ${r.pass ? 'passed audit' : 'failed audit'}`
  return r.edit ? `${head}. Changes: ${r.edit.changelog.join('; ')}` : `${head}. (original)`
}

const feedback = (base, last) => {
  const parts = []
  if (!base.audit) {
    parts.push(`The audit of ${base.version} did not complete. Check every claim against the sources yourself.`)
  } else if (!base.pass) {
    parts.push(
      `The auditor blocked ${base.version}. Fix every blocking violation, and the stretches where you can. ` +
        `Only the audit is shown, because effectiveness does not count until the draft is honest.`,
      JSON.stringify(base.audit.violations, null, 2),
    )
  } else {
    parts.push(
      `${base.version} passed the honesty audit (honesty ${base.honesty}). Raise effectiveness from ${base.effectiveness} ` +
        `towards ${TARGET} without adding anything the sources don't support.`,
      `Reader's first impression: ${base.grade?.first_impression}`,
      `Reader's decision: ${base.grade?.decision}`,
      `Criteria: ${JSON.stringify(base.grade?.criteria ?? [], null, 2)}`,
      `Weaknesses:\n- ${(base.grade?.weaknesses ?? []).join('\n- ')}`,
      `Suggestions:\n- ${(base.grade?.suggestions ?? []).join('\n- ')}`,
    )
    if (base.audit?.violations.length)
      parts.push(`Non-blocking audit findings to clean up:\n${JSON.stringify(base.audit.violations, null, 2)}`)
  }
  if (last && last !== base)
    parts.push(
      `Your last attempt, ${last.version}, was discarded ` +
        (last.pass
          ? `because it scored ${last.effectiveness}, no better than ${base.version}.`
          : `because it failed the audit again.`) +
        ` Its changes: ${last.edit?.changelog.join('; ') ?? 'none'}. Don't repeat what didn't work.`,
    )
  return parts.join('\n\n')
}

let status = 'max rounds'
let improvedAt = 0
let fails = 0

const baseline = await evaluate(0, 'Baseline')
if (baseline.pass && baseline.effectiveness >= TARGET && (await confirm(baseline))) status = 'target met'

for (let r = 1; status === 'max rounds' && r <= MAX_ROUNDS; r++) {
  const last = history[history.length - 1]
  const best = bestOf()
  let base = best ?? last
  if (!last.pass && (fails < 2 || !best)) base = last
  else if (!last.pass) fails = 0

  const edit = await twice(() =>
    agent(
      `Round ${r} of at most ${MAX_ROUNDS}. Edit the document in place in the git worktree ${REPO}: the files the brief lists under \`document\`.\n` +
        `First check that \`git -C ${REPO} branch --show-current\` starts with grind/, and stop if it doesn't. ` +
        `Start from the base version, ${base.version} (commit ${base.commit}): stash any uncommitted changes (git -C ${REPO} stash -u), and if HEAD ` +
        `is not ${base.commit}, revert back to it in one commit: git -C ${REPO} revert --no-commit ${base.commit}..HEAD && ` +
        `git -C ${REPO} commit -m "grind: back to ${base.version}"\n` +
        (args.render_ext ? `After editing, run the brief's render command from ${REPO} with {out} = ${renderedPath(r)}, and fix any errors.\n` : '') +
        `Then commit your edit and return its hash: git -C ${REPO} add -A && git -C ${REPO} commit --allow-empty -m "grind ${tag(r)}: <what changed>"\n` +
        `Last, write the diff for the auditor: mkdir -p ${NOTES}/diffs; git -C ${REPO} diff --word-diff=plain ${base.commit} HEAD > ${diffPath(r)}\n` +
        `Brief: ${BRIEF}\nFacts: ${FACTS}\nRubric: ${RUBRIC}\n` +
        `To pass, a draft needs no blocking audit violations and honesty of at least ${HONESTY_MIN}. Effectiveness target: ${TARGET}.\n\n` +
        `History so far:\n${history.map(summaryLine).join('\n')}\n\nFeedback on the base draft:\n${feedback(base, last)}`,
      { agentType: 'grind-editor', schema: EDIT, phase: 'Grind', label: `edit ${tag(r)} from ${base.version}` },
    ),
  )
  if (!edit) {
    log(`${tag(r)}: the editor failed twice; skipping the round`)
    continue
  }

  const rec = await evaluate(r, 'Grind', edit, base)
  fails = rec.pass ? 0 : fails + 1
  if (rec.pass && (!best || rec.effectiveness > best.effectiveness)) improvedAt = r
  if (rec.pass && rec.effectiveness >= TARGET && (await confirm(rec))) status = 'target met'
  else if (bestOf() && r - improvedAt >= PATIENCE) status = 'plateau'
}

const scored = history.filter(r => r.honesty != null && r.effectiveness != null)
const dominated = p =>
  scored.some(
    q =>
      q !== p &&
      q.honesty >= p.honesty &&
      q.effectiveness >= p.effectiveness &&
      (q.honesty > p.honesty || q.effectiveness > p.effectiveness),
  )
const best = bestOf()
const point = r => ({ version: r.version, commit: r.commit, honesty: r.honesty, effectiveness: r.effectiveness, pass: r.pass })

return {
  status: best ? status : 'no honest draft',
  targets: { honesty_min: HONESTY_MIN, effectiveness_target: TARGET },
  best: best ? point(best) : null,
  frontier: scored.filter(p => !dominated(p)).map(point),
  questions_for_owner: [...questions],
  history,
}
