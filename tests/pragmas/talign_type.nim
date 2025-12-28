discard """
  description: "Test align pragma on type definitions"
"""

# Type-level alignment
type
  Aligned16 {.align: 16.} = object
    x: int32

  Aligned32 {.align: 32.} = object
    x: int32

# Verify alignment is set correctly
static:
  doAssert alignof(Aligned16) == 16
  doAssert alignof(Aligned32) == 32

# Verify alignment affects struct layout
type
  Container = object
    a: byte
    b: Aligned16  # Should be at offset 16
    c: byte

static:
  # Container should be at least 32 bytes due to alignment padding
  doAssert sizeof(Container) >= 32

# Verify type alignment combines with field alignment
type
  AlignedWithField {.align: 8.} = object
    x {.align: 16.}: int32  # Field has higher alignment

static:
  # Field alignment should take precedence when higher
  doAssert alignof(AlignedWithField) >= 8

echo "All type-level align tests passed"
