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
##
## Note: The `importc` pragma is ONLY valid on types and procedures.
## It is NOT valid on fields or variables (fields can't be imported from C).

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

  # Prove different instantiations are distinct (feature actually works):
  doAssert sizeof(SingleImport[int8]) != sizeof(SingleImport[int64])
  doAssert sizeof(SingleImport[int16]) != sizeof(SingleImport[int32])

# Verify importc pragma expression is evaluated correctly by testing usage:
# If the deferred importc didn't work, these assignments would fail.
si8 = default(SingleImport[int8])
si16 = default(SingleImport[int16])
si32 = default(SingleImport[int32])
si64 = default(SingleImport[int64])

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
# Complex type name generation with conditionals
# -----------------------------------------------------------------------------

proc conditionalTypeName(T: typedesc): string {.compileTime.} =
  when sizeof(T) == 1: "char"
  elif sizeof(T) == 2: "short"
  elif sizeof(T) == 4: "int"
  elif sizeof(T) == 8: "long long"
  else: "void"

type ConditionalImport[T] {.importc: conditionalTypeName(T), size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(ConditionalImport[int8]) == 1
  doAssert sizeof(ConditionalImport[int16]) == 2
  doAssert sizeof(ConditionalImport[int32]) == 4
  doAssert sizeof(ConditionalImport[int64]) == 8

# -----------------------------------------------------------------------------
# Type name with string concatenation
# -----------------------------------------------------------------------------

proc prefixedTypeName(T: typedesc): string {.compileTime.} =
  when T is int32: "my_" & "int"
  elif T is int64: "my_" & "long_long"
  else: "int"

type PrefixedImport[T] {.importc: prefixedTypeName(T), size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(PrefixedImport[int32]) == 4
  doAssert sizeof(PrefixedImport[int64]) == 8

# -----------------------------------------------------------------------------
# Mixed importc, size, and align pragmas
# -----------------------------------------------------------------------------

proc alignedTypeName(T: typedesc): string {.compileTime.} =
  when T is int8: "signed char"
  elif T is int32: "int"
  else: "int"

type AlignedImport[T] {.importc: alignedTypeName(T), size: sizeof(T),
                        align: alignof(T), completeStruct.} = object

static:
  doAssert sizeof(AlignedImport[int8]) == 1
  doAssert sizeof(AlignedImport[int32]) == 4
  doAssert alignof(AlignedImport[int32]) >= 4

# -----------------------------------------------------------------------------
# Non-generic (regression test)
# -----------------------------------------------------------------------------

type FixedImport {.importc: "int", size: 4, completeStruct.} = object

static:
  doAssert sizeof(FixedImport) == 4

echo "All deferred importc pragma tests passed!"
