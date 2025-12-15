#!/bin/bash

set -ex

# Note: boehm is excluded due to pre-existing Nim bug in lib/system/mm/boehm.nim
for mm in orc arc atomicArc refc markAndSweep none; do
  echo "=== Testing --mm:$mm ==="
  ./koch temp c -r --mm:$mm tests/stdlib/concurrency/tatomics.nim
  echo ""
done

echo "All memory managers passed!"
