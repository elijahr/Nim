#!/bin/bash
# Cross-compile atomics test for multiple architectures
# Tests hasLockFree8, hasLockFree16 detection and full tatomics.nim compilation

set -e

NIM="./bin/nim_temp"

echo "=== Nim Atomics Cross-Compilation Test ==="
echo ""

# Create a test file that uses static assertions for hasLockFree8 and hasLockFree16
cat > /tmp/test_lockfree.nim << 'EOF'
import std/atomics

# Test hasLockFree8
when defined(expectLockFree8):
  static: doAssert hasLockFree8, "Expected hasLockFree8=true but got false"
else:
  static: doAssert not hasLockFree8, "Expected hasLockFree8=false but got true"

# Test hasLockFree16
when defined(expectLockFree16):
  static: doAssert hasLockFree16, "Expected hasLockFree16=true but got false"
else:
  static: doAssert not hasLockFree16, "Expected hasLockFree16=false but got true"

echo "hasLockFree8 = ", hasLockFree8
echo "hasLockFree16 = ", hasLockFree16
EOF

# Define architectures and their cross-compiler settings
# Format: "nim_cpu:nim_os:gcc_prefix:expect_8byte:expect_16byte"
declare -a TARGETS=(
    # 64-bit WITH 16-byte lock-free (amd64 and arm64 only)
    "amd64:linux:x86_64-linux-gnu-:true:true"
    "arm64:linux:aarch64-linux-gnu-:true:true"

    # 64-bit WITHOUT 16-byte lock-free
    "riscv64:linux:riscv64-linux-gnu-:true:false"

    # 32-bit WITH 8-byte lock-free (no 16-byte)
    "i386:linux:i686-linux-gnu-:true:false"
    "arm:linux:arm-linux-gnueabihf-:true:false"

    # 32-bit WITHOUT 8-byte lock-free (no 16-byte)
    "mips:linux:mips-linux-gnu-:false:false"
    "mipsel:linux:mipsel-linux-gnu-:false:false"
    "powerpc:linux:powerpc-linux-gnu-:false:false"
)

PASSED=0
FAILED=0
SKIPPED=0

for target in "${TARGETS[@]}"; do
    IFS=':' read -r cpu os gcc_prefix expect_8byte expect_16byte <<< "$target"

    echo "----------------------------------------"
    echo "Testing: $cpu ($os)"
    echo "  GCC prefix: ${gcc_prefix:-native}"
    echo "  Expected hasLockFree8: $expect_8byte"
    echo "  Expected hasLockFree16: $expect_16byte"

    # Check if cross-compiler exists
    if [ -n "$gcc_prefix" ] && ! command -v "${gcc_prefix}gcc" &> /dev/null; then
        echo "  ⚠️  SKIPPED: ${gcc_prefix}gcc not found"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Build cross-compile args (compile only - can't run cross-compiled binaries)
    ARGS="--cpu:$cpu --os:$os -c"
    if [ -n "$gcc_prefix" ]; then
        ARGS="$ARGS --gcc.exe:${gcc_prefix}gcc --gcc.linkerexe:${gcc_prefix}gcc"
    fi

    # Test 1: hasLockFree8 and hasLockFree16 detection
    echo "  Test 1: Lock-free detection..."
    ARGS1="$ARGS"
    if [ "$expect_8byte" = "true" ]; then
        ARGS1="$ARGS1 -d:expectLockFree8"
    fi
    if [ "$expect_16byte" = "true" ]; then
        ARGS1="$ARGS1 -d:expectLockFree16"
    fi

    if $NIM c $ARGS1 --hints:off /tmp/test_lockfree.nim 2>&1; then
        echo "    ✅ hasLockFree8=$expect_8byte, hasLockFree16=$expect_16byte (correct)"
    else
        echo "    ❌ FAILED: Lock-free detection incorrect"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Test 2: Full tatomics.nim compilation (compile-only)
    echo "  Test 2: tatomics.nim compilation..."
    if $NIM c $ARGS --hints:off --mm:orc tests/stdlib/concurrency/tatomics.nim 2>&1; then
        echo "    ✅ tatomics.nim compiles"
        PASSED=$((PASSED + 1))
    else
        echo "    ❌ FAILED: tatomics.nim compilation failed"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo ""

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo "All cross-compilation tests passed!"
