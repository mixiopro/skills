#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

eval_skill='skills/mixio-eval/SKILL.md'
pipeline='skills/mixio-pipeline/SKILL.md'
example='skills/mixio-eval/references/modern-evaluation-request.example.json'

require() {
  rg -Fq -- "$2" "$1" || { echo "missing: $2 in $1" >&2; exit 1; }
}

require "$eval_skill" '`evals_evaluate_media`'
require "$eval_skill" '`evals_get_evaluation_result`'
require "$eval_skill" '`evals_list_evaluation_catalog`'
require "$eval_skill" 'deprecated'
require "$eval_skill" 'compatibility aliases only'
require "$eval_skill" '`source-url`, `asset-id`, or `reference-id`'
require "$eval_skill" '`shot-plan` object'
require "$eval_skill" 'worst transition and any blocking finding win'
require "$eval_skill" '`keyframe-continuity`'
require "$eval_skill" 'general storyboard lens'
require "$eval_skill" 'transport adapter'
require "$pipeline" 'evals_evaluate_media'
require "$pipeline" 'keyframe-continuity'
require "$pipeline" '`sequence-storyboard` only as a general storyboard lens'
require "$pipeline" 'video-multi-shot'
require "$pipeline" 'delivery-qc'

node - "$example" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const request = JSON.parse(fs.readFileSync(path, 'utf8'))
const fail = message => {
  console.error(`invalid eval example: ${message}`)
  process.exit(1)
}
const profiles = new Set([
  'keyframe-continuity',
  'sequence-storyboard',
  'video-multi-shot',
  'video-character',
  'video-general',
  'delivery-qc'
])
const roles = new Set([
  'candidate',
  'reference',
  'expected-state',
  'transcript',
  'subtitle',
  'audio',
  'sequence',
  'panel'
])
const types = new Set([
  'image',
  'video',
  'audio',
  'text',
  'sequence',
  'character-reference',
  'location-reference',
  'voice-reference',
  'style-reference',
  'prop',
  'prop-reference',
  'custom'
])
const sourceKeys = ['source-url', 'asset-id', 'reference-id']
const transitionDimensions = [
  'screenDirection',
  'spatialGeography',
  'identity',
  'pose',
  'wardrobe',
  'propState',
  'palette',
  'lighting',
  'camera',
  'temporalArtifacts'
]

