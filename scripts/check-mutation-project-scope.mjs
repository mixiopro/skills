#!/usr/bin/env node
// Bounded documentation regression for the hosted 1.1.0 mutation scope migration.
// Runtime truth: mixiopro/studio apps/app-kalaasetu/src/app/api/mcp/server.ts
// (tool parameter schemas, mutationTargets, and preflightMcpMutation).
import assert from 'node:assert/strict'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), '..'))
const skills = join(root, process.argv[3] ?? 'skills')
const tools = [
  'update_project', 'delete_project', 'update_episode', 'delete_episode',
  'update_element', 'delete_element', 'tag_element', 'bulk_update_elements',
  'delete_relation', 'revise_shot_specs', 'update_shot_state', 'update_reference',
  'submit_studio_job', 'generate_image', 'create_relation', 'bulk_create_relations',
  'link_graph', 'create_episode', 'create_element', 'bulk_create_elements',
  'register_reference_entities', 'upsert_screenplay', 'upsert_scene_packages',
  'create_character_turnaround', 'breakdown_script',
  // These scoped operations preflight outside the mutationTargets map.
  'batch_submit_studio_jobs', 'cancel_studio_job',
]
const contextScoped = new Set(['submit_studio_job', 'generate_image', 'batch_submit_studio_jobs'])
const toolNames = tools.join('|')
// Optionally compare the bounded list with a local Studio source checkout.
if (process.argv[4]) {
  const server = readFileSync(resolve(process.argv[4]), 'utf8')
  const targets = server.match(/const mutationTargets:[\s\S]*?= \{([\s\S]*?)\n\};/)
  assert(targets, 'Cannot locate server mutationTargets')
  for (const [, name] of targets[1].matchAll(/^  (\w+):/gm)) {
    assert(tools.includes(name), `Documentation check omits scoped mutation ${name}`)
  }
}

// Balance object braces while ignoring quoted strings and comments. This lets
// generation examples put their required context after nested media payloads.
function objectText(body, start) {
  const tokens = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|\/\/[^\n]*|\/\*[\s\S]*?\*\/|[{}]/g
  tokens.lastIndex = start
  let depth = 0
  for (let token; (token = tokens.exec(body));) {
    if (token[0] === '{') depth++
    else if (token[0] === '}' && --depth === 0) return body.slice(start, tokens.lastIndex)
  }
  return ''
}
const files = []
function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) walk(path)
    else if (entry.isFile() && entry.name.endsWith('.md')) files.push(path)
  }
}
walk(skills)
if (existsSync(join(root, 'AGENTS.md'))) files.push(join(root, 'AGENTS.md'))
const failures = []
let checked = 0
for (const file of files) {
  const body = readFileSync(file, 'utf8')
  const shorthand = new RegExp(`studio_(${toolNames})\\s*\\((?!\\s*\\{)`, 'g')
  for (const match of body.matchAll(shorthand)) {
    failures.push(`${file}: ${match[1]} must show an object with projectId`)
  }
  // Non-generation examples/signatures put project scope before nested payloads.
  const examples = new RegExp(`studio_(${toolNames})\\s*\\(\\s*\\{([^{}]*)`, 'g')
  const signatures = new RegExp('\\| `studio_(' + toolNames + ')` \\| `\\{([^{}]*)', 'g')
  for (const pattern of [examples, signatures]) {
    for (const match of body.matchAll(pattern)) {
      checked++
      const input = objectText(body, body.indexOf('{', match.index))
      const scoped = contextScoped.has(match[1])
        ? /\bcontext\s*:\s*\{[^{}]*\bprojectId\b/.test(input)
        : /\bprojectId\b/.test(match[2])
      if (!scoped) {
        const line = body.slice(0, match.index).split('\n').length
        failures.push(`${file}:${line}: ${match[1]} omits projectId`)
      }
      if (['upsert_screenplay', 'upsert_scene_packages'].includes(match[1])
        && !/\bepisodeId\b/.test(match[2])) {
        failures.push(`${file}: ${match[1]} omits episodeId`)
      }
    }
  }
  if (/take no `projectId`|verify no project scope/.test(body)) {
    failures.push(`${file}: stale unscoped-mutation guidance`)
  }
  if (file.endsWith('/mixio-episode/SKILL.md')) {
    if (!body.includes('both take `{ projectId, shots: [{ shotId, ... }] }`')) {
      failures.push(`${file}: shared shot mutation signature omits projectId`)
    }
    if (!body.includes('before any mutation')) {
      failures.push(`${file}: missing ownership preflight guidance`)
    }
  }
}
assert(checked > 0, 'No documented mutation calls/signatures found')
assert.equal(failures.length, 0, failures.join('\n'))
console.log(`PASS: ${checked} mutation calls/signatures across ${files.length} Markdown files`)
