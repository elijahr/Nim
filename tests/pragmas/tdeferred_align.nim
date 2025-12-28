discard """
  description: "Test deferred align pragma expressions for generic types"
  targets: "cpp"
"""

# Test 1: Combined size and align on std::atomic (real C++ type)
type
  AtomicLike[T] {.importcpp: "std::atomic", header: "<atomic>",
                  size: sizeof(T), align: alignof(T), completeStruct.} = object

static:
  doAssert sizeof(AtomicLike[int8]) == 1
  doAssert sizeof(AtomicLike[int16]) == 2
  doAssert sizeof(AtomicLike[int32]) == 4
  doAssert sizeof(AtomicLike[int64]) == 8
  doAssert alignof(AtomicLike[int8]) >= 1
  doAssert alignof(AtomicLike[int16]) >= 2
  doAssert alignof(AtomicLike[int32]) >= 4
  doAssert alignof(AtomicLike[int64]) >= 8

# Test 2: alignof(A) with multiple type params
type
  PairFirst[A, B] {.importcpp: "std::pair", header: "<utility>",
                    size: sizeof(A) + sizeof(B),
                    align: alignof(A), completeStruct.} = object

static:
  doAssert sizeof(PairFirst[int64, int32]) == 12
  doAssert sizeof(PairFirst[int32, int64]) == 12
  doAssert alignof(PairFirst[int64, int32]) >= alignof(int64)
  doAssert alignof(PairFirst[int32, int64]) >= alignof(int32)

# Test 3: alignof(B) - use second type param
type
  PairSecond[A, B] {.importcpp: "std::pair", header: "<utility>",
                     size: sizeof(A) + sizeof(B),
                     align: alignof(B), completeStruct.} = object

static:
  doAssert alignof(PairSecond[int32, int64]) >= alignof(int64)
  doAssert alignof(PairSecond[int64, int32]) >= alignof(int32)

# Test 4: Basic field-level align (non-deferred, always works)
type
  AlignedStruct = object
    a {.align: 8.}: int32
    b: int32

var s: AlignedStruct
s.a = 42
s.b = 99
doAssert s.a == 42

# Test 5: Field align with compile-time constant
const MyAlign = 16

type
  ConstAlignedStruct = object
    data {.align: MyAlign.}: array[4, int32]

var ca: ConstAlignedStruct
ca.data[0] = 1
doAssert ca.data[0] == 1

echo "All deferred align pragma tests passed!"
