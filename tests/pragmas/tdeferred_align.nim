discard """
  targets: "c cpp"
"""

# Type-level align with generic param
type
  GenericAligned[T] {.importc, align: alignof(T).} = object

  Container[T] = object
    data {.align: alignof(T).}: T

  MultiParam[T, U] {.importc, align: alignof(T).} = object
    field1 {.align: alignof(U).}: U
    field2 {.align: alignof(T).}: T

# Test instantiation
type
  AlignedInt = GenericAligned[int]
  AlignedChar = GenericAligned[char]

  ContainerInt = Container[int]
  ContainerInt64 = Container[int64]

  MultiIntChar = MultiParam[int, char]

# Basic alignment verification (types should compile)
static:
  doAssert alignof(int) > 0
  doAssert alignof(char) > 0
  doAssert alignof(int64) > 0

# Nested generic contexts
type
  Nested[T] = object
    inner {.align: alignof(T).}: T

  DoubleNested[T, U] = object
    level1 {.align: alignof(T).}: Nested[U]
    level2 {.align: alignof(U).}: T

type
  NestedIntFloat = DoubleNested[int, float]

# Multiple fields with different alignments
type
  MultiField[T] = object
    a {.align: alignof(T).}: T
    b {.align: alignof(int).}: int
    c {.align: alignof(T).}: T

type
  MultiFieldChar = MultiField[char]
  MultiFieldInt64 = MultiField[int64]

# Test with array types
type
  ArrayAligned[T] = object
    data {.align: alignof(T).}: array[10, T]

type
  ArrayAlignedInt = ArrayAligned[int]

echo "All deferred align pragma tests passed!"
