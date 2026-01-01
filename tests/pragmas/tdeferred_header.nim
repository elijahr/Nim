discard """
  action: compile
  targets: "c cpp"
"""
## Test: Deferred `header` pragma with generic type parameters
##
## This test verifies that the compiler accepts deferred header expressions
## with generic type parameters. The actual header inclusion is verified
## in the generated C/C++ code.
##
## Coverage:
## - header with compile-time function using generic param
## - header with multiple generic params
## - header combined with importcpp
## - Different headers for different instantiations

# -----------------------------------------------------------------------------
# Basic deferred header with compile-time function
# -----------------------------------------------------------------------------

proc getHeader(T: typedesc): string {.compileTime.} =
  when T is int32: "<cstdint>"
  elif T is int64: "<cstdint>"
  elif T is float32: "<cmath>"
  elif T is float64: "<cmath>"
  else: "<cstdlib>"

type GenericWithHeader[T] {.importc: "GenericType",
                            header: getHeader(T),
                            completeStruct.} = object

# Each instantiation should use the appropriate header
discard GenericWithHeader[int32].sizeof
discard GenericWithHeader[float64].sizeof

# -----------------------------------------------------------------------------
# Header with static string (non-deferred, should still work)
# -----------------------------------------------------------------------------

type FixedHeader[T] {.importc: "FixedType",
                      header: "<stdio.h>",
                      completeStruct.} = object

discard FixedHeader[int32].sizeof
discard FixedHeader[float64].sizeof

# -----------------------------------------------------------------------------
# C++ specific tests
# -----------------------------------------------------------------------------

when defined(cpp):
  # C++ template with deferred header
  proc getCppHeader(T: typedesc): string {.compileTime.} =
    when T is int32: "<vector>"
    elif T is float64: "<array>"
    else: "<deque>"

  type CppContainer[T] {.importcpp: "Container<'0>",
                         header: getCppHeader(T),
                         completeStruct.} = object

  discard CppContainer[int32].sizeof
  discard CppContainer[float64].sizeof

  # Standard library types with appropriate headers
  proc getStlHeader(T: typedesc): string {.compileTime.} =
    "<memory>"

  type SmartPtr[T] {.importcpp: "std::unique_ptr<'0>",
                     header: getStlHeader(T),
                     completeStruct.} = object

  discard SmartPtr[int32].sizeof

# -----------------------------------------------------------------------------
# Combined with size and align pragmas
# -----------------------------------------------------------------------------

proc getSizedHeader(T: typedesc): string {.compileTime.} =
  when sizeof(T) <= 4: "<stdint.h>"
  else: "<inttypes.h>"

type SizedType[T] {.importc: "SizedType",
                    header: getSizedHeader(T),
                    size: sizeof(T),
                    completeStruct.} = object

discard SizedType[int8].sizeof
discard SizedType[int64].sizeof

# -----------------------------------------------------------------------------
# Multiple generic parameters
# -----------------------------------------------------------------------------

proc getPairHeader(A, B: typedesc): string {.compileTime.} =
  "<utility>"

type GenericPair[A, B] {.importc: "Pair",
                         header: getPairHeader(A, B),
                         completeStruct.} = object

discard GenericPair[int32, float32].sizeof
discard GenericPair[int64, float64].sizeof

# -----------------------------------------------------------------------------
# Non-generic type with deferred-style header (regression test)
# -----------------------------------------------------------------------------

# This uses a literal string - should work as before
type PlainType {.importc: "PlainType", header: "<stdlib.h>",
                 completeStruct.} = object

discard PlainType.sizeof

# -----------------------------------------------------------------------------
# Verify different instantiations are distinct
# -----------------------------------------------------------------------------

type HeaderTypeA[T] {.importc: "TypeA",
                      header: getHeader(T),
                      completeStruct.} = object

type HeaderTypeB[T] {.importc: "TypeB",
                      header: getHeader(T),
                      completeStruct.} = object

discard HeaderTypeA[int32].sizeof
discard HeaderTypeA[float64].sizeof
discard HeaderTypeB[int32].sizeof
discard HeaderTypeB[float64].sizeof

static:
  doAssert not (HeaderTypeA[int32] is HeaderTypeA[float64])
  doAssert not (HeaderTypeA[int32] is HeaderTypeB[int32])
