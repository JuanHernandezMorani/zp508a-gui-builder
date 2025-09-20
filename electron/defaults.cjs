const ZP508a_DEFAULTS = Object.freeze({
  zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  human_class: { health: 100, speed: 240, gravity: 1.0, armor: 0 },
  special_zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  special_human_class: { health: 100, speed: 240, gravity: 1.0, armor: 0 }
})

function createDefaultTracker() {
  return {
    applied: new Set(),
    overridden: new Set()
  }
}

function ensureDefaultTracker(entity) {
  if (!entity || typeof entity !== 'object') return createDefaultTracker()
  if (!entity.meta || typeof entity.meta !== 'object') entity.meta = {}
  const tracker = entity.meta.defaultTracker
  if (
    tracker &&
    tracker.applied instanceof Set &&
    tracker.overridden instanceof Set
  ) {
    return tracker
  }
  const fresh = createDefaultTracker()
  entity.meta.defaultTracker = fresh
  return fresh
}

function applyDefaultsToEntity(entity) {
  if (!entity || typeof entity !== 'object') return []
  if (!entity.stats || typeof entity.stats !== 'object') entity.stats = {}
  const defaults = ZP508a_DEFAULTS[entity.type]
  if (!defaults) return []
  const tracker = ensureDefaultTracker(entity)
  const applied = []
  for (const [field, value] of Object.entries(defaults)) {
    const current = entity.stats[field]
    if (current === undefined || current === null || Number.isNaN(current)) {
      entity.stats[field] = value
      tracker.applied.add(field)
      tracker.overridden.delete(field)
      applied.push(field)
    }
  }
  return applied
}

function markDefaultOverridden(entity, field) {
  if (!entity || !field) return false
  const tracker = ensureDefaultTracker(entity)
  if (tracker.applied.has(field)) {
    tracker.applied.delete(field)
    tracker.overridden.add(field)
    return true
  }
  return false
}

function finalizeDefaultMeta(entity) {
  if (!entity || !entity.meta) return
  const tracker = entity.meta.defaultTracker
  if (!tracker) return
  const applied = tracker.applied instanceof Set ? Array.from(tracker.applied) : []
  const overridden = tracker.overridden instanceof Set ? Array.from(tracker.overridden) : []
  if (applied.length || overridden.length) {
    if (!Array.isArray(entity.meta.extraCalls)) entity.meta.extraCalls = []
    if (applied.length) {
      entity.meta.extraCalls.push({ type: 'defaultApplied', fields: applied })
    }
    if (overridden.length) {
      entity.meta.extraCalls.push({ type: 'defaultOverridden', fields: overridden })
    }
  }
  delete entity.meta.defaultTracker
}

module.exports = {
  ZP508a_DEFAULTS,
  createDefaultTracker,
  ensureDefaultTracker,
  applyDefaultsToEntity,
  markDefaultOverridden,
  finalizeDefaultMeta
}
