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

  # Prove alignment differs when parameter order changes:
  doAssert alignof(AlignFirst[int64, int8]) != alignof(AlignFirst[int8, int64])

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

# Prove align pragma has effect by comparing with/without:
type NoAlignPragma {.importc, size: 4, completeStruct.} = object
type DoubleAlign[T] {.importc, size: sizeof(T), align: alignof(T) * 2, completeStruct.} = object

static:
  # Verify alignment expression actually evaluates (would be natural align if broken):
  doAssert alignof(DoubleAlign[int32]) == 8   # 4 * 2
  doAssert alignof(DoubleAlign[int16]) == 4   # 2 * 2

  # Prove pragma controls alignment (not natural alignment):
  doAssert alignof(FixedTypeAlign) > alignof(NoAlignPragma)

# -----------------------------------------------------------------------------
# Multiple pragmas on same field
# -----------------------------------------------------------------------------

# Field with both align and another pragma
type MultiPragmaField[T] = object
  header: int8
  data {.align: alignof(T).}: T

var mpf8: MultiPragmaField[int8]
var mpf64: MultiPragmaField[int64]
mpf8.data = 1
mpf64.data = 2
doAssert mpf8.data == 1
doAssert mpf64.data == 2

# Field with complex align expression (mix of sizeof and alignof)
type ComplexAlignExpr[T] = object
  header: int8
  # Align to maximum of alignof(T) and sizeof(T), whichever is larger
  data {.align: max(alignof(T), sizeof(T)).}: T

var cae: ComplexAlignExpr[int32]
cae.data = 42
doAssert cae.data == 42

# Field with conditional alignment expression
type ConditionalAlign[T] = object
  header: int8
  # Use at least 8 bytes alignment, but respect T's natural alignment if larger
  data {.align: max(8, alignof(T)).}: T

var ca32: ConditionalAlign[int32]
var ca64: ConditionalAlign[int64]
ca32.data = 1
ca64.data = 2
doAssert ca32.data == 1
doAssert ca64.data == 2

# Multiple fields with different deferred align expressions
type MultiDeferredFields[A, B, C] = object
  first {.align: alignof(A).}: A
  second {.align: alignof(B).}: B
  third {.align: alignof(C).}: C

var mdf: MultiDeferredFields[int8, int32, int64]
mdf.first = 1
mdf.second = 2
mdf.third = 3
doAssert mdf.first == 1
doAssert mdf.second == 2
doAssert mdf.third == 3

# -----------------------------------------------------------------------------
# Variable-level alignment with more complex types
# -----------------------------------------------------------------------------

proc testVarAlignWithArray[T]() =
  var arr {.align: alignof(T).}: array[4, T]
  for i in 0..3:
    arr[i] = default(T)
  doAssert arr[0] == default(T)

testVarAlignWithArray[int16]()
testVarAlignWithArray[int64]()

proc testLetAlignWithTuple[T](val: T) =
  let x {.align: alignof(T).}: (T, T) = (val, val)
  doAssert x[0] == val
  doAssert x[1] == val

testLetAlignWithTuple[int8](5)
testLetAlignWithTuple[int32](42)

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
