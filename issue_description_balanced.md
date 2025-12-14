Invalid `m_type` access in hooks for distinct generic types (ARC/ORC/HOOKS)

### Nim Version
Affects Nim versions 1.6.10+, 2.0.0+, and devel.

### Description
When using the ARC/ORC/HOOKS/ATOMICARC memory managers, the compiler generates invalid C code for distinct types derived from generic objects (e.g., `distinct Ctx[N]`). Specifically, the generated `=sink` (or other lifecycle) hooks attempt to copy the `m_type` field (Runtime Type Information) from the object, even though the underlying C struct does not have this field.

This results in a C compilation error:
`error: no member named 'm_type' in 'struct ...'`

### Why this happens
The compiler's `liftdestructors` pass is responsible for generating hooks like `=sink`. It has a check (`isObjLackingTypeField`) to decide if it needs to copy the hidden `m_type` field.

The bug is that this check is performed on the **generic instance type** (e.g., `Ctx[4]`) rather than the underlying object type. The check strictly requires a `tyObject` node; if it sees a generic instance, it assumes (incorrectly) that the field must exist.

This issue is masked in single-file builds because the C backend often deduplicates the hook implementation, using the correct version generated for the base object. However, in **multi-module builds**, the compiler generates a specific hook for the imported type, which includes the invalid access, causing the build to fail.

### Reproduction
`ts.nim`:
```nim
type
  BaseObject*[N: static int] = object
    value*: int

  UnusedDistinct*[N: static int] = distinct BaseObject[N]
  DistinctObject*[N: static int] = distinct BaseObject[N]

proc `=copy`*[N: static int](dest: var DistinctObject[N], src: DistinctObject[N]) {.error: "no".}

proc makeUnused*[N: static int](): UnusedDistinct[N] =
  UnusedDistinct[N](BaseObject[N](value: 0))

proc consume*[N: static int](u: sink UnusedDistinct[N]): DistinctObject[N] =
  DistinctObject[N](BaseObject[N](u))
```

`main.nim`:
```nim
import ./ts

proc test() =
  var globalObj: DistinctObject[4]
  globalObj = makeUnused[4]().consume()

test()
```

Run with: `nim c --mm:orc main.nim`