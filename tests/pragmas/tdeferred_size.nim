discard """
  targets: "cpp"
  description: "Test deferred size pragma expressions for generic imported types"
"""

# Basic sizeof(T) with importcpp
type
  CppAtomic[T] {.importcpp: "std::atomic", header: "<atomic>", size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(CppAtomic[int8]) == 1
  doAssert sizeof(CppAtomic[int16]) == 2
  doAssert sizeof(CppAtomic[int32]) == 4
  doAssert sizeof(CppAtomic[int64]) == 8

# Basic sizeof(T) with importc
type
  CAtomicInt[T] {.importc: "atomic_int", size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(CAtomicInt[int32]) == 4

# sizeof with expression: sizeof(T) + padding
type
  PaddedWrapper[T] {.importcpp: "PaddedType", size: sizeof(T) + 4, completeStruct.} = object

static:
  doAssert sizeof(PaddedWrapper[int8]) == 5
  doAssert sizeof(PaddedWrapper[int32]) == 8

# sizeof with expression: sizeof(T) * multiplier
type
  DoubleWrapper[T] {.importcpp: "DoubleType", size: sizeof(T) * 2, completeStruct.} = object

static:
  doAssert sizeof(DoubleWrapper[int8]) == 2
  doAssert sizeof(DoubleWrapper[int32]) == 8

# Multiple generic parameters - sizeof uses first
type
  PairFirst[A, B] {.importcpp: "PairFirst", size: sizeof(A), completeStruct.} = object

static:
  doAssert sizeof(PairFirst[int8, int64]) == 1
  doAssert sizeof(PairFirst[int64, int8]) == 8

# Multiple generic parameters - sizeof uses second
type
  PairSecond[A, B] {.importcpp: "PairSecond", size: sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(PairSecond[int8, int64]) == 8
  doAssert sizeof(PairSecond[int64, int8]) == 1

# Multiple generic parameters - sizeof uses both
type
  PairBoth[A, B] {.importcpp: "PairBoth", size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(PairBoth[int8, int8]) == 2
  doAssert sizeof(PairBoth[int32, int64]) == 12

# Verify regular size pragma still works (non-generic, fixed size)
type
  FixedSize {.importcpp, size: 16, completeStruct.} = object

static:
  doAssert sizeof(FixedSize) == 16

echo "All deferred size pragma tests passed!"
