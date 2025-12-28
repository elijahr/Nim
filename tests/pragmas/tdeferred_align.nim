discard """
  description: "Test deferred align pragma expressions for generic types"
  targets: "c cpp"
"""

# ===========================================
# Backend-agnostic tests (C and C++)
# ===========================================

# Basic alignof(T) with importc
type
  GenericAligned[T] {.importc: "GenericAligned", size: sizeof(T), align: alignof(T), completeStruct.} = object

static:
  doAssert alignof(GenericAligned[int8]) >= alignof(int8)
  doAssert alignof(GenericAligned[int16]) >= alignof(int16)
  doAssert alignof(GenericAligned[int32]) >= alignof(int32)
  doAssert alignof(GenericAligned[int64]) >= alignof(int64)

# alignof(A) with multiple type params
type
  AlignFirst[A, B] {.importc: "AlignFirst", size: sizeof(A) + sizeof(B), align: alignof(A), completeStruct.} = object

static:
  doAssert alignof(AlignFirst[int64, int32]) >= alignof(int64)
  doAssert alignof(AlignFirst[int32, int64]) >= alignof(int32)

# alignof(B) - use second type param
type
  AlignSecond[A, B] {.importc: "AlignSecond", size: sizeof(A) + sizeof(B), align: alignof(B), completeStruct.} = object

static:
  doAssert alignof(AlignSecond[int32, int64]) >= alignof(int64)
  doAssert alignof(AlignSecond[int64, int32]) >= alignof(int32)

# Non-generic with fixed alignment (this works)
type
  FixedAlign16 {.importc: "FixedAlign16", size: 4, align: 16, completeStruct.} = object

static:
  doAssert alignof(FixedAlign16) == 16

# Basic field-level align (non-deferred)
type
  AlignedStruct = object
    a {.align: 8.}: int32
    b: int32

var s: AlignedStruct
s.a = 42
s.b = 99
doAssert s.a == 42

# Field align with compile-time constant
const MyAlign = 16

type
  ConstAlignedStruct = object
    data {.align: MyAlign.}: array[4, int32]

var ca: ConstAlignedStruct
ca.data[0] = 1
doAssert ca.data[0] == 1

# ===========================================
# C++ specific tests
# ===========================================

when defined(cpp):
  type
    AtomicLike[T] {.importcpp: "std::atomic", header: "<atomic>",
                    size: sizeof(T), align: alignof(T), completeStruct.} = object

  static:
    doAssert sizeof(AtomicLike[int8]) == 1
    doAssert sizeof(AtomicLike[int64]) == 8
    doAssert alignof(AtomicLike[int64]) >= alignof(int64)

  type
    PairLike[A, B] {.importcpp: "std::pair", header: "<utility>",
                     size: sizeof(A) + sizeof(B),
                     align: alignof(A), completeStruct.} = object

  static:
    doAssert alignof(PairLike[int64, int32]) >= alignof(int64)
