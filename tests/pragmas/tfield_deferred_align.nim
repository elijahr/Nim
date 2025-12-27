discard """
  targets: "c"
  description: "Test deferred align/size pragmas on fields in generic types"
"""

# Test 1: Basic alignof(T) on field
type Container[T] = object
  data {.align: alignof(T).}: T

static:
  doAssert alignof(Container[int8]) == alignof(int8)
  doAssert alignof(Container[int16]) == alignof(int16)
  doAssert alignof(Container[int32]) == alignof(int32)
  doAssert alignof(Container[int64]) == alignof(int64)

# Test 2: Multiple fields with different alignments
type Multi[T, U] = object
  first {.align: alignof(T).}: T
  second {.align: alignof(U).}: U

static:
  type M = Multi[int8, int64]
  # Note: Cannot directly test field alignment in static context
  # This mainly tests that compilation succeeds

# Test 3: Expression involving generic params (using if expression)
type Padded[T] = object
  data {.align: (if alignof(T) >= 16: alignof(T) else: 16).}: T

static:
  # Should use max(alignof(int8), 16) = 16
  type P8 = Padded[int8]
  # Should use max(alignof(int64), 16) = 16
  type P64 = Padded[int64]

# Test 4: Nested generics
type Inner[U] = object
  data {.align: alignof(U).}: U

type Outer[T] = object
  inner: Inner[T]

static:
  type O = Outer[int64]
  # Nested instantiation should work

# Test 5: Variant object
type Variant[T] = object
  case kind: bool
  of true:
    a {.align: alignof(T).}: T
  of false:
    b: int

static:
  type V = Variant[int32]

# Test 6: Inherited fields
type Base[T] = object of RootObj
  baseField {.align: alignof(T).}: T

type Derived[U] = object of Base[U]
  derivedField: U

static:
  type D = Derived[int64]

# Test 7: Multiple generic params - different expressions
type Pair[A, B] = object
  first {.align: alignof(A).}: A
  second {.align: alignof(B).}: B
  both {.align: (if alignof(A) >= alignof(B): alignof(A) else: alignof(B)).}: int

static:
  type P = Pair[int8, int64]

# Test 8: Non-generic with constant alignment (regression test)
type Fixed = object
  data {.align: 16.}: int

static:
  # This should still work as before (immediate evaluation)
  type F = Fixed

# Test 9: Complex expression
type Complex[T] = object
  # Test arithmetic with alignof
  data {.align: alignof(T) * 2.}: T

echo "All field deferred pragma tests passed!"
