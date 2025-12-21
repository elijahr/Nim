# PR: Implement cycle detection for recursive concepts

## Title
`fixes #17630, #8558; implement cycle detection for recursive concepts`

## Description

Implements proper cycle detection for concept matching, enabling recursive concept definitions.

### Problem

The current implementation has a workaround that gives up after one level of recursion:

```nim
if m.depthCount > 0:
  # concepts that are more then 2 levels deep are treated like
  # tyAnything to stop dependencies from getting out of control
  return true
```

This prevents legitimate recursive concepts like:

```nim
type
  Trivial = concept x
    x is int or distinctBase(x) is Trivial
```

### Solution

- Track `(conceptId, typeId)` pairs during matching using the existing (but unused) `marker` field
- When a cycle is detected, return `true` (coinductive semantics - assume match)
- Changed `marker` from `IntSet` to `HashSet[ConceptTypePair]` to avoid XOR hash collisions
- Removed unused `depthCount` field

### Changes

**`compiler/concepts.nim`**
- Added `ConceptTypePair = tuple[conceptId, typeId: int]`
- Changed `marker: IntSet` to `marker: HashSet[ConceptTypePair]`
- Implemented cycle detection in `matchConceptToImpl`
- Removed `depthCount` field

**`doc/manual.md`**
- Documented recursive concepts feature

**`tests/concepts/trecursive_concepts.nim`**
- Tests for recursive concepts with `distinctBase`
- Tests for deep distinct chains (5+ levels)
- Tests for mutually recursive (co-dependent) concepts

### Backward Compatibility

- Mutually-referencing concepts (e.g., `Buffer` requiring `Writable` and vice versa) continue to work
- The cycle detection returns `true` on cycle, preserving the original behavior for co-dependent concepts
