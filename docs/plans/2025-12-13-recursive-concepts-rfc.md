# RFC: Cycle Detection for Recursive Concept Matching

## Abstract

Enable concepts to reference themselves (directly or indirectly) during type matching by implementing proper cycle detection, replacing the current depth-limit bail-out that treats nested concepts as `tyAnything`. This allows patterns like recursive `distinctBase` unwrapping in concept definitions.

## Motivation

### The Problem

Currently, Nim's concept system cannot properly handle recursive type constraints. This limitation prevents expressing patterns like:

```nim
type
  TrivialBase = SomeNumber | bool | enum | ptr | pointer | char

  Trivial = concept x
    x is TrivialBase or distinctBase(x) is Trivial  # Recursive!
```

This pattern is useful for the `atomics` module where we want `Atomic[T]` to use lock-free operations when `T` is "trivial" - including `distinct` types that wrap trivial types at any nesting depth.

### Who Benefits

- Library authors who need to express recursive type constraints
- Users of `distinct` types who want them to inherit concept membership from their base types
- The `atomics` module specifically, which needs to distinguish lock-free-compatible types

### Current Behavior

In `compiler/concepts.nim` lines 191-194, when concept matching recurses more than one level deep, the compiler gives up and returns `true` (match), effectively treating the nested concept as `tyAnything`:

```nim
if m.depthCount > 0:
  # concepts that are more then 2 levels deep are treated like
  # tyAnything to stop dependencies from getting out of control
  return true
```

This defeats the purpose of type constraints and can cause false matches.

### Evidence of Intent

The `MatchCon` object already has an unused field that was clearly intended for cycle detection:

```nim
MatchCon = object
  bindings: LayeredIdTable
  marker: IntSet  ## Some protection against wild runaway recursions. <-- NEVER USED
  ...
  depthCount = 0  # <-- Current workaround
```

## Description

### Proposed Solution

Replace the depth-limit bail-out with proper cycle detection using a `HashSet` of `(conceptId, typeId)` pairs.

### Algorithm

1. Before checking if type `T` matches concept `C`, create a pair `(C.id, T.id)`
2. If this pair is already in the marker set, we've detected a cycle - return `true` (coinductive match)
3. Otherwise, add the pair to the marker set, proceed with matching, then remove it (backtrack)

### Why Coinductive (return `true` on cycle)?

We return `true` on cycle detection rather than `false` because:

1. **Co-dependent concepts require it**: Concepts like `Buffer <-> Writable` that reference each other would fail to match with `false` semantics
2. **Backward compatibility**: The old depth-limit bail-out returned `true`, so existing code continues to work
3. **Recursive distinctBase still works**: When checking `distinct int is Trivial`, the recursion goes `distinct int -> int -> (base case)`, so the types change and cycle detection doesn't trigger until we hit the base case

### Implementation Details

**Change marker type** from `IntSet` to `HashSet[ConceptTypePair]` to avoid XOR collision risk:

```nim
type
  ConceptTypePair = tuple[conceptId, typeId: int]

  MatchCon = object
    bindings: LayeredIdTable
    marker: HashSet[ConceptTypePair]  # Tracks (concept, type) pairs being checked
    # ... rest of fields
```

**Replace depth check** with cycle detection:

```nim
proc matchConceptToImpl(c: PContext, f, potentialImpl: PType; m: var MatchCon): bool =
  let concpt = f.reduceToBase
  let pair: ConceptTypePair = (concpt.id, potentialImpl.id)

  if pair in m.marker:
    # Cycle detected - return true (coinductive)
    return true
  m.marker.incl pair

  # ... do matching ...

  m.marker.excl pair  # backtrack
```

**Remove `depthCount`** field entirely - cycle detection fully replaces it.

### Termination Guarantee

For well-formed recursive concepts like:

```nim
Trivial = concept x
  x is TrivialBase or distinctBase(x) is Trivial
```

The recursion is guaranteed to terminate because:
- `distinctBase(T)` strictly reduces type complexity (unwraps one layer)
- Eventually reaches a ground type (e.g., `int`) that either matches `TrivialBase` or doesn't
- Malformed types like `type Weird = distinct Weird` are caught by cycle detection

## Code Examples

### Basic Recursive Concept with distinctBase

```nim
import std/typetraits

type
  TrivialBase = SomeInteger | bool | char | ptr | pointer

  Trivial = concept x
    x is TrivialBase or distinctBase(x) is Trivial

  MyInt = distinct int
  MyMyInt = distinct MyInt
  DeepInt = distinct MyMyInt

# All should match:
doAssert int is Trivial
doAssert MyInt is Trivial
doAssert MyMyInt is Trivial
doAssert DeepInt is Trivial

# Should NOT match:
doAssert not(float is Trivial)
doAssert not(string is Trivial)
```

### 3-Way Mutual Recursion (Co-dependent Concepts)

```nim
type
  ConceptA = concept
    proc toB(x: Self): ConceptB

  ConceptB = concept
    proc toC(x: Self): ConceptC

  ConceptC = concept
    proc toA(x: Self): ConceptA

  Chain = object
    value: int

proc toB(x: Chain): Chain = x
proc toC(x: Chain): Chain = x
proc toA(x: Chain): Chain = x

# Chain satisfies all three mutually recursive concepts:
doAssert Chain is ConceptA
doAssert Chain is ConceptB
doAssert Chain is ConceptC
```

### Deep Distinct Chains (5+ levels)

```nim
type
  Base = SomeInteger

  DeepTrivial = concept x
    x is Base or distinctBase(x) is DeepTrivial

  D1 = distinct int
  D2 = distinct D1
  D3 = distinct D2
  D4 = distinct D3
  D5 = distinct D4

doAssert D5 is DeepTrivial  # Unwraps 5 levels to reach int
```

## Backwards Compatibility

This change is **backwards compatible** with one exception:

**Changed behavior**: Code that previously relied on deep concept nesting returning `true` (accepting everything as `tyAnything`) will now get accurate matching. This is a bug fix, not a breaking change, but could surface latent type errors in existing code that accidentally depended on the loose matching.

**Co-dependent concepts continue to work**: The coinductive semantics (return `true` on cycle) preserves the original behavior for patterns like `Buffer <-> Writable`.

## Links

- [Nim RFC #168: Concepts and Type Checking](https://github.com/nim-lang/RFCs/issues/168) - Original concepts RFC
- [Issue #17630: Recursive Concepts Cause Compiler Segfault](https://github.com/nim-lang/Nim/issues/17630) - Related crash bug
- [Issue #8558: Compiler Stack Overflow With Recursive Functions Using Concepts](https://github.com/nim-lang/Nim/issues/8558) - Related recursion issue
- [Rust Internals: Recursive Trait Bounds](https://internals.rust-lang.org/t/recursive-trait-bounds/5265) - How Rust handles this (they prohibit it)

## Implementation

A working implementation is available on the `concepts-cycle-detection` branch, including:
- `compiler/concepts.nim` changes (~50 lines)
- `tests/concepts/trecursive_concepts.nim` comprehensive test suite
