# PR2: Support align pragma with generic type parameters

**Base:** `feature/deferred-size-pragma` (PR1)
**Branch:** `feature/deferred-align-pragma`

---

This PR extends the deferred pragma infrastructure (from PR1) to support the `align` pragma with generic type parameters, including a new capability: type-level alignment for imported types.

## Summary

1. **Type-level align pragma**: The `align` pragma is now valid on type definitions, not just fields and variables
2. **Field-level deferred align**: Field alignment can use expressions like `alignof(T)`
3. **Deferred evaluation**: Align expressions are evaluated during generic instantiation

## Example

```nim
type
  # Type-level alignment based on generic parameter
  GenericAligned[T] {.importc, size: sizeof(T),
                      align: alignof(T), completeStruct.} = object

  # Field-level alignment
  Container[T] = object
    header: int32
    data {.align: alignof(T).}: T

static:
  doAssert alignof(GenericAligned[int64]) >= alignof(int64)
```

## Use Cases

### Proper C++ Template Type Wrapping

Combined with PR1's size pragma, this enables complete C++ template wrapping:

```nim
type
  # C++ std::atomic wrapper with correct size AND alignment
  Atomic[T] {.importcpp: "std::atomic", header: "<atomic>",
              size: sizeof(T), align: alignof(T), completeStruct.} = object
```

### SIMD and Hardware-Aligned Types

Generic SIMD wrappers with correct platform-specific alignment:

```nim
type
  SimdVector[T; N: static int] {.importc,
    size: sizeof(T) * N,
    align: sizeof(T) * N,  # SIMD typically requires alignment = size
    completeStruct.} = object
```

### Generic Containers with Aligned Storage

```nim
type
  AlignedBuffer[T] = object
    len: int
    data {.align: alignof(T).}: UncheckedArray[T]
```

## Implementation

**Pragma processing** (`pragmas.nim`):
- `wAlign` added to `typePragmas` set (previously only in `fieldPragmas`/`varPragmas`)
- Modified `wAlign` handler to support both type-level and field-level deferred expressions
- Power-of-2 validation for alignment values

**Instantiation** (`semtypinst.nim`):
- Added `wAlign` case to `applyDeferredPragma` for type-level alignment
- New `applyDeferredFieldPragma`: Evaluates field-level deferred pragmas
- New `evaluateDeferredFieldPragmas`: Orchestrates field pragma evaluation
- Integration with `replaceTypeVarsN` for field processing

## Tests

- `tests/pragmas/tdeferred_align.nim` - Align pragma at type and field level

## Dependencies

- Requires PR1 (`feature/deferred-size-pragma`) for deferred pragma infrastructure
