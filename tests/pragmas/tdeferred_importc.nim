discard """
  targets: "c cpp"
"""
## Test: Deferred `importc` pragma with generic type parameters
##
## Coverage:
## - Compile-time function returning C type name
## - Single generic param
## - Multiple generic params
## - Non-generic regression test

# -----------------------------------------------------------------------------
# Single generic parameter
# -----------------------------------------------------------------------------

proc singleTypeName(T: typedesc): string {.compileTime.} =
  when T is int8: "signed char"
  elif T is int16: "short"
  elif T is int32: "int"
  elif T is int64: "long long"
  else: "int"

type SingleImport[T] {.importc: singleTypeName(T), size: sizeof(T), completeStruct.} = object

var si8: SingleImport[int8]
var si16: SingleImport[int16]
var si32: SingleImport[int32]
var si64: SingleImport[int64]

static:
  doAssert sizeof(SingleImport[int8]) == 1
  doAssert sizeof(SingleImport[int16]) == 2
  doAssert sizeof(SingleImport[int32]) == 4
  doAssert sizeof(SingleImport[int64]) == 8

# -----------------------------------------------------------------------------
# Multiple generic parameters
# -----------------------------------------------------------------------------

proc firstTypeName(A, B: typedesc): string {.compileTime.} =
  when A is int8: "signed char"
  elif A is int32: "int"
  elif A is int64: "long long"
  else: "int"

type FirstImport[A, B] {.importc: firstTypeName(A, B), size: sizeof(A), completeStruct.} = object

static:
  doAssert sizeof(FirstImport[int8, int64]) == 1
  doAssert sizeof(FirstImport[int64, int8]) == 8

proc secondTypeName(A, B: typedesc): string {.compileTime.} =
  when B is int8: "signed char"
  elif B is int32: "int"
  elif B is int64: "long long"
  else: "int"

type SecondImport[A, B] {.importc: secondTypeName(A, B), size: sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(SecondImport[int8, int64]) == 8
  doAssert sizeof(SecondImport[int64, int8]) == 1

# -----------------------------------------------------------------------------
# Non-generic (regression test)
# -----------------------------------------------------------------------------

type FixedImport {.importc: "int", size: 4, completeStruct.} = object

static:
  doAssert sizeof(FixedImport) == 4

echo "All deferred importc pragma tests passed!"
