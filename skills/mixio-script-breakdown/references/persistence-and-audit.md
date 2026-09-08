# Breakdown persistence and relational audit example

Use this example after resolving the project and episode scope. It demonstrates the composed
path's two hard boundaries: reference policy decides whether an unmatched entity can be written,
and IDs come from refreshed live context and persisted shots, never a hand-written UUID.

```javascript
const { settings = {} } = await studio_get_project({ projectId })
const createPolicy = settings.references?.createPolicy ?? "allow"
const aliasMatching = settings.references?.aliasMatching === true
const initialContext = await studio_get_production_context({ projectId, episodeId })

const normalized = value => value.trim().toLocaleUpperCase()
const keyFor = ({ type, name }) => `${type}:${normalized(name)}`
const referenceEntries = ({ canonical }) => [
  ...canonical.characters.map(item => ({ type: "CHARACTER", ...item })),
  ...canonical.locations.map(item => ({ type: "LOCATION", ...item })),
  ...canonical.props.map(item => ({ type: "PROP", ...item }))
]
const asArray = value => Array.isArray(value) ? value : value ? [value] : []
const namesFor = item => [
  item.name,
  ...(aliasMatching ? [...asArray(item.aka), ...asArray(item.aliases)] : [])
]
const initialReferences = new Set(referenceEntries(initialContext).flatMap(item =>
  namesFor(item).map(name => keyFor({ type: item.type, name }))
))

// Produced by the deterministic screenplay pass. It may include existing references; registration
// is needed only for the subset not already present in the initial context.
const extractedReferences = [
  { type: "CHARACTER", name: "TONY" },
  { type: "CHARACTER", name: "POPPY" },
  { type: "LOCATION", name: "TONY & POPPY'S BROOKLYN APARTMENT" },
  { type: "PROP", name: "TABLET" },
  { type: "PROP", name: "PHONE" }
]
const unmatched = extractedReferences.filter(item => !initialReferences.has(keyFor(item)))
if (unmatched.length && createPolicy !== "allow") {
  const action = createPolicy === "propose"
    ? "Surface this exact proposal and wait for approval"
    : "Ask the user to select an existing reference"
  throw new Error(`${action}; no reference, package, or relation write: ${JSON.stringify(unmatched)}`)
}
if (unmatched.length) {
  await studio_register_reference_entities({ projectId, references: unmatched })
}

// This read must occur after registration. Do not resolve IDs from initialContext: it predates
// any new elements and has no ID for them.
const { canonical } = await studio_get_production_context({ projectId, episodeId })

const allReferences = referenceEntries({ canonical })
const referenceIdByName = new Map(allReferences.flatMap(item =>
  namesFor(item).map(name => [keyFor({ type: item.type, name }), item.id])
))
const requiredId = (type, name) => {
  const id = referenceIdByName.get(keyFor({ type, name }))
  if (!id) throw new Error(`Missing ${type} reference: ${name}`)
  return id
}

const tonyId = requiredId("CHARACTER", "TONY")
const poppyId = requiredId("CHARACTER", "POPPY")
const apartmentId = requiredId(
  "LOCATION",
  "TONY & POPPY'S BROOKLYN APARTMENT"
)
const tabletId = requiredId("PROP", "TABLET")
const phoneId = requiredId("PROP", "PHONE")

const scenePackages = [{
  sceneNumber: 1,
  name: "INT. TONY & POPPY'S BROOKLYN APARTMENT — DAY",
  status: "breakdown",
  metadata: {
    heading: "INT. TONY & POPPY'S BROOKLYN APARTMENT — DAY",
    location: "TONY & POPPY'S BROOKLYN APARTMENT",
    timeOfDay: "DAY",
    scriptBody: "TONY drops her PHONE onto the BED, then takes the TABLET from POPPY.",
    screenplayLines: ["TONY drops her PHONE onto the BED, then takes the TABLET from POPPY."],
    dialogueLines: [],
    dialogueLinesRomanized: [],
    cameraNotes: "Dolly in from the foot of the bed.",
    directorNotes: "Keep the handoff readable.",
    transitionFromPrevious: "CUT TO",
    isContinuation: false
  },
  shots: [{
    shotNumber: 7,
    name: "Tony takes the tablet",
    metadata: {
      shot_type: "over_shoulder",
      camera_movement: "dolly_in",
      camera_angle: "eye_level",
      lens: "standard",
      subject: "TONY seated on the BED",
      action: "TONY drops her PHONE beside her, then takes the TABLET from POPPY [M2].",
      context: "TONY & POPPY'S BROOKLYN APARTMENT, DAY, warm sunlight through the WINDOWS",
      style_ambiance: "warm lived-in Brooklyn; long diagonal light shafts",
      lighting: "as Anchor 1",
      mood: "unguarded, domestic",
      blocking: "FG → TONY; MG → TABLET; BG → POPPY",
      duration: 4.5,
      audio: { ambient: "a truck downshifting outside" },
      character_links: ["TONY", "POPPY"],
      location_links: ["TONY & POPPY'S BROOKLYN APARTMENT"],
      prop_links: ["TABLET", "PHONE"],
      linked_character_ids: [tonyId, poppyId],
      linked_location_ids: [apartmentId],
      linked_prop_ids: [tabletId, phoneId]
    }
  }]
}]

const upsertResult = await studio_upsert_scene_packages({
  projectId,
  episodeId,
  scenes: scenePackages
})

const persistedScene = upsertResult.scenes?.find(scene => scene.sceneNumber === 1)
const persistedShot = persistedScene?.shots?.find(shot => shot.shotNumber === 7)
if (!persistedShot?.id) {
  throw new Error("studio_upsert_scene_packages did not return the persisted shot id")
}
const shotId = persistedShot.id

const appearanceRelations = [
  {
      fromId: tonyId,
      toId: shotId,
      relationType: "appears_in",
      metadata: {
        wardrobe: "oversized grey crewneck, faded denim shorts",
        condition: "rested, unblemished",
        carriedProps: ["PHONE"],
        hairState: "loose natural curls, parted center",
        continuityNotes: "sets PHONE down at [M2]"
      }
  },
  {
      fromId: poppyId,
      toId: shotId,
      relationType: "appears_in",
      metadata: {
        wardrobe: "structured olive blazer, white silk camisole",
        condition: "pristine, sharp",
        carriedProps: ["TABLET"],
        hairState: "sleek high ponytail",
        continuityNotes: "extends TABLET across the bed"
      }
  }
]

await studio_link_graph({
  projectId,
  relations: appearanceRelations
})
```

