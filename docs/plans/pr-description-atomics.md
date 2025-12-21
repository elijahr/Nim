# PR: Improved atomics with size-based lock-free detection

## Title
`std/atomics: size-based lock-free detection; support small objects/tuples`

## Description

Rewrites `std/atomics` to use `sizeof` and `supportsCopyMem` for lock-free eligibility instead of a fixed type list (`Trivial`). This enables small objects and tuples to use hardware atomic operations.

### Changes

**1. Lock-free criteria now based on:**
- `sizeof(T) <= maxLockFreeSize` (pointer size: 8 bytes on 64-bit, 4 on 32-bit)
- `supportsCopyMem(T)` - no managed memory (no GC refs)
- With `--mm:atomicArc` or `--mm:none`: managed types also qualify

**2. New public API:**
- `maxLockFreeSize*: int` - maximum byte size for lock-free atomics
- `isLockFree*(T: typedesc): bool` - compile-time check for lock-free eligibility
- `-d:nimEnforceLockFreeAtomics` - compile error instead of spinlock fallback

**3. Expanded lock-free support:**
```nim
# These now use lock-free atomics:
type Point = object
  x, y: int32  # 8 bytes, no managed memory

var p: Atomic[Point]
p.store(Point(x: 10, y: 20))  # Hardware atomic!

type Pair = tuple[a, b: int32]
var t: Atomic[Pair]  # Also lock-free!

# Distinct types still work:
type MyInt = distinct int
var a: Atomic[MyInt]  # Lock-free
```

**4. Removed `Trivial` concept:**
The old `Trivial` type class was replaced with inline `when` checks using `sizeof` and `supportsCopyMem`. This is simpler and more flexible.

### Why `supportsCopyMem`?

Managed types (`ref`, `string`, `seq`) bypass GC write barriers when stored atomically, which can cause:
- Use-after-free
- Memory leaks
- Double-free

The `supportsCopyMem` check excludes these types unless `--mm:atomicArc` (atomic refcounting) or `--mm:none` (no GC) where it's safe.

### Testing

- Added `isLockFree` tests for various types
- Added small object and tuple atomic tests
- All existing atomics tests pass across configurations:
  - `--mm:orc`, `--mm:refc`
  - C and C++ backends
  - `-d:nimUseCppAtomics`

### Backward Compatibility

- All existing code continues to work
- Types that were lock-free before remain lock-free
- New types (small objects/tuples) gain lock-free performance
- The `Trivial` type is no longer exported but was internal implementation detail
