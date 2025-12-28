discard """
  targets: "c cpp"
  description: "Test deferred size pragma expressions for generic imported types"
"""

# ===========================================
# Backend-agnostic tests (C and C++)
# ===========================================

# Basic sizeof(T) with importc
type
  GenericSized[T] {.importc: "GenericSized", size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(GenericSized[int8]) == 1
  doAssert sizeof(GenericSized[int16]) == 2
  doAssert sizeof(GenericSized[int32]) == 4
  doAssert sizeof(GenericSized[int64]) == 8

# sizeof with expression: sizeof(T) + padding
type
  PaddedWrapper[T] {.importc: "PaddedWrapper", size: sizeof(T) + 4, completeStruct.} = object

static:
  doAssert sizeof(PaddedWrapper[int8]) == 5
  doAssert sizeof(PaddedWrapper[int32]) == 8

# sizeof with expression: sizeof(T) * multiplier
type
  DoubleWrapper[T] {.importc: "DoubleWrapper", size: sizeof(T) * 2, completeStruct.} = object

static:
  doAssert sizeof(DoubleWrapper[int8]) == 2
  doAssert sizeof(DoubleWrapper[int32]) == 8

# Multiple generic parameters - sizeof uses first
type
  PairFirst[A, B] {.importc: "PairFirst", size: sizeof(A), completeStruct.} = object

static:
  doAssert sizeof(PairFirst[int8, int64]) == 1
  doAssert sizeof(PairFirst[int64, int8]) == 8

# Multiple generic parameters - sizeof uses second
type
  PairSecond[A, B] {.importc: "PairSecond", size: sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(PairSecond[int8, int64]) == 8
  doAssert sizeof(PairSecond[int64, int8]) == 1

# Multiple generic parameters - sizeof uses both
type
  PairBoth[A, B] {.importc: "PairBoth", size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(PairBoth[int8, int8]) == 2
  doAssert sizeof(PairBoth[int32, int64]) == 12

# Verify regular size pragma still works (non-generic, fixed size)
type
  FixedSize {.importc: "FixedSize", size: 16, completeStruct.} = object

static:
  doAssert sizeof(FixedSize) == 16

# ===========================================
# C++ specific tests
# ===========================================

when defined(cpp):
  type
    CppAtomic[T] {.importcpp: "std::atomic", header: "<atomic>", size: sizeof(T), completeStruct.} = object

  static:
    doAssert sizeof(CppAtomic[int8]) == 1
    doAssert sizeof(CppAtomic[int16]) == 2
    doAssert sizeof(CppAtomic[int32]) == 4
    doAssert sizeof(CppAtomic[int64]) == 8

echo "All deferred size pragma tests passed!"
