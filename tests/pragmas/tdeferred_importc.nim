discard """
  action: compile
  targets: "c cpp"
"""
## Test: Deferred `importc` and `importcpp` pragma with generic type parameters
##
## This test verifies that the compiler accepts deferred importc/importcpp expressions
## with generic type parameters. The actual linking is not tested since we don't
## provide C/C++ implementations.
##
## Coverage:
## - importc with single generic param in name
## - importc with multiple generic params
## - importcpp with generic params
## - Complex string expressions with $T
## - Nested generic contexts
## - C++ template types (cpp backend only)

# -----------------------------------------------------------------------------
# Single generic parameter - importc
# -----------------------------------------------------------------------------

type Wrapper[T] {.importc: "Wrap_$1", completeStruct.} = object

# The external name should be based on the instantiated type name
# For Wrapper[int32], the external name will be "Wrap_Wrapper"
# (The $1 is replaced with the type name, not the generic param)

# We can't directly test external names from Nim, but we verify compilation succeeds
discard Wrapper[int32].sizeof
discard Wrapper[int64].sizeof

# -----------------------------------------------------------------------------
# Multiple generic parameters - importc
# -----------------------------------------------------------------------------

type MultiParam[A, B] {.importc: "Multi_$1", completeStruct.} = object

discard MultiParam[int32, int64].sizeof
discard MultiParam[float32, float64].sizeof

# -----------------------------------------------------------------------------
# Single generic parameter - importcpp
# -----------------------------------------------------------------------------

when defined(cpp):
  # Test basic importcpp with generic parameter
  type CppType[T] {.importcpp: "CppType<'0>", completeStruct.} = object

  discard CppType[int32].sizeof
  discard CppType[float64].sizeof

# -----------------------------------------------------------------------------
# Complex importcpp with multiple parameters
# -----------------------------------------------------------------------------

when defined(cpp):
  type CppPair[A, B] {.importcpp: "std::pair<'0, '1>",
                        header: "<utility>", completeStruct.} = object

  discard CppPair[int32, int32].sizeof
  discard CppPair[int64, float64].sizeof

# -----------------------------------------------------------------------------
# Standard library types (cpp backend only)
# -----------------------------------------------------------------------------

when defined(cpp):
  # std::vector
  type CppVector[T] {.importcpp: "std::vector<'0>",
                       header: "<vector>", completeStruct.} = object

  discard CppVector[int32].sizeof
  discard CppVector[float64].sizeof

  # std::unique_ptr
  type CppUniquePtr[T] {.importcpp: "std::unique_ptr<'0>",
                          header: "<memory>", completeStruct.} = object

  discard CppUniquePtr[int32].sizeof
  discard CppUniquePtr[float64].sizeof

# -----------------------------------------------------------------------------
# Nested generic contexts
# -----------------------------------------------------------------------------

when defined(cpp):
  # Container of containers
  type OuterContainer[T] {.importcpp: "OuterContainer<'0>",
                            completeStruct.} = object

  type InnerContainer[T] {.importcpp: "InnerContainer<'0>",
                            completeStruct.} = object

  discard OuterContainer[InnerContainer[int32]].sizeof
  discard OuterContainer[InnerContainer[float64]].sizeof

# -----------------------------------------------------------------------------
# Non-generic types (regression test: ensure fixed names still work)
# -----------------------------------------------------------------------------

type FixedName {.importc: "MyFixedStruct", completeStruct.} = object

discard FixedName.sizeof

when defined(cpp):
  type FixedCpp {.importcpp: "MyFixedClass", completeStruct.} = object

  discard FixedCpp.sizeof

# -----------------------------------------------------------------------------
# Default $1 behavior (no explicit name)
# -----------------------------------------------------------------------------

type DefaultName[T] {.importc, completeStruct.} = object

discard DefaultName[int32].sizeof
discard DefaultName[int64].sizeof

when defined(cpp):
  type DefaultCpp[T] {.importcpp, completeStruct.} = object

  discard DefaultCpp[int32].sizeof
  discard DefaultCpp[float64].sizeof

# -----------------------------------------------------------------------------
# Complex C++ template types
# -----------------------------------------------------------------------------

when defined(cpp):
  # Template with multiple template parameters
  type CppMap[K, V] {.importcpp: "std::map<'0, '1>",
                       header: "<map>", completeStruct.} = object

  discard CppMap[int32, int32].sizeof
  discard CppMap[string, float64].sizeof

  # Template with const qualifier
  type CppConstRef[T] {.importcpp: "const $1&", completeStruct.} = object

  discard CppConstRef[int32].sizeof
  discard CppConstRef[float64].sizeof

# -----------------------------------------------------------------------------
# Verify different instantiations are distinct types
# -----------------------------------------------------------------------------

# This is a compile-time test - if deferred pragmas don't work,
# different instantiations would share the same external name and cause issues

type TypeA[T] {.importc: "TypeA_$1", completeStruct.} = object
type TypeB[T] {.importc: "TypeB_$1", completeStruct.} = object

discard TypeA[int32].sizeof
discard TypeA[int64].sizeof
discard TypeB[int32].sizeof
discard TypeB[int64].sizeof

# These should all be different types with different external names
static:
  doAssert not (TypeA[int32] is TypeA[int64])
  doAssert not (TypeA[int32] is TypeB[int32])

# -----------------------------------------------------------------------------
# $1 substitution with generic types
# -----------------------------------------------------------------------------

type GenericWrapper[T] {.importc: "Wrapper_$1", completeStruct.} = object
  value: T

# Test $1 substitution - verify compilation and sizeof access
discard GenericWrapper[int32].sizeof
discard GenericWrapper[int64].sizeof