if (typeof request['project-id'] !== 'string' || !request['project-id']) fail('project-id')
if ('projectId' in request) fail('runtime example must use project-id')
if (!profiles.has(request.profile)) fail('unsupported profile example')
if (request.profile !== 'keyframe-continuity') fail('strict example profile')
if (!Array.isArray(request.inputs) || request.inputs.length < 1) fail('inputs')
if (typeof request.prompt !== 'string' || !request.prompt) fail('prompt')
if (typeof request.threshold !== 'number' || request.threshold < 0 || request.threshold > 1) fail('threshold')
if (request.background !== true) fail('background must be true')
for (const legacyField of ['capability', 'videoUrl', 'imageUrls']) {
  if (legacyField in request) fail(`legacy field ${legacyField}`)
}
const outputSchema = request['output-schema']
if (!outputSchema || !['extend', 'replace-extension'].includes(outputSchema.mode)) fail('output-schema wrapper mode')
if (typeof outputSchema.namespace !== 'string' || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(outputSchema.namespace)) fail('output-schema wrapper namespace')
if (!outputSchema.schema || typeof outputSchema.schema !== 'object' || Array.isArray(outputSchema.schema)) fail('output-schema wrapper schema')
if (Object.keys(outputSchema).sort().join(',') !== 'mode,namespace,schema') fail('output-schema wrapper keys')
if ('$schema' in outputSchema || 'type' in outputSchema) fail('output-schema must not be a root schema')
const schema = outputSchema.schema
if (schema.type !== 'object' || schema.additionalProperties !== false) fail('output-schema object contract')
const reservedExtensionProperties = new Set(['id', 'object', 'type', 'status', 'model', 'output', 'contract-version', 'catalog-version', 'verdict', 'passed', 'score', 'threshold', 'confidence', 'profile', 'metrics', 'findings', 'evidence', 'coverage', 'resolved-plan', 'skill-outputs', 'extensions', 'input-alias', 'source-url', 'required-floor', 'finding-ids', 'evidence-ids'])
const publicProperty = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/
const checkExtensionPropertyNames = (node) => {
  if (!node || typeof node !== 'object' || Array.isArray(node)) return
  if (node.properties && typeof node.properties === 'object' && !Array.isArray(node.properties)) {
    for (const key of Object.keys(node.properties)) {
      if (!publicProperty.test(key) || reservedExtensionProperties.has(key)) fail(`output-schema reserved or invalid property ${key}`)
      checkExtensionPropertyNames(node.properties[key])
    }
  }
  if (node.items) checkExtensionPropertyNames(node.items)
  if (node.$defs && typeof node.$defs === 'object') Object.values(node.$defs).forEach(checkExtensionPropertyNames)
}
checkExtensionPropertyNames(schema)
const outputRequired = new Set(schema.required || [])
for (const field of ['review-verdict', 'worst-transition', 'blocking-findings', 'transitions']) {
  if (!outputRequired.has(field)) fail(`output-schema required ${field}`)
}
if (!schema.properties || !schema.properties['review-verdict'] || !Array.isArray(schema.properties['review-verdict'].enum)) fail('output-schema verdict enum')
if (!schema.properties['worst-transition'].required?.includes('transition-id') || !schema.properties['worst-transition'].required?.includes('transition-status')) fail('output-schema worst transition identity')
if (!schema.properties['blocking-findings'].items?.$ref) fail('output-schema blocking findings reference')
if (!schema.properties.transitions.minItems || !schema.properties.transitions.items?.properties?.['transition-findings']) fail('output-schema transition findings')
const findingSchema = schema.$defs?.finding
if (!findingSchema || !['finding-id', 'transition-id', 'dimension', 'classification', 'blocking', 'message'].every(field => findingSchema.required?.includes(field))) fail('output-schema finding structure')
const findingClassifications = ['intended_change', 'accidental_drift', 'technical_artifact', 'unlocalized']
if (!findingClassifications.every(classification => findingSchema.properties.classification.enum?.includes(classification))) fail('output-schema finding classifications')

