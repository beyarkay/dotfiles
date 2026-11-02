// Runs grind.js against scripted agents, no model calls: bun grind.test.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('./grind.js', import.meta.url), 'utf8').replace('export const meta', 'const meta')
const AsyncFunction = (async () => {}).constructor
const workflow = new AsyncFunction('args', 'agent', 'parallel', 'log', 'phase', source)

const violation = severity => ({ severity, quote: 'q', problem: 'p', evidence: 'e', fix: 'f' })
const auditOf = (...severities) => ({ claims_checked: 5, violations: severities.map(violation), questions_for_owner: [], summary: '' })
const gradeOf = score => ({
  criteria: [{ name: 'fit', score, reason: '' }],
  first_impression: '',
  decision: '',
  weaknesses: [],
  suggestions: [],
})

async function run(script, extra = {}) {
  const prompts = []
  const agent = async (prompt, opts) => {
    prompts.push({ label: opts.label, prompt })
    if (opts.label === 'facts' || opts.label === 'rubric') return { entries: 3 }
    if (opts.label === 'weights') return script.weights ?? { criteria: [{ name: 'fit', weight: 100 }] }
    if (opts.agentType === 'grind-editor') return { commit: `h-${opts.label.slice(5, 8)}`, changelog: [opts.label], new_claims: [] }
    const reply = script[opts.label]
    assert.ok(reply !== undefined, `no scripted reply for ${opts.label}`)
    return reply
  }
  const parallel = thunks => Promise.all(thunks.map(t => t().catch(() => null)))
  const result = await workflow({ repo: '/wt', start: 'c0', max_rounds: 4, patience: 2, ...extra }, agent, parallel, () => {}, () => {})
  return { result, prompts }
}

{
  const { result, prompts } = await run({
    'audit v00': auditOf('fabrication'),
    'grade v00': gradeOf(90),
    'audit v01': auditOf('stretch'),
    'grade v01': gradeOf(70),
    'audit v02': auditOf(),
    'grade v02': gradeOf(88),
    'confirm audit v02': auditOf(),
    'confirm grade v02': gradeOf(84),
  })
  assert.equal(result.status, 'target met')
  assert.equal(result.best.version, 'v02')
  assert.equal(result.best.effectiveness, 86)
  assert.deepEqual(result.frontier.map(p => p.version).sort(), ['v00', 'v02'])
  const firstEdit = prompts.find(p => p.label.startsWith('edit v01')).prompt
  assert.match(firstEdit, /blocked v00/)
  assert.doesNotMatch(firstEdit, /Reader's first impression/)
  assert.match(firstEdit, /base version, v00 \(commit c0\)/)
  assert.match(prompts.find(p => p.label.startsWith('edit v02')).prompt, /base version, v01 \(commit h-v01\)/)
  assert.match(firstEdit, /git -C \/wt diff --word-diff=plain c0 HEAD > \/wt\/\.grind\/diffs\/v01\.diff/)
  const auditPrompt = label => prompts.find(p => p.label === label).prompt
  assert.doesNotMatch(auditPrompt('audit v00'), /already been audited/)
  assert.match(auditPrompt('audit v01'), /edited from v00, which has already been audited\. The changes are in \/wt\/\.grind\/diffs\/v01\.diff/)
  assert.match(auditPrompt('audit v01'), /"severity": "fabrication"/)
  assert.match(auditPrompt('audit v02'), /edited from v01/)
  assert.doesNotMatch(auditPrompt('confirm audit v02'), /already been audited/)
}

{
  const { result } = await run({
    'audit v00': auditOf(),
    'grade v00': gradeOf(60),
    'audit v01': auditOf(),
    'grade v01': gradeOf(58),
    'audit v02': auditOf(),
    'grade v02': gradeOf(59),
  })
  assert.equal(result.status, 'plateau')
  assert.equal(result.best.version, 'v00')
}

{
  const { prompts } = await run({
    'audit v00': auditOf(),
    'grade v00': gradeOf(60),
    'audit v01': auditOf('misleading'),
    'grade v01': gradeOf(95),
    'audit v02': auditOf('fabrication'),
    'grade v02': gradeOf(95),
    'audit v03': auditOf(),
    'grade v03': gradeOf(70),
    'audit v04': auditOf(),
    'grade v04': gradeOf(71),
  }, { patience: 9 })
  const edits = prompts.filter(p => p.label.startsWith('edit'))
  assert.deepEqual(edits.map(p => p.label), ['edit v01 from v00', 'edit v02 from v01', 'edit v03 from v00', 'edit v04 from v03'])
  assert.match(edits[2].prompt, /git -C \/wt revert --no-commit c0\.\.HEAD && git -C \/wt commit -m "grind: back to v00"/)
  assert.match(edits[3].prompt, /base version, v03 \(commit h-v03\)/)
}

{
  const { result } = await run({
    'audit v00': auditOf(),
    'grade v00': gradeOf(90),
    'confirm audit v00': auditOf('fabrication'),
    'confirm grade v00': gradeOf(90),
    'audit v01': auditOf(),
    'grade v01': gradeOf(87),
    'confirm audit v01': auditOf('nit'),
    'confirm grade v01': gradeOf(85),
  })
  assert.equal(result.status, 'target met')
  assert.equal(result.best.version, 'v01')
  assert.equal(result.best.honesty, 99)
  assert.equal(result.history[0].pass, false)
  assert.equal(result.history[0].honesty, 75)
  assert.equal(result.history[0].commit, 'c0')
}

{
  const { result, prompts } = await run({
    'audit v00': auditOf(),
    'grade v00': gradeOf(60),
    'audit v01': auditOf(),
    'grade v01': gradeOf(90),
    'confirm audit v01': auditOf(),
    'confirm grade v01': gradeOf(90),
  }, { render_ext: '.pdf' })
  assert.equal(result.best.commit, 'h-v01')
  const edit = prompts.find(p => p.label.startsWith('edit v01')).prompt
  assert.match(edit, /git -C \/wt branch --show-current/)
  assert.match(edit, /\{out\} = \/wt\/\.grind\/rendered\/v01\.pdf/)
  assert.match(prompts.find(p => p.label === 'audit v01').prompt, /Rendered: \/wt\/\.grind\/rendered\/v01\.pdf/)
  assert.match(prompts.find(p => p.label === 'grade v01').prompt, /rendered document \/wt\/\.grind\/rendered\/v01\.pdf/)
  assert.match(prompts.find(p => p.label === 'audit v00').prompt, /v00 of the document: the files the brief lists under `document`, as they are now in \/wt/)
}

{
  const { result } = await run({
    weights: { criteria: [{ name: 'fit', weight: 90 }, { name: 'candour', weight: 10 }] },
    'audit v00': auditOf(),
    'grade v00': {
      ...gradeOf(60),
      criteria: [
        { name: 'fit', score: 60, reason: '' },
        { name: 'candour', weight: 82, score: 82, reason: '' },
      ],
    },
  }, { max_rounds: 0 })
  assert.equal(result.history[0].effectiveness, 62)
}

console.log('grind.js: all scenarios pass')
