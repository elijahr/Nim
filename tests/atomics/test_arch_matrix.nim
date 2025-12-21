## Test lock-free atomics across architectures
## Verifies that hasLockFree8 and isLockFree behave correctly per-architecture

import std/atomics
import std/os

# Report architecture info
echo "=== Architecture Info ==="
echo "sizeof(pointer): ", sizeof(pointer)
echo "sizeof(int): ", sizeof(int)
echo "hasLockFree8: ", hasLockFree8

when defined(i386): echo "CPU: i386 (x86-32)"
elif defined(amd64): echo "CPU: amd64 (x86-64)"
elif defined(arm): echo "CPU: arm (32-bit)"
elif defined(arm64): echo "CPU: arm64"
elif defined(mips): echo "CPU: mips (32-bit)"
elif defined(mipsel): echo "CPU: mipsel (32-bit LE)"
elif defined(powerpc): echo "CPU: powerpc (32-bit)"
elif defined(sparc): echo "CPU: sparc (32-bit)"
elif defined(riscv32): echo "CPU: riscv32"
elif defined(riscv64): echo "CPU: riscv64"
else: echo "CPU: unknown"

echo ""
echo "=== Lock-Free Status ==="

template report(T: typedesc) =
  echo astToStr(T), ": ", T.isLockFree

report(int8)
report(int16)
report(int32)
report(int64)
report(pointer)

type SmallObj = object
  a, b: int32

report(SmallObj)

type BigObj = object
  a, b, c: int64

report(BigObj)

echo ""
echo "=== Verification ==="

# 1, 2, 4 byte types should always be lock-free
doAssert isLockFree(int8), "int8 should be lock-free"
doAssert isLockFree(int16), "int16 should be lock-free"
doAssert isLockFree(int32), "int32 should be lock-free"
doAssert isLockFree(bool), "bool should be lock-free"
doAssert isLockFree(char), "char should be lock-free"

# 8-byte types depend on hasLockFree8
doAssert isLockFree(int64) == hasLockFree8, "int64 lock-free should match hasLockFree8"
doAssert isLockFree(SmallObj) == hasLockFree8, "8-byte object lock-free should match hasLockFree8"

# Big objects should never be lock-free
doAssert not isLockFree(BigObj), "BigObj (24 bytes) should not be lock-free"

# Verify hasLockFree8 matches expected value from environment
let expectedStr = getEnv("EXPECT_8BYTE_LOCKFREE", "")
if expectedStr != "":
  let expected = expectedStr == "true"
  doAssert hasLockFree8 == expected,
    "hasLockFree8=" & $hasLockFree8 & " but expected " & $expected

echo "All architecture tests passed!"