const aliases = new Set()
for (const input of request.inputs) {
  if (!/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(input['input-alias'])) fail('input-alias')
  if (aliases.has(input['input-alias'])) fail('duplicate input-alias')
  aliases.add(input['input-alias'])
  if (!roles.has(input.role)) fail(`role ${input.role}`)
  if (!types.has(input.type)) fail(`type ${input.type}`)
  const sourceCount = sourceKeys.filter(key => typeof input[key] === 'string' && input[key]).length
  if (sourceCount !== 1) fail(`exactly one source for ${input['input-alias']}`)
  if (input['source-url'] && !/^https?:\/\//.test(input['source-url'])) fail('source-url must be HTTP(S)')
  if (!request.prompt.includes(`@${input['input-alias']}`)) fail(`prompt mention @${input['input-alias']}`)
}

const ordered = request.inputs.map(input => input['input-alias'])
if (ordered.join(',') !== 'shot-01-end,shot-02-start,shot-02-video,expected-state') fail('ordered evidence')
if (request.inputs[0].role !== 'candidate' || request.inputs[1].role !== 'candidate') fail('keyframe candidate roles')
if (request.inputs[2].role !== 'candidate' || request.inputs[2].type !== 'video') fail('candidate video')
if (request.inputs[3].role !== 'expected-state' || request.inputs[3].type !== 'text') fail('expected-state input')

const keyframeContinuity = request['keyframe-continuity']
if (!keyframeContinuity || !Array.isArray(keyframeContinuity.frames) || keyframeContinuity.frames.length !== 2) fail('keyframe-continuity frames')
const keyframeAliases = new Set(request.inputs.slice(0, 3).map(input => input['input-alias']))
for (const frame of keyframeContinuity.frames) {
  if (!keyframeAliases.has(frame['input-alias'])) fail('keyframe input binding')
  const input = request.inputs.find(candidate => candidate['input-alias'] === frame['input-alias'])
  if (!input || input.role !== 'candidate' || !['image', 'video', 'sequence'].includes(input.type)) fail('keyframe candidate binding')
  if (typeof frame.id !== 'string' || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(frame.id)) fail('keyframe id')
  if (!Number.isInteger(frame['frame-index']) && !Number.isInteger(frame['time-ms'])) fail('keyframe localization')
}
if (!Array.isArray(keyframeContinuity.relations) || keyframeContinuity.relations.length !== 1) fail('keyframe relations')
if (keyframeContinuity.relations[0].from !== keyframeContinuity.frames[0].id || keyframeContinuity.relations[0].to !== keyframeContinuity.frames[1].id) fail('keyframe relation order')

if (!Array.isArray(request.shots) || request.shots.map(shot => shot.id).join(',') !== 'shot-01,shot-02') fail('ordered shots')
if (request['shot-plan']?.sequence?.join(',') !== request.shots.map(shot => shot.id).join(',')) fail('shot-plan sequence')
const transitions = request['shot-plan']?.transitions
if (!Array.isArray(transitions) || transitions.length !== 1) fail('transitions')
const transition = transitions[0]
if (transition.id !== 'shot-01-to-shot-02' || transition.from !== 'shot-01' || transition.to !== 'shot-02') fail('transition identity')
for (const dimension of transitionDimensions) {
  if (typeof transition.expectedState?.[dimension] !== 'string' || !transition.expectedState[dimension]) fail(`expectedState.${dimension}`)
}
if (!Array.isArray(transition.intentionalChanges) || transition.intentionalChanges.length < 1) fail('intentionalChanges')

const terminalStatuses = new Set(['completed', 'failed', 'cancelled'])
const completed = {
  ok: true,
  runId: 'response-example',
  status: 'completed',
  terminal: true,
  threshold: 0.8,
  evaluation: { id: 'response-example', status: 'completed' }
}
const pending = { ...completed, status: 'in_progress', terminal: false, threshold: null }
if (!terminalStatuses.has(completed.status) || terminalStatuses.has(pending.status) || pending.terminal) fail('polling lifecycle')

const strictGate = (receipt, worstTransition, findings) => (
  receipt.ok === true &&
  receipt.status === 'completed' &&
  receipt.terminal === true &&
  worstTransition.status === 'pass' &&
  findings.every(finding => (
    finding.blocking === false &&
    finding.classification === 'intended_change'
  ))
)
const highAverageWithBlocker = [{ transitionId: transition.id, classification: 'accidental_drift', blocking: true }]
if (strictGate({ ...completed, evaluation: { ...completed.evaluation, average: 0.99 } }, { status: 'pass' }, highAverageWithBlocker)) fail('blocking finding must win over average')
const declaredChange = [{ transitionId: transition.id, classification: 'intended_change', blocking: false }]
if (!strictGate(completed, { status: 'pass' }, declaredChange)) fail('declared change should not block')
if (strictGate(completed, { status: 'pass' }, [{ transitionId: transition.id, classification: 'intended_change', blocking: true }])) fail('blocking intended change must still block')
if (strictGate(completed, { status: 'pass' }, [{ transitionId: transition.id, classification: 'unknown', blocking: false }])) fail('unknown finding classification must fail closed')
if (strictGate({ ...completed, status: 'failed' }, { status: 'pass' }, [])) fail('failed run must not pass')

console.log('OK: modern evaluation request, ordered evidence, profile routing, polling, and strict gate contract')
NODE
