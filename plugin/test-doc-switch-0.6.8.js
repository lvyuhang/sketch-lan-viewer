#!/usr/bin/env node
'use strict'

// Mirrors shouldSuppressArtboardSwitch + applyDocumentContext semantics from 0.6.8 plugin.
function shouldSuppressArtboardSwitch(prevArtboardId, nextArtboardId, suppressedArtboardId, oldStillInDocument) {
  if (prevArtboardId == null || nextArtboardId == null) {
    return { suppress: false, suppressedArtboardId: suppressedArtboardId, reason: 'no-prev-or-next' }
  }
  if (String(nextArtboardId) === String(prevArtboardId)) {
    return { suppress: false, suppressedArtboardId: null, reason: 'same-artboard' }
  }
  if (suppressedArtboardId !== null && String(nextArtboardId) === String(suppressedArtboardId)) {
    return { suppress: true, suppressedArtboardId: suppressedArtboardId, reason: 'still-suppressed' }
  }
  if (!oldStillInDocument) {
    if (suppressedArtboardId === null) {
      return { suppress: true, suppressedArtboardId: String(nextArtboardId), reason: 'first-auto-jump-after-delete' }
    }
    return { suppress: false, suppressedArtboardId: null, reason: 'manual-after-suppress' }
  }
  return { suppress: false, suppressedArtboardId: suppressedArtboardId, reason: 'old-still-in-doc' }
}

function applyDocumentContext(state, documentId, opts) {
  opts = opts || {}
  if (!documentId) return false
  const id = String(documentId)
  const changed = state.currentDocumentId !== null && String(state.currentDocumentId) !== id
  if (changed || opts.forceReset) {
    state.lockSource = null
    state.suppressedArtboardId = null
    state.currentArtboardId = null
    state.currentPageId = null
    state.forceNextFrame = true
    state.dirty = true
  }
  state.currentDocumentId = id
  return changed
}

let passed = 0
function assert(cond, msg) {
  if (!cond) throw new Error('FAIL: ' + msg)
  passed++
  console.log('ok', msg)
}

// 1) Cross-document: after applyDocumentContext, prev cleared → never suppress
{
  const st = { currentDocumentId: 'docA', currentArtboardId: 'a1', suppressedArtboardId: null, lockSource: 'sketch', currentPageId: 'p1', forceNextFrame: false, dirty: false }
  assert(applyDocumentContext(st, 'docB', { reason: 'tab' }) === true, 'doc A→B changes')
  assert(st.currentArtboardId === null, 'clears sticky artboard')
  assert(st.suppressedArtboardId === null, 'clears suppress')
  assert(st.forceNextFrame === true, 'forces next frame')
  const d = shouldSuppressArtboardSwitch(st.currentArtboardId, 'b1', st.suppressedArtboardId, false)
  assert(d.suppress === false, 'cross-doc selection not suppressed')
}

// 2) True delete in same doc: first auto-jump suppressed
{
  const d = shouldSuppressArtboardSwitch('gone', 'auto1', null, false)
  assert(d.suppress === true && d.reason === 'first-auto-jump-after-delete', 'delete auto-jump suppressed')
  const d2 = shouldSuppressArtboardSwitch('gone', 'auto1', 'auto1', false)
  assert(d2.suppress === true && d2.reason === 'still-suppressed', 'stay suppressed on same auto id')
  const d3 = shouldSuppressArtboardSwitch('gone', 'manual2', 'auto1', false)
  assert(d3.suppress === false && d3.reason === 'manual-after-suppress', 'manual other id clears')
}

// 3) Cross-page same doc, old board still exists elsewhere → do not suppress
{
  const d = shouldSuppressArtboardSwitch('a1', 'a2', null, true)
  assert(d.suppress === false && d.reason === 'old-still-in-doc', 'cross-page manual ok')
}

// 4) 0.6.6 bug simulation: WITHOUT doc reset, old id missing on new page → false suppress
{
  const buggy = shouldSuppressArtboardSwitch('a1-from-docA', 'b1-from-docB', null, false)
  assert(buggy.suppress === true, 'demonstrates pre-0.6.7 false suppress without doc reset')
}

console.log('\nAll', passed, 'assertions passed')
