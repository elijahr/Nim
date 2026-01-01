# PR4: Support header pragma with generic type parameters

**Base:** `feature/deferred-importc-pragma` (PR3)
**Branch:** `feature/deferred-header-pragma`

---

This PR extends the deferred pragma infrastructure to support the `header` pragma with compile-time expressions, enabling dynamic header selection based on generic type parameters.

## Summary

1. **Computed header paths**: The `header` pragma now accepts compile-time expressions that compute the C/C++ header path based on type parameters
2. **Per-instantiation headers**: Different generic instantiations can include different headers

## Example

```nim
# Compute header based on type
proc getHeader(T: typedesc): string {.compileTime.} =
  when T is int32: "<cstdint>"
  elif T is float64: "<cmath>"
  else: "<cstdlib>"

type
  GenericType[T] {.importc: "GenericType",
                   header: getHeader(T),
                   completeStruct.} = object

# GenericType[int32] includes <cstdint>
# GenericType[float64] includes <cmath>
var a: GenericType[int32]
var b: GenericType[float64]
```

## Use Cases

### Platform-Specific Headers

Select headers based on type characteristics:

```nim
proc getSizedHeader(T: typedesc): string {.compileTime.} =
  when sizeof(T) <= 4: "<stdint.h>"
  else: "<inttypes.h>"

type SizedType[T] {.importc, header: getSizedHeader(T), completeStruct.} = object
```

### C++ Standard Library Wrappers

Use appropriate STL headers for different container types:

```nim
proc getContainerHeader(T: typedesc): string {.compileTime.} =
  when T is int32: "<vector>"
  elif T is float64: "<array>"
  else: "<deque>"

type Container[T] {.importcpp: "Container<'0>",
                    header: getContainerHeader(T),
                    completeStruct.} = object
```

### Complete C++ Type Wrapping

Combined with the other deferred pragmas for complete C++ type interop:

```nim
proc atomicHeader(T: typedesc): string {.compileTime.} =
  "<atomic>"

type
  Atomic[T] {.importcpp: "std::atomic",
              header: atomicHeader(T),
              size: sizeof(T),
              align: alignof(T),
              completeStruct.} = object
```

## Implementation

**Pragma processing** (`pragmas.nim`):
- Modified `wHeader` handler to detect type-level pragmas
- Added deferred expression check via `containsUnresolvedIdent`
- Deferred expressions stored on type via `setDeferredExpr`
- Immediate evaluation for non-generic contexts

**Instantiation** (`semtypinst.nim`):
- Added `wHeader` case to `applyDeferredPragma`
- Creates lib entry with evaluated header path
- Adds instantiated type to appropriate lib

## Tests

- `tests/pragmas/tdeferred_header.nim` - Header pragma with compile-time expressions

## Dependencies

- Requires PR3 (`feature/deferred-importc-pragma`) which includes PR1 and PR2's infrastructure

---

## Series Summary

| PR | Branch | Focus | Lines (net) |
|----|--------|-------|-------------|
| PR1 | `feature/deferred-size-pragma` | Infrastructure + `size` pragma | +441 |
| PR2 | `feature/deferred-align-pragma` | `align` pragma (type + field) | +172 |
| PR3 | `feature/deferred-importc-pragma` | `importc`/`importcpp` pragmas | +300 |
| PR4 | `feature/deferred-header-pragma` | `header` pragma | +170 |

Together these PRs enable complete generic wrapping of C/C++ types with dynamic headers:

```nim
proc getAtomicHeader(T: typedesc): string {.compileTime.} = "<atomic>"

type
  Atomic[T] {.importcpp: "std::atomic",
              header: getAtomicHeader(T),
              size: sizeof(T),
              align: alignof(T),
              completeStruct.} = object
```
