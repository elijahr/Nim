## Test: Concept-based lock-free type detection
## Result: compileTime procs work for concept constraints!

import std/typetraits

type
  BigArray = array[100, int]

  Point = object
    x, y: int32

  ThreeBytes = object
    a, b, c: uint8

# ============================================
# Working approach: compileTime procs
# ============================================

proc hasValidAtomicSize[T](x: typedesc[T]): bool {.compileTime.} =
  sizeof(T) == 1 or sizeof(T) == 2 or sizeof(T) == 4 or sizeof(T) == 8

proc isCopyMemSafe[T](x: typedesc[T]): bool {.compileTime.} =
  supportsCopyMem(T)

# Define concepts using these procs
type
  ValidAtomicSize = concept type T
    hasValidAtomicSize(T)

  CopyMemSafe = concept type T
    isCopyMemSafe(T)

# Combine for full LockFreeType
when defined(gcdestructors):
  type
    LockFreeType = ValidAtomicSize and CopyMemSafe
else:
  type
    LockFreeType = ValidAtomicSize

# ============================================
# Tests
# ============================================

echo "Testing ValidAtomicSize concept:"
echo "  int8 is ValidAtomicSize: ", int8 is ValidAtomicSize
echo "  int16 is ValidAtomicSize: ", int16 is ValidAtomicSize
echo "  int32 is ValidAtomicSize: ", int32 is ValidAtomicSize
echo "  int64 is ValidAtomicSize: ", int64 is ValidAtomicSize
echo "  int is ValidAtomicSize: ", int is ValidAtomicSize
echo "  Point (8 bytes) is ValidAtomicSize: ", Point is ValidAtomicSize
echo "  ThreeBytes (3 bytes) is ValidAtomicSize: ", ThreeBytes is ValidAtomicSize
echo "  BigArray is ValidAtomicSize: ", BigArray is ValidAtomicSize

echo "\nTesting CopyMemSafe concept:"
echo "  int is CopyMemSafe: ", int is CopyMemSafe
echo "  Point is CopyMemSafe: ", Point is CopyMemSafe
echo "  ref int is CopyMemSafe: ", (ref int) is CopyMemSafe
echo "  string is CopyMemSafe: ", string is CopyMemSafe

echo "\nTesting LockFreeType (combined):"
echo "  int is LockFreeType: ", int is LockFreeType
echo "  Point is LockFreeType: ", Point is LockFreeType
echo "  ThreeBytes is LockFreeType: ", ThreeBytes is LockFreeType
echo "  BigArray is LockFreeType: ", BigArray is LockFreeType
when defined(gcdestructors):
  echo "  (gcdestructors) ref int is LockFreeType: ", (ref int) is LockFreeType
  echo "  (gcdestructors) string is LockFreeType: ", string is LockFreeType

# ============================================
# Test proc overloading with the concepts
# ============================================

proc doLockFree[T: LockFreeType](x: T) =
  echo "    Lock-free op on ", typeof(x)

proc doSpinlock[T: not LockFreeType](x: T) =
  echo "    Spinlock op on ", typeof(x)

echo "\nTesting proc overloading:"
doLockFree(42'i8)
doLockFree(42'i64)
doLockFree(Point(x: 1, y: 2))
doSpinlock(ThreeBytes(a: 1, b: 2, c: 3))
doSpinlock(BigArray.default)

echo "\nAll tests passed!"
