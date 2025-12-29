discard """
  targets: "c cpp"
"""
## Test: Deferred `size` pragma with generic type parameters
##
## Coverage:
## - Single generic param: sizeof(T)
## - Multiple generic params: sizeof(A), sizeof(B), sizeof(A)+sizeof(B)
## - Complex expressions: sizeof(T)+N, sizeof(T)*N
## - C++ templates (cpp backend only)

# -----------------------------------------------------------------------------
# Single generic parameter
# -----------------------------------------------------------------------------

type Single[T] {.importc, size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(Single[int8]) == 1
  doAssert sizeof(Single[int16]) == 2
  doAssert sizeof(Single[int32]) == 4
  doAssert sizeof(Single[int64]) == 8

# -----------------------------------------------------------------------------
# Multiple generic parameters
# -----------------------------------------------------------------------------

type FirstParam[A, B] {.importc, size: sizeof(A), completeStruct.} = object

static:
  doAssert sizeof(FirstParam[int8, int64]) == 1
  doAssert sizeof(FirstParam[int64, int8]) == 8

type SecondParam[A, B] {.importc, size: sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(SecondParam[int8, int64]) == 8
  doAssert sizeof(SecondParam[int64, int8]) == 1

type BothParams[A, B] {.importc, size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(BothParams[int8, int8]) == 2
  doAssert sizeof(BothParams[int32, int64]) == 12

# -----------------------------------------------------------------------------
# Complex expressions
# -----------------------------------------------------------------------------

type PlusConst[T] {.importc, size: sizeof(T) + 4, completeStruct.} = object

static:
  doAssert sizeof(PlusConst[int8]) == 5
  doAssert sizeof(PlusConst[int32]) == 8

type TimesConst[T] {.importc, size: sizeof(T) * 2, completeStruct.} = object

static:
  doAssert sizeof(TimesConst[int8]) == 2
  doAssert sizeof(TimesConst[int32]) == 8

type ComplexExpr[T] {.importc, size: sizeof(T) * 2 + 4, completeStruct.} = object

static:
  doAssert sizeof(ComplexExpr[int8]) == 6
  doAssert sizeof(ComplexExpr[int32]) == 12

# -----------------------------------------------------------------------------
# Non-generic (regression test: ensure fixed sizes still work)
# -----------------------------------------------------------------------------

type FixedSize {.importc, size: 16, completeStruct.} = object

static:
  doAssert sizeof(FixedSize) == 16

# -----------------------------------------------------------------------------
# C++ templates (cpp backend only)
# -----------------------------------------------------------------------------

when defined(cpp):
  type CppAtomic[T] {.importcpp: "std::atomic", header: "<atomic>",
                      size: sizeof(T), completeStruct.} = object

  static:
    doAssert sizeof(CppAtomic[int8]) == 1
    doAssert sizeof(CppAtomic[int32]) == 4
    doAssert sizeof(CppAtomic[int64]) == 8

echo "All deferred size pragma tests passed!"
