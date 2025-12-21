# Experiments to detect 16-byte lock-free atomics at Nim compile time
# using staticExec to query the C compiler

import std/strutils

# Approach: Use staticExec to compile a small C program that prints
# whether 16-byte atomics are lock-free, then parse the output
#
# For C: Check __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 macro
# For C++: Use std::atomic<T>::is_always_lock_free (requires C++17)

const cTestProgram = """
#include <stdio.h>
int main() {
#ifdef __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16
  printf("1");
#else
  printf("0");
#endif
  return 0;
}
"""

const cppTestProgram = """
#include <cstdio>
#include <atomic>
struct S16 { long long a; long long b; };
int main() { printf("%d", std::atomic<S16>::is_always_lock_free ? 1 : 0); return 0; }
"""

# Write test program, compile it, run it, parse output
# This happens at Nim compile time via staticExec

const tempFile = "/tmp/nim_lockfree16_test"

when defined(cpp):
  const ext = ".cpp"
  const testProgram = cppTestProgram
  const compilerCmd = "c++ -std=c++17"
else:
  const ext = ".c"
  const testProgram = cTestProgram
  const compilerCmd = "cc"

# Write the test program
const writeCmd = "cat > " & tempFile & ext & " << 'NIMEOF'\n" & testProgram & "\nNIMEOF"
const writeResult = staticExec(writeCmd)

# Compile and run it
const compileAndRun = staticExec(compilerCmd & " -o " & tempFile & " " & tempFile & ext & " && " & tempFile & " 2>/dev/null || echo 0")

const hasLockFree16_detected* = compileAndRun.strip() == "1"

echo "staticExec compile+run result: '", compileAndRun.strip(), "'"
echo "hasLockFree16 (detected via staticExec): ", hasLockFree16_detected

when hasLockFree16_detected:
  echo "16-byte lock-free atomics ARE supported!"
else:
  echo "16-byte lock-free atomics are NOT supported"

echo "Done"
