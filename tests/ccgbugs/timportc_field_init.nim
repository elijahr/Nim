discard """
  targets: "c"
"""

# Objects with importc fields cannot use aggregate initialization {{}} in C
# The compiler should use {0} initialization instead

type
  AtomicLike {.importc: "_Atomic int", nodecl.} = object

  ContainsImportc = object
    normal: int
    atomic: AtomicLike

  NestedImportc = object
    wrapper: ContainsImportc
    extra: int

# These const initializations should compile (uses {0} not {{}})
const c1 = default(ContainsImportc)
const c2 = default(NestedImportc)

var v1: ContainsImportc
var v2: NestedImportc