If the upsert response does not include nested IDs, make a scoped SHOT lookup by `episodeId`,
scene number, and shot number, verify exactly one match, and use that returned ID. Do not proceed
with an invented ID or an unverified relation target.

## Persisted relational-audit proof

`scenePackages` is the deterministic screenplay-beat plan: it is built from the selected
screenplay before the write. Compare that plan with the package response and relation reads. If a
package response does not contain a complete persisted scene/shot record, fetch scoped `SCENE` and
`SHOT` elements first; never audit the authored request as though it were a persisted read.

```javascript
const persistedScenes = upsertResult.scenes ?? []
const persistedShots = persistedScenes.flatMap(scene => scene.shots ?? [])
if (persistedShots.some(shot => !shot.id)) {
  throw new Error("Read scoped persisted shots before the relational audit")
}

const expectedShots = scenePackages.flatMap(scene => scene.shots ?? [])
const expectedShotCount = expectedShots.length
const expectedTotalDuration = expectedShots.reduce(
  (sum, shot) => sum + Number(shot.metadata?.duration), 0
)
const totalDuration = persistedShots.reduce(
  (sum, shot) => sum + Number(shot.metadata?.duration), 0
)
const durationDelta = totalDuration - expectedTotalDuration

const placeholder = new Set(["", "tbd", "n/a", "na", "unknown", "none", "null"])
const isConcrete = value =>
  typeof value === "string" && !placeholder.has(value.trim().toLowerCase())
const canonicalFields = [
  "shot_type", "camera_movement", "subject", "action", "context", "style_ambiance", "duration"
]
const canonicalFieldFailures = persistedShots.flatMap(shot =>
  canonicalFields
    .filter(field => field === "duration"
      ? !Number.isFinite(Number(shot.metadata?.[field])) || Number(shot.metadata[field]) < 1 || Number(shot.metadata[field]) > 60
      : !isConcrete(shot.metadata?.[field]))
    .map(field => `${shot.id}:${field}`)
)

const validReferenceIds = new Set(allReferences.map(item => item.id))
const linkSpecs = [
  ["CHARACTER", "character_links", "linked_character_ids"],
  ["LOCATION", "location_links", "linked_location_ids"],
  ["PROP", "prop_links", "linked_prop_ids"]
]
const graphFailures = persistedShots.flatMap(shot => linkSpecs.flatMap(([type, namesKey, idsKey]) => {
  const names = Array.isArray(shot.metadata?.[namesKey]) ? shot.metadata[namesKey] : []
  const ids = Array.isArray(shot.metadata?.[idsKey]) ? shot.metadata[idsKey] : []
  const nameFailures = names.flatMap(name => {
    const expectedId = referenceIdByName.get(keyFor({ type, name }))
    return expectedId && ids.includes(expectedId) ? [] : [`${shot.id}:${namesKey}:${name}`]
  })
  const orphanIds = ids.filter(id => !validReferenceIds.has(id)).map(id => `${shot.id}:${idsKey}:${id}`)
  return [...nameFailures, ...orphanIds]
}))

const appearanceReads = await Promise.all(persistedShots.map(shot =>
  studio_query_relations({ projectId, toId: shot.id, relationType: "appears_in", limit: 200 })
))
const persistedAppearances = appearanceReads.flatMap(result => result.results ?? [])
const appearanceByPair = new Map(persistedAppearances.map(relation => [
  `${relation.fromId}:${relation.toId}`, relation
]))
const expectedAppearances = persistedShots.flatMap(shot =>
  (Array.isArray(shot.metadata?.linked_character_ids) ? shot.metadata.linked_character_ids : [])
    .map(characterId => ({ characterId, shotId: shot.id }))
)
const appearanceFailures = expectedAppearances.flatMap(({ characterId, shotId }) => {
  const relation = appearanceByPair.get(`${characterId}:${shotId}`)
  return relation && isConcrete(relation.metadata?.wardrobe) && isConcrete(relation.metadata?.condition) &&
    Array.isArray(relation.metadata?.carriedProps) ? [] : [`${characterId}:${shotId}`]
})

const scopeFailures = []
if (persistedShots.length !== expectedShotCount) scopeFailures.push("shot_count")
if (Math.abs(durationDelta) > 0.01) scopeFailures.push("duration")
const audit = {
  total_scenes: persistedScenes.length,
  total_shots: persistedShots.length,
  total_duration: totalDuration,
  expected_shot_count: expectedShotCount,
  expected_total_duration: expectedTotalDuration,
  duration_delta: durationDelta,
  canonical_fields_complete: canonicalFieldFailures.length === 0,
  canonical_field_failures: canonicalFieldFailures.length,
  cast_world_links_valid: graphFailures.length === 0,
  unresolved_entities: graphFailures.length,
  appearance_states_bound: expectedAppearances.length,
  appearance_state_failures: appearanceFailures.length
}
if (canonicalFieldFailures.length || graphFailures.length || appearanceFailures.length || scopeFailures.length) {
  throw new Error(`Relational audit failed: ${JSON.stringify({ audit, canonicalFieldFailures, graphFailures, appearanceFailures, scopeFailures })}`)
}

await studio_update_episode({
  episodeId,
  updates: {
    metadata: {
      pipeline: {
        step_03: "complete",
        breakdown_audit: {
          total_scenes: persistedScenes.length,
          total_shots: persistedShots.length,
          total_duration: totalDuration,
          expected_shot_count: expectedShotCount,
          expected_total_duration: expectedTotalDuration,
          duration_delta: durationDelta,
          canonical_fields_complete: canonicalFieldFailures.length === 0,
          canonical_field_failures: canonicalFieldFailures.length,
          cast_world_links_valid: graphFailures.length === 0,
          unresolved_entities: graphFailures.length,
          appearance_states_bound: expectedAppearances.length,
          appearance_state_failures: appearanceFailures.length
        }
      }
    }
  }
})
```
