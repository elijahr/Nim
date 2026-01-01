# PR1: Support size pragma with generic type parameters

**Base:** `devel`
**Branch:** `feature/deferred-size-pragma`

---

This PR implements **deferred pragma expressions** for the `size` pragma, establishing the infrastructure for deferred evaluation of pragma expressions in generic types.

## Summary

1. **Deferred evaluation infrastructure**: New `DeferredPragmaExpr` type and accessors for storing pragma expressions that reference generic type parameters
2. **Size pragma enhancement**: The `size` pragma now accepts expressions like `sizeof(T)` that are evaluated during generic instantiation
3. **Feature detection**: Use `defined(nimHasDeferredPragmas)` to check for this feature

## Example

```nim
type
  # C++ std::atomic wrapper with correct size
  CppAtomic[T] {.importcpp: "std::atomic", header: "<atomic>",
                 size: sizeof(T), completeStruct.} = object

  # Complex expressions are supported
  PaddedWrapper[T] {.importc, size: sizeof(T) + 4, completeStruct.} = object

  # Multiple type parameters
  Pair[A, B] {.importc, size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(CppAtomic[int32]) == 4
  doAssert sizeof(CppAtomic[int64]) == 8
  doAssert sizeof(PaddedWrapper[int8]) == 5
  doAssert sizeof(Pair[int32, int64]) == 12
```

## Use Cases

### Proper C++ Template Type Wrapping

The primary motivation: correctly wrapping C++ template types whose size depends on template parameters.

```nim
# Before: Workarounds like fake fields - WRONG for std::atomic
type Atomic[T] = object
  raw: T  # Approximate size only

# After: Exact size matching C++
type
  Atomic[T] {.importcpp: "std::atomic", header: "<atomic>",
              size: sizeof(T), completeStruct.} = object
```

### Platform-Independent FFI

Cross-platform bindings where sizes vary by architecture:

```nim
type
  PlatformInt {.importc: "intptr_t", size: sizeof(pointer),
               completeStruct.} = object
```

## Implementation

**AST extensions** (`astdef.nim`, `ast.nim`):
- `DeferredPragmaExpr` type pairs pragma word with unevaluated expression
- `deferredExprsImpl` field on `TType` and `TSym`
- `sfHasDeferredPragmas` / `tfHasDeferredPragmas` flags
- Accessor procs: `setDeferredExpr`, `clearDeferredExpr`, `deferredPragmas` iterator

**Pragma processing** (`pragmas.nim`):
- `containsUnresolvedIdent`: Detects expressions with unresolved generic identifiers
- `deferOrEvaluate`: Generic helper for defer-or-evaluate decision
- Modified `wSize` handler to defer when expression contains generic params

**Instantiation** (`semtypinst.nim`):
- `replaceIdentsWithTypes`: Substitutes generic param names with concrete types
- `applyDeferredPragma`: Evaluates deferred pragmas after instantiation
- `evaluateDeferredPragmas`: Orchestrates evaluation of all deferred type pragmas

**IC serialization** (`ic/enum2nif.nim`):
- Added serialization for new `sfHasDeferredPragmas` and `tfHasDeferredPragmas` flags

## Tests

- `tests/pragmas/tdeferred_size.nim` - Size pragma with `sizeof(T)` expressions

## Prior Art

[PR #24204](https://github.com/nim-lang/Nim/pull/24204) addresses the same problem for the `size` pragma. Key differences in our approach:

| Aspect | PR #24204 | This PR |
|--------|-----------|---------|
| **Scope** | `size` pragma | `size` pragma (with extensible infrastructure) |
| **Storage** | Retrieves from symbol's pragma AST | Dedicated `deferredExprsImpl` field with typed accessors |
| **Detection** | `tfHasMeta` flag | Scope lookup via `containsUnresolvedIdent` |
| **Extensibility** | Single pragma | Generic system designed for additional pragmas |

Our approach uses a dedicated storage mechanism rather than mining symbol AST (which the #24204 author noted "seems dubious"). The `DeferredPragmaExpr` type and accessor API make it straightforward to add deferred support to additional pragmas in follow-up PRs.

## Related Work

This PR establishes the infrastructure that will be extended in follow-up PRs to support:
- `align` pragma with generic expressions
- `importc`/`importcpp` pragmas with generic expressions
- `header` pragma with generic expressions
