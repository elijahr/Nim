**Title:** std/atomics: lock-free for any 1/2/4/8/16-byte type, not just Trivial

**Body:**

Changes `std/atomics` to determine lock-free eligibility by size, `supportsCopyMem`, architecture, and memory management rather than by type.

Previously, only `Trivial` types (`SomeNumber | bool | enum | ptr | pointer`) could use lock-free atomics. Any other type (small objects, char, etc) would fall back to spin-lock even though it could fit in a register.

Now, any type with `sizeof(T)` of 1, 2, 4, 8, or 16 bytes (with architecture support) and no managed memory (under ARC/ORC) uses lock-free atomics.

## Dependencies

This PR depends on #XXXX (sizeof-typedesc-fix) which fixes a compiler bug that blocked using `when isLockFree(T)` in the `Atomic[T]` body.

## Changes

- Replace `Trivial` type constraint with public `isLockFree(T)` template
- Add `hasLockFree8` constant for 8-byte atomic support
- Add `hasLockFree16` constant for 16-byte atomic support
- Add 128-bit atomic type (`Int128`) for 16-byte lock-free operations
- Add `-d:nimEnforceLockFreeAtomics` to error instead of silently falling back to spinlock
- Add `-d:nimNoLockFree16` to disable 16-byte lock-free for old x86-64 CPUs
- Document lock-free eligibility rules

## Architecture Support

### 8-byte atomics (`hasLockFree8`)

| Architecture | Supported | Instruction |
|--------------|-----------|-------------|
| All 64-bit   | ✅        | Native      |
| x86-32       | ✅        | CMPXCHG8B   |
| ARM32        | ✅        | LDREXD      |
| MIPS32       | ❌        | -           |
| PowerPC32    | ❌        | -           |
| SPARC32      | ❌        | -           |
| RISC-V 32    | ❌        | -           |

### 16-byte atomics (`hasLockFree16`)

| Architecture | Supported | Instruction |
|--------------|-----------|-------------|
| x86-64       | ✅        | CMPXCHG16B  |
| ARM64        | ✅        | LDXP/STXP   |
| Other 64-bit | ❌        | -           |
| All 32-bit   | ❌        | -           |

Note: Use `-d:nimNoLockFree16` if targeting very old x86-64 CPUs (pre-2005) that lack CMPXCHG16B.

## Lock-free eligibility by type and memory manager

| Type                     | refc | markAndSweep | none | arc | orc | atomicArc |
|--------------------------|------|--------------|------|-----|-----|-----------|
| int, bool, char, ptr     | ✅   | ✅           | ✅   | ✅  | ✅  | ✅        |
| enum, distinct           | ✅   | ✅           | ✅   | ✅  | ✅  | ✅        |
| Small object (1-4 bytes) | ✅   | ✅           | ✅   | ✅  | ✅  | ✅        |
| 8-byte object*           | ✅*  | ✅*          | ✅*  | ✅* | ✅* | ✅*       |
| 16-byte object**         | ✅** | ✅**         | ✅** | ✅**| ✅**| ✅**      |
| ref, string, seq         | ✅   | ✅           | ✅   | ❌  | ❌  | ❌        |
| Big object (>16 bytes)   | ❌   | ❌           | ❌   | ❌  | ❌  | ❌        |

\* Requires `hasLockFree8`
\*\* Requires `hasLockFree16`
