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
]
const toolNames = tools.join('|')
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
  // Examples and signature tables put scope before any nested payload object.
  const examples = new RegExp(`studio_(${toolNames})\\s*\\(\\s*\\{([^{}]*)`, 'g')
  const signatures = new RegExp('\\| `studio_(' + toolNames + ')` \\| `\\{([^{}]*)', 'g')
  for (const pattern of [examples, signatures]) {
    for (const match of body.matchAll(pattern)) {
      checked++
      if (!/\bprojectId\b/.test(match[2])) {
        const line = body.slice(0, match.index).split('\n').length
        failures.push(`${file}:${line}: ${match[1]} omits projectId`)
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
