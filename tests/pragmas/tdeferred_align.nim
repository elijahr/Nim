discard """
  targets: "c cpp"
"""
## Test: Deferred `align` pragma with generic type parameters
##
## Coverage:
## - Type-level align: alignof(T)
## - Field-level align: alignof(T)
## - Variable-level align: alignof(T)
## - Multiple generic params
## - C++ templates (cpp backend only)

# -----------------------------------------------------------------------------
# Type-level alignment (NEW: align pragma now valid on types)
# -----------------------------------------------------------------------------

type AlignedType[T] {.importc, size: sizeof(T), align: alignof(T), completeStruct.} = object

static:
  doAssert alignof(AlignedType[int8]) >= 1
  doAssert alignof(AlignedType[int32]) >= 4
  doAssert alignof(AlignedType[int64]) >= alignof(int64)

type AlignFirst[A, B] {.importc, size: sizeof(A) + sizeof(B), align: alignof(A), completeStruct.} = object

static:
  doAssert alignof(AlignFirst[int64, int8]) >= alignof(int64)
  doAssert alignof(AlignFirst[int8, int64]) >= 1

type AlignSecond[A, B] {.importc, size: sizeof(A) + sizeof(B), align: alignof(B), completeStruct.} = object

static:
  doAssert alignof(AlignSecond[int8, int64]) >= alignof(int64)
  doAssert alignof(AlignSecond[int64, int8]) >= 1

# -----------------------------------------------------------------------------
# Field-level alignment
# -----------------------------------------------------------------------------

type FieldAlign[T] = object
  header: int8
  data {.align: alignof(T).}: T

var fa8: FieldAlign[int8]
var fa64: FieldAlign[int64]
fa8.data = 1
fa64.data = 2
doAssert fa8.data == 1
doAssert fa64.data == 2

type MultiFieldAlign[A, B] = object
  first {.align: alignof(A).}: A
  second {.align: alignof(B).}: B

var mfa: MultiFieldAlign[int32, int64]
mfa.first = 1
mfa.second = 2
doAssert mfa.first == 1
doAssert mfa.second == 2

# Field with sizeof-based alignment (align to size boundary)
type SizeAsAlign[T] = object
  header: int8
  value {.align: sizeof(T).}: T

var saa: SizeAsAlign[int32]
saa.value = 42
doAssert saa.value == 42

# -----------------------------------------------------------------------------
# Variable-level alignment
# -----------------------------------------------------------------------------

proc testVarAlign[T]() =
  var x {.align: alignof(T).}: T
  x = default(T)
  doAssert x == default(T)

testVarAlign[int8]()
testVarAlign[int32]()
testVarAlign[int64]()

proc testLetAlign[T](val: T) =
  let x {.align: alignof(T).}: T = val
  doAssert x == val

testLetAlign[int32](42)
testLetAlign[int64](123)

# -----------------------------------------------------------------------------
# Non-generic (regression test)
# -----------------------------------------------------------------------------

type FixedAlign = object
  data {.align: 16.}: int32

var fixed: FixedAlign
fixed.data = 1
doAssert fixed.data == 1

type FixedTypeAlign {.importc, size: 4, align: 16, completeStruct.} = object

static:
  doAssert alignof(FixedTypeAlign) == 16

# -----------------------------------------------------------------------------
# C++ templates (cpp backend only)
# -----------------------------------------------------------------------------

when defined(cpp):
  type CppAligned[T] {.importcpp: "std::atomic", header: "<atomic>",
                       size: sizeof(T), align: alignof(T), completeStruct.} = object

  static:
    doAssert sizeof(CppAligned[int64]) == 8
    doAssert alignof(CppAligned[int64]) >= alignof(int64)

echo "All deferred align pragma tests passed!"
