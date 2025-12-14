Invalid `m_type` access in hooks for distinct generic types under ARC/ORC/HOOKS/ATOMICARC

### Nim Version
Affects Nim versions 1.6.10+, 2.0.0+, and devel.

### Description
When using memory managers in the ARC family (ARC, ORC, HOOKS, ATOMICARC), the compiler generates invalid C code for `=sink`, `=assign`, `=deepcopy`, and `=dup` hooks involving distinct types derived from generic objects (e.g., `distinct Ctx[N]`). Specifically, the generated C code attempts to copy the `m_type` field (Runtime Type Information) from the object's struct, even though plain objects do not possess this field.

This results in a C compilation error: `error: no member named 'm_type' in 'struct ...'`.

### Technical Analysis
The issue occurs because `liftdestructors.nim` (responsible for generating type-bound operators) determines whether to copy the `m_type` field based on `isObjLackingTypeField`. This check expects a `tyObject` but often receives a `tyGenericInst` (the generic type wrapper). When `isObjLackingTypeField` encounters a `tyGenericInst`, it incorrectly returns `false` (implying the `m_type` field exists). This causes `liftdestructors` to generate AST nodes for copying `m_type`.

In **single-module scenarios**, this bug is masked. The compiler generates the invalid AST for `m_type` access, but the C backend, during its type canonicalization and code deduplication phase, likely opts to use the correct (non-buggy) hook generated for the base object type (which shares the same C layout), thus bypassing the problematic code.

In **multi-module scenarios**, this deduplication often does not occur across module boundaries for this specific case. The compiler generates and uses the buggy hook for the `tyGenericInst`, which attempts to access `m_type` on the struct defined in the imported module (where `m_type` is correctly absent), leading to a C compilation error.

### Minimal Reproduction
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

`a.nim`:
```nim
import ./ts

proc testA*() =
  discard makeUnused[4]().consume()
```

`b.nim`:
```nim
import ./ts

var globalObj: DistinctObject[4]

proc testB*() =
  globalObj = makeUnused[4]().consume()
```

`main.nim`:
```nim
import ./a, ./b
testA()
testB()
```

Run with: `nim c --mm:orc main.nim`

### Current Output
```
error: no member named 'm_type' in 'struct tyObject_Ctx__Ofjd05JshcgM9aoDXkzMY3Q'
        (*dest_p0).m_type = src_p1.m_type;
        ~~~~~~~~~~ ^
```

### Expected Output
Successful compilation and execution.
