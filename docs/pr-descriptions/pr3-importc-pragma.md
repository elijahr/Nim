# PR3: Support importc/importcpp pragmas with generic type parameters

**Base:** `feature/deferred-align-pragma` (PR2)
**Branch:** `feature/deferred-importc-pragma`

---

This PR extends the deferred pragma infrastructure to support `importc` and `importcpp` pragmas with compile-time expressions, completing the deferred pragma feature set.

## Summary

1. **Computed external names**: The `importc` and `importcpp` pragmas now accept compile-time expressions that compute the C/C++ identifier based on type parameters
2. **Generic type family wrapping**: A single generic Nim type can wrap multiple related C/C++ types

## Example

```nim
# Computed C type names (proc must be outside type block)
proc cTypeName(T: typedesc): string {.compileTime.} =
  when T is int8: "int8_t"
  elif T is int16: "int16_t"
  elif T is int32: "int32_t"
  elif T is int64: "int64_t"
  else: "int"

type
  CInt[T] {.importc: cTypeName(T), size: sizeof(T), completeStruct.} = object

# Each instantiation imports the corresponding C type
var i8: CInt[int8]    # imports "int8_t"
var i32: CInt[int32]  # imports "int32_t"
```

## Use Cases

### Generic C Type Family Wrappers

Wrap families of related C types with a single generic Nim type:

```nim
proc cIntType(T: typedesc): string {.compileTime.} =
  when T is int8: "int8_t"
  elif T is int32: "int32_t"
  elif T is int64: "int64_t"
  else: "int"

type CInt[T] {.importc: cIntType(T), size: sizeof(T), completeStruct.} = object
```

### C++ Template Instantiation Names

Generate correct C++ template instantiation names:

```nim
proc cppVectorName(T: typedesc): string {.compileTime.} =
  when T is int32: "std::vector<int>"
  elif T is float64: "std::vector<double>"
  else: "std::vector<void*>"

type
  Vector[T] {.importcpp: cppVectorName(T), header: "<vector>".} = object
```

### Platform-Specific Type Names

Handle platform differences in type naming:

```nim
proc platformSizeT(T: typedesc): string {.compileTime.} =
  when sizeof(pointer) == 8: "uint64_t"
  else: "uint32_t"

type SizeT {.importc: platformSizeT(pointer), size: sizeof(pointer).} = object
```

## Implementation

**Pragma processing** (`pragmas.nim`):
- New `expectString` helper template for validating string constants
- Modified `wImportc` handler to support deferred evaluation for type-level pragmas
- Modified `wImportCpp` handler to support deferred evaluation for type-level pragmas

**Instantiation** (`semtypinst.nim`):
- Added `wImportc` and `wImportCpp` cases to `applyDeferredPragma`
- String extraction and validation from evaluated expressions
- Proper external name setting on instantiated types

## Tests

- `tests/pragmas/tdeferred_importc.nim` - Importc/importcpp with compile-time expressions

## Dependencies

- Requires PR2 (`feature/deferred-align-pragma`) which includes PR1's infrastructure

---

## Series Summary

| PR | Branch | Focus | Lines (net) |
|----|--------|-------|-------------|
| PR1 | `feature/deferred-size-pragma` | Infrastructure + `size` pragma | +441 |
| PR2 | `feature/deferred-align-pragma` | `align` pragma (type + field) | +172 |
| PR3 | `feature/deferred-importc-pragma` | `importc`/`importcpp` pragmas + refactoring | +300 |

Together these PRs enable complete generic wrapping of C/C++ types:

```nim
type
  Atomic[T] {.importcpp: "std::atomic", header: "<atomic>",
              size: sizeof(T), align: alignof(T), completeStruct.} = object
```
