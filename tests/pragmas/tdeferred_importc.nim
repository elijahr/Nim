discard """
  targets: "c cpp"
  description: "Test deferred importc/importcpp pragma expressions for generic types"
"""

# ===========================================
# Backend-agnostic tests (C and C++)
# ===========================================

# Test 1: Simple compile-time function returning C type names
proc cTypeName(T: typedesc): string {.compileTime.} =
  # Use real C type names
  when T is int8: "signed char"
  elif T is int16: "short"
  elif T is int32: "int"
  elif T is int64: "long long"
  else: "int"

type GenericWrapper[T] {.importc: cTypeName(T), size: sizeof(T), completeStruct.} = object

# Instantiate with different types
var w1: GenericWrapper[int8]
var w2: GenericWrapper[int16]
var w3: GenericWrapper[int32]
var w4: GenericWrapper[int64]

static:
  doAssert sizeof(GenericWrapper[int8]) == 1
  doAssert sizeof(GenericWrapper[int16]) == 2
  doAssert sizeof(GenericWrapper[int32]) == 4
  doAssert sizeof(GenericWrapper[int64]) == 8

# Test 2: Multiple type parameters - use first
proc useFirstName(A, B: typedesc): string {.compileTime.} =
  when A is int8: "signed char"
  elif A is int32: "int"
  else: "int"

type UseFirst[A, B] {.importc: useFirstName(A, B), size: sizeof(A), completeStruct.} = object

var uf1: UseFirst[int8, int64]
var uf2: UseFirst[int32, int8]

static:
  doAssert sizeof(UseFirst[int8, int64]) == 1
  doAssert sizeof(UseFirst[int32, int8]) == 4

# Test 3: Multiple type parameters - use second
proc useSecondName(A, B: typedesc): string {.compileTime.} =
  when B is int64: "long long"
  elif B is int8: "signed char"
  else: "int"

type UseSecond[A, B] {.importc: useSecondName(A, B), size: sizeof(B), completeStruct.} = object

var us1: UseSecond[int8, int64]
var us2: UseSecond[int32, int8]

static:
  doAssert sizeof(UseSecond[int8, int64]) == 8
  doAssert sizeof(UseSecond[int32, int8]) == 1

# Note: importcpp with deferred expressions has a limitation:
# importcpp auto-appends template parameters, so returning "std::int32_t"
# becomes "std::int32_t<NI32>" which is invalid. This is a separate issue
# from deferred pragma expressions and would need changes to how importcpp
# patterns work. For now, deferred importc works correctly.
