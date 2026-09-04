# Breakdown persistence and relational audit example

Use this example after resolving the project and episode scope. It demonstrates the important
part of the composed path: IDs come from the live context and the persisted shot, never from a
hand-written UUID.

```javascript
const { canonical } = await studio_get_production_context({ projectId, episodeId })

const requiredId = (items, name, type) => {
  const match = items.find(item => item.name === name)
  if (!match?.id) throw new Error(`Missing ${type} reference: ${name}`)
  return match.id
}

const tonyId = requiredId(canonical.characters, "TONY", "CHARACTER")
const poppyId = requiredId(canonical.characters, "POPPY", "CHARACTER")
const apartmentId = requiredId(
  canonical.locations,
  "TONY & POPPY'S BROOKLYN APARTMENT",
  "LOCATION"
)
const tabletId = requiredId(canonical.props, "TABLET", "PROP")
const phoneId = requiredId(canonical.props, "PHONE", "PROP")

const upsertResult = await studio_upsert_scene_packages({
  projectId,
  episodeId,
  scenes: [{
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

## Runtime and audit proof

Before reporting a pass, read the episode and require the planned runtime set by preflight or the
user:

```javascript
const episode = await studio_get_episode({ episodeId })
const plannedRuntimeSeconds = Number(episode.metadata?.pipeline?.planned_runtime_seconds)
if (!Number.isFinite(plannedRuntimeSeconds) || plannedRuntimeSeconds <= 0) {
  throw new Error("planned_runtime_seconds is required before the breakdown audit")
}

const persistedScenes = upsertResult.scenes ?? []
const persistedShots = persistedScenes.flatMap(scene => scene.shots ?? [])
const appearanceStateCount = appearanceRelations.length
const totalDuration = persistedShots.reduce((sum, shot) => sum + shot.metadata.duration, 0)
const durationDelta = totalDuration - plannedRuntimeSeconds
if (Math.abs(durationDelta) > 0.01) {
  throw new Error(`Shot duration does not match planned runtime: ${durationDelta}s`)
}
```

The emitted audit must include `total_duration`, `planned_runtime_seconds`, `duration_delta`,
shot count, resolved entity counts, and appearance-state coverage. Persist the proof only after
all four checks pass: canonical fields, graph IDs, appearance state, and scope duration.

```javascript
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
          planned_runtime_seconds: plannedRuntimeSeconds,
          duration_delta: durationDelta,
          canonical_fields_complete: true,
          cast_world_links_valid: true,
          unresolved_entities: 0,
          appearance_states_bound: appearanceStateCount
        }
      }
    }
  }
})
```
