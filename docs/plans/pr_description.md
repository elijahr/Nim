Changes `std/atomics` to determine lock-free eligibility by size, `supportsCopyMem`, architecture, and memory management rather than by type.

Previously, only `Trivial` types (`SomeNumber | bool | enum | ptr | pointer`) could use lock-free atomics. Any other type (small objects, char, etc) would fall back to spin-lock even though it could fit in a register.

Now, any type with `sizeof(T)` of 1, 2, 4, 8, or 16 bytes (with architecture support) and no managed memory (under ARC/ORC) uses lock-free atomics.

## Changes

- Replace `Trivial` type constraint with public `isLockFree(T)` template
- Add `hasLockFree8` constant for 8-byte atomic support
- Add `hasLockFree16` constant for 16-byte atomic support
- Add 128-bit atomic type (`Int128`) for 16-byte lock-free operations
- Add `-d:nimEnforceLockFreeAtomics` to error instead of silently falling back to spinlock
- Add `-d:nimNoLockFree16` to disable 16-byte lock-free for old x86-64 CPUs
- Add `-d:nimUseCppAtomics` to use C++ `std::atomic` instead of C11 primitives
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

## Compiler Fix

This PR also fixes a bug in `compiler/semtypinst.nim` that blocked using `when isLockFree(T)` in the `Atomic[T]` body.

The issue was that when a generic type had a `when` clause that called a template with a `typedesc` parameter containing `sizeof(T)`:

```nim
template isLockFree(T: typedesc): bool =
  sizeof(T) <= 8

type Foo[T] = object
  when isLockFree(T):  # T is unresolved here
    a: T
  else:
    b: ptr T

proc bar[T](x: var Foo[T]) = discard

var x: Foo[int]
x.bar()  # triggers the bug
```

The compiler would error with: `'sizeof' requires '.importc' types to be '.completeStruct'`.

The root cause was that `hasValuelessStatics` checks whether a `when` condition contains unresolved generics that can't be evaluated yet. It checked for `tyStatic` but missed `tyTypeDesc(tyGenericParam)`, which is the type that occurs when a typedesc template parameter receives an unresolved generic type.

The fix is to add a check that unwraps `tyTypeDesc` to detect a wrapped `tyGenericParam`.
