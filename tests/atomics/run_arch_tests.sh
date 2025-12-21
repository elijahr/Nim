#!/bin/bash
# Run atomics lock-free tests across multiple architectures via Docker/QEMU
#
# Prerequisites:
#   - Docker with buildx and QEMU support
#   - Run: docker run --privileged --rm tonistiigi/binfmt --install all
#
# Usage:
#   cd tests/atomics
#   ./run_arch_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NIM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$NIM_ROOT"

echo "=== Setting up QEMU for multi-arch support ==="
docker run --privileged --rm tonistiigi/binfmt --install all 2>/dev/null || true

echo ""
echo "=== Building and testing across architectures ==="
echo ""

# Test each architecture individually for better error reporting
ARCHS="amd64 arm64 i386 arm32"

for arch in $ARCHS; do
    echo "----------------------------------------"
    echo "Testing: $arch"
    echo "----------------------------------------"

    if docker compose -f tests/atomics/docker-compose.yml build "$arch" 2>&1; then
        if docker compose -f tests/atomics/docker-compose.yml run --rm "$arch" 2>&1; then
            echo "✅ $arch: PASSED"
        else
            echo "❌ $arch: FAILED (test)"
        fi
    else
        echo "❌ $arch: FAILED (build)"
    fi
    echo ""
done

echo "=== Summary ==="
echo "Tested architectures: $ARCHS"
echo ""
echo "Note: MIPS32, SPARC32, PowerPC32 have limited Docker support."
echo "These would need custom QEMU setups or cross-compilation testing."
