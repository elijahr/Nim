#
#
#            Nim's Runtime Library
#        (c) Copyright 2018 Jörg Wollenschläger
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Types and operations for atomic operations and lockless algorithms.
##
## Unstable API.
##
## Lock-free vs Spinlock
## ---------------------
## Lock-free eligibility depends on type size, architecture, and memory manager.
## Types that don't qualify fall back to a spinlock.
##
## **Size requirements:**
## - 1, 2, 4 bytes: lock-free (requires natural alignment)
## - 8 bytes: requires `hasLockFree8` (see below)
## - 16 bytes: requires `hasLockFree16` (see below)
## - Other sizes: uses spinlock
##
## **Memory manager requirements:**
## - With destructor-based MMs (`--mm:arc`, `--mm:orc`, `--mm:atomicArc`):
##   `supportsCopyMem(T)` must be true (excludes `ref`, `string`, `seq`)
## - With non-destructor MMs (`--mm:refc`, `--mm:markAndSweep`, `--mm:none`):
##   managed types of a correct size can use lock-free atomics
##
## Architecture Support
## --------------------
## **8-byte atomics** (`hasLockFree8`):
## - All 64-bit architectures
## - x86-32 (CMPXCHG8B, Pentium and later)
## - ARM32 (LDREXD/STREXD, ARMv6K+; not ARMv7-M)
## - NOT supported: MIPS32, SPARC32, PowerPC32, RISC-V 32
##
## **16-byte atomics** (`hasLockFree16`):
## - x86-64 (CMPXCHG16B, standard since ~2006)
## - ARM64 (LDXP/STXP; full 128-bit atomicity requires ARMv8.4+)
## - Use `-d:nimNoLockFree16` to disable for old x86-64 CPUs without CMPXCHG16B
##
## Use `isLockFree(T)` or the `LockFree` concept to check at compile-time whether
## a type uses lock-free operations. Non-lock-free types are rejected at compile time.
##
## C++ Backend
## -----------
## By default, lock-free types use fixed-size C++ atomic integers
## (`std::atomic<int8>`, etc.). To use C++'s generic `std::atomic<T>`,
## compile with `-d:nimUseCppAtomics`.
##
## Safety with Managed Types
## -------------------------
## **Important:** Lock-free atomics on managed types (`ref`, `string`, `seq`)
## means the *swap operation* is lock-free, NOT that concurrent access is safe.
##
## Naively using `Atomic[ref T]` leads to memory corruption:
## - **Use-after-free:** Thread A loads pointer, Thread B frees object, Thread A dereferences
## - **ABA problem:** Pointer reused for new object between load and CAS
##
## **Memory manager determines what's possible:**
##
## | Memory Manager     | Lock-free refs? | Notes |
## |--------------------|-----------------|-------|
## | `--mm:refc`        | No              | Thread-local heaps; refs can't cross threads |
## | `--mm:markAndSweep`| No              | Thread-local heaps; refs can't cross threads |
## | `--mm:arc/orc`     | No              | Non-atomic refcount; use locks or `--mm:atomicArc` |
## | `--mm:atomicArc`   | Yes             | Use `GC_ref`/`GC_unref`; prevent ABA and use-after-free |
## | `--mm:boehm`       | Yes             | `GC_ref`/`GC_unref` are no-ops; prevent ABA and use-after-free |
## | `--mm:go`          | Yes             | `GC_ref`/`GC_unref` are no-ops; prevent ABA and use-after-free |
## | `--mm:none`        | Yes             | You manually manage all memory |
##

import std/typetraits

type
  SomeAtomicInt* = SomeInteger | char | enum
    ## Types that support atomic arithmetic and bitwise operations.
    ## Includes all integer types, `char`, and `enum` (all integral types in C/C++).

const
  hasLockFree8* = sizeof(pointer) >= 8 or  # All 64-bit architectures
                  defined(i386) or          # x86-32 has CMPXCHG8B
                  defined(arm)              # ARM32 has LDREXD/STREXD (ARMv6k+)
    ## Whether 8-byte atomics are lock-free on this architecture.
    ##
    ## **True for:**
    ## - All 64-bit CPUs
    ## - x86-32 (CMPXCHG8B)
    ## - ARM32 (LDREXD)
    ##
    ## **False for:** MIPS32, SPARC32, PowerPC32, RISC-V 32

  hasLockFree16* = not defined(nimNoLockFree16) and
                   (defined(amd64) or  # x86-64 has CMPXCHG16B (standard since ~2006)
                    defined(arm64))    # ARM64 has LDXP/STXP
    ## Whether 16-byte atomics are lock-free on this architecture.
    ##
    ## **True for:**
    ## - x86-64 (CMPXCHG16B)
    ## - ARM64 (LDXP/STXP)
    ##
    ## Use `-d:nimNoLockFree16` to disable for old x86-64 CPUs without CMPXCHG16B.

# Concept for types that can use lock-free hardware atomics.
# Used as proc constraint `[T: LockFree]` to restrict atomic operations to lock-free types.
when defined(gcdestructors):
  type LockFree* = concept type T
    (sizeof(T) == 1 or sizeof(T) == 2 or sizeof(T) == 4 or
     (sizeof(T) == 8 and hasLockFree8) or
     (sizeof(T) == 16 and hasLockFree16)) and
    supportsCopyMem(T)
else:
  type LockFree* = concept type T
    sizeof(T) == 1 or sizeof(T) == 2 or sizeof(T) == 4 or
    (sizeof(T) == 8 and hasLockFree8) or
    (sizeof(T) == 16 and hasLockFree16)

template isManaged(T: typedesc): bool =
  # Returns `true` if `T` contains managed memory that prevents lock-free atomics.
  when defined(gcdestructors):
    not supportsCopyMem(T)
  else:
    false

template isLockFree*(T: typedesc): bool =
  ## Returns `true` if `Atomic[T]` uses lock-free hardware atomics,
  ## `false` if it falls back to a spinlock.
  ##
  ## Lock-free requires:
  ## - `sizeof(T)` must be 1, 2, 4, 8, or 16 bytes
  ## - 8-byte requires `hasLockFree8`
  ## - 16-byte requires `hasLockFree16`
  ## - `supportsCopyMem(T)` (no managed memory) for destructor-based MMs
  (sizeof(T) == 1 or sizeof(T) == 2 or sizeof(T) == 4 or
   (sizeof(T) == 8 and hasLockFree8) or
   (sizeof(T) == 16 and hasLockFree16)) and not isManaged(T)

runnableExamples:
  # Check lock-free status at compile time
  assert isLockFree(int)
  assert isLockFree(bool)

  type Point = object
    x, y: int32
  assert isLockFree(Point) == (sizeof(Point) <= sizeof(pointer))

  # Large types use spinlock fallback
  type BigArray = array[100, int]
  assert not isLockFree(BigArray)

runnableExamples:
  # Atomic
  var loc: Atomic[int]
  loc.store(4)
  assert loc.load == 4
  loc.store(2)
  assert loc.load(moRelaxed) == 2
  loc.store(9)
  assert loc.load(moAcquire) == 9
  loc.store(0, moRelease)
  assert loc.load == 0

  assert loc.exchange(7) == 0
  assert loc.load == 7

  var expected = 7
  assert loc.compareExchange(expected, 5, moRelaxed, moRelaxed)
  assert expected == 7
  assert loc.load == 5

  assert not loc.compareExchange(expected, 12, moRelaxed, moRelaxed)
  assert expected == 5
  assert loc.load == 5

  assert loc.fetchAdd(1) == 5
  assert loc.fetchAdd(2) == 6
  assert loc.fetchSub(3) == 8

  loc.atomicInc(1)
  assert loc.load == 6

  # AtomicFlag
  var flag: AtomicFlag

  assert not flag.testAndSet
  assert flag.testAndSet
  flag.clear(moRelaxed)
  assert not flag.testAndSet

# Wait/Notify Implementation
# ===========================
# Platform-specific blocking primitives

import std/times

const
  hasDarwinUlock = defined(macosx) or defined(ios) or defined(tvos) or defined(watchos)
    ## True when Darwin __ulock_wait/__ulock_wake syscalls are available.
    ## Supports 32 and 64-bit atomics.

# Concept for types that support wait/notify operations.
# Size requirements vary by platform:
# - Linux/FreeBSD/OpenBSD: 4 bytes only (futex)
# - Windows: 1, 2, 4, or 8 bytes (WaitOnAddress)
# - Darwin: 4 or 8 bytes (ulock)
when defined(linux) or defined(freebsd) or defined(openbsd):
  type Waitable* = concept type T
    sizeof(T) == 4
elif defined(windows):
  type Waitable* = concept type T
    sizeof(T) in {1, 2, 4, 8}
elif hasDarwinUlock:
  type Waitable* = concept type T
    sizeof(T) in {4, 8}
else:
  type Waitable* = concept type T
    false  # Unsupported platform

# Platform-specific wait/notify implementations
when defined(linux):
  type Timespec {.importc: "struct timespec", header: "<time.h>", final, pure, completeStruct.} = object
    tv_sec: int
    tv_nsec: int

  const
    FUTEX_WAIT_PRIVATE = 128
    FUTEX_WAKE_PRIVATE = 129

  when defined(amd64):
    proc syscall(number: clong): clong {.importc, header: "<unistd.h>", varargs.}
    const SYS_futex = 202
  elif defined(i386):
    proc syscall(number: clong): clong {.importc, header: "<unistd.h>", varargs.}
    const SYS_futex = 240
  elif defined(arm):
    proc syscall(number: clong): clong {.importc, header: "<unistd.h>", varargs.}
    const SYS_futex = 240
  elif defined(arm64):
    proc syscall(number: clong): clong {.importc, header: "<unistd.h>", varargs.}
    const SYS_futex = 98
  else:
    proc syscall(number: clong): clong {.importc, header: "<unistd.h>", varargs.}
    var SYS_futex {.importc: "SYS_futex", header: "<sys/syscall.h>".}: clong

  proc futexWait(address: ptr int32, expected: int32, timeoutUs: int = -1): bool =
    ## Returns true if woken by notify, false on timeout or spurious wakeup.
    var ts: Timespec
    var tsPtr: pointer = nil
    if timeoutUs >= 0:
      ts.tv_sec = timeoutUs div 1_000_000
      ts.tv_nsec = (timeoutUs mod 1_000_000) * 1000
      tsPtr = addr ts
    let res = syscall(SYS_futex, address, FUTEX_WAIT_PRIVATE, expected.clong, tsPtr)
    result = res == 0 or res == -1

  proc futexWakeOne(address: ptr int32) =
    discard syscall(SYS_futex, address, FUTEX_WAKE_PRIVATE, 1.clong)

  proc futexWakeAll(address: ptr int32) =
    discard syscall(SYS_futex, address, FUTEX_WAKE_PRIVATE, high(clong))

when defined(windows):
  # Link synchronization library for MinGW; VCC links Windows SDK automatically
  when not defined(vcc):
    {.passL: "-lsynchronization".}

  proc WaitOnAddress(address: pointer, compareAddress: pointer,
                     addressSize: csize_t, dwMilliseconds: int32): int32
                     {.importc, header: "<synchapi.h>", stdcall.}
  proc WakeByAddressSingle(address: pointer)
                           {.importc, header: "<synchapi.h>", stdcall.}
  proc WakeByAddressAll(address: pointer)
                        {.importc, header: "<synchapi.h>", stdcall.}

  const INFINITE = -1'i32

  proc windowsWait[T](address: ptr T, expected: T, timeoutUs: int = -1): bool =
    var exp = expected
    let ms = if timeoutUs < 0: INFINITE else: int32(timeoutUs div 1000)
    result = WaitOnAddress(address, addr exp, csize_t(sizeof(T)), ms) != 0

when hasDarwinUlock:
  const
    UL_COMPARE_AND_WAIT = 1'u32
    ULF_WAKE_ALL = 0x00000100'u32

  proc ulockWait(operation: uint32, address: pointer, value: uint64,
                 timeout: uint32): cint {.importc: "__ulock_wait", dynlib: "libSystem.B.dylib".}
  proc ulockWake(operation: uint32, address: pointer,
                 wake_value: uint64): cint {.importc: "__ulock_wake", dynlib: "libSystem.B.dylib".}

  proc darwinWait32(address: ptr uint32, expected: uint32, timeoutUs: int = -1): bool =
    let timeout = if timeoutUs < 0: 0'u32 else: uint32(timeoutUs)
    let res = ulockWait(UL_COMPARE_AND_WAIT, address, expected.uint64, timeout)
    result = res == 0

  proc darwinWait64(address: ptr uint64, expected: uint64, timeoutUs: int = -1): bool =
    let timeout = if timeoutUs < 0: 0'u32 else: uint32(timeoutUs)
    let res = ulockWait(UL_COMPARE_AND_WAIT, address, expected, timeout)
    result = res == 0

  proc darwinWakeOne(address: pointer) =
    discard ulockWake(UL_COMPARE_AND_WAIT, address, 0)

  proc darwinWakeAll(address: pointer) =
    while ulockWake(UL_COMPARE_AND_WAIT or ULF_WAKE_ALL, address, 0) >= 0:
      discard

when defined(freebsd):
  # FreeBSD _umtx_op - supports 32-bit atomics
  type Timespec {.importc: "struct timespec", header: "<time.h>", final, pure, completeStruct.} = object
    tv_sec: int
    tv_nsec: int

  const
    UMTX_OP_WAIT_UINT_PRIVATE = 15  # Wait on 32-bit value (process-private)
    UMTX_OP_WAKE_PRIVATE = 16       # Wake waiters (process-private)

  type UmtxTime {.importc: "struct _umtx_time", header: "<sys/umtx.h>", final, pure.} = object
    timeout: Timespec
    flags: uint32
    clockid: uint32

  proc umtxOp(obj: pointer, op: cint, val: culong, uaddr: pointer,
              uaddr2: pointer): cint {.importc: "_umtx_op", header: "<sys/umtx.h>".}

  proc freebsdWait(address: ptr uint32, expected: uint32, timeoutUs: int = -1): bool =
    if timeoutUs < 0:
      let res = umtxOp(address, UMTX_OP_WAIT_UINT_PRIVATE, expected.culong, nil, nil)
      result = res == 0 or res == -1
    else:
      var ut: UmtxTime
      ut.timeout.tv_sec = timeoutUs div 1_000_000
      ut.timeout.tv_nsec = (timeoutUs mod 1_000_000) * 1000
      ut.flags = 0
      ut.clockid = 0  # CLOCK_REALTIME
      let res = umtxOp(address, UMTX_OP_WAIT_UINT_PRIVATE, expected.culong,
                       cast[pointer](sizeof(UmtxTime)), addr ut)
      result = res == 0 or res == -1

  proc freebsdWakeOne(address: ptr uint32) =
    discard umtxOp(address, UMTX_OP_WAKE_PRIVATE, 1, nil, nil)

  proc freebsdWakeAll(address: ptr uint32) =
    discard umtxOp(address, UMTX_OP_WAKE_PRIVATE, high(culong), nil, nil)

when defined(openbsd):
  # OpenBSD futex - supports 32-bit atomics (added in OpenBSD 6.2)
  type Timespec {.importc: "struct timespec", header: "<time.h>", final, pure, completeStruct.} = object
    tv_sec: int
    tv_nsec: int

  const
    FUTEX_WAIT = 1
    FUTEX_WAKE = 2

  proc futex(uaddr: pointer, op: cint, val: cint, timeout: pointer,
             uaddr2: pointer): cint {.importc, header: "<sys/futex.h>".}

  proc openbsdWait(address: ptr int32, expected: int32, timeoutUs: int = -1): bool =
    var ts: Timespec
    var tsPtr: pointer = nil
    if timeoutUs >= 0:
      ts.tv_sec = timeoutUs div 1_000_000
      ts.tv_nsec = (timeoutUs mod 1_000_000) * 1000
      tsPtr = addr ts
    let res = futex(address, FUTEX_WAIT, expected.cint, tsPtr, nil)
    result = res == 0 or res == -1

  proc openbsdWakeOne(address: ptr int32) =
    discard futex(address, FUTEX_WAKE, 1, nil, nil)

  proc openbsdWakeAll(address: ptr int32) =
    discard futex(address, FUTEX_WAKE, high(cint), nil, nil)

when (defined(cpp) and defined(nimUseCppAtomics)) or defined(nimdoc):
  # For the C++ backend, types and operations map directly to C++11 atomics.

  # On Linux with GCC/Clang, 16-byte atomic operations may not be inlined
  # and require libatomic even when using C++ std::atomic.
  when defined(linux) and hasLockFree16:
    {.passL: "-latomic".}

  {.push, header: "<atomic>".}

  type
    MemoryOrder* {.importcpp: "std::memory_order".} = enum
      ## Specifies how non-atomic operations can be reordered around atomic
      ## operations.

      moRelaxed
        ## No ordering constraints. Only the atomicity and ordering against
        ## other atomic operations is guaranteed.

      moConsume
        ## This ordering is currently discouraged as it's semantics are
        ## being revised. Acquire operations should be preferred.

      moAcquire
        ## When applied to a load operation, no reads or writes in the
        ## current thread can be reordered before this operation.

      moRelease
        ## When applied to a store operation, no reads or writes in the
        ## current thread can be reorderd after this operation.

      moAcquireRelease
        ## When applied to a read-modify-write operation, this behaves like
        ## both an acquire and a release operation.

      moSequentiallyConsistent
        ## Behaves like Acquire when applied to load, like Release when
        ## applied to a store and like AcquireRelease when applied to a
        ## read-modify-write operation.
        ## Also guarantees that all threads observe the same total ordering
        ## with other moSequentiallyConsistent operations.

  type
    Atomic*[T] {.importcpp: "std::atomic", completeStruct.} = object
      ## An atomic object with underlying type `T`.
      raw: T

    AtomicFlag* {.importcpp: "std::atomic_flag", size: 1.} = object
      ## An atomic boolean state.

  # Access operations - internal importcpp procs

  proc loadImpl[T](location: var Atomic[T]; order: MemoryOrder): T {.importcpp: "#.load(@)", inline.}
  proc storeImpl[T](location: var Atomic[T]; desired: T; order: MemoryOrder) {.importcpp: "#.store(@)", inline.}

  proc load*[T: LockFree](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    ## Atomically obtains the value of the atomic object.
    loadImpl(location, order)

  proc store*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
    ## Atomically replaces the value of the atomic object with the `desired`
    ## value.
    storeImpl(location, desired, order)

  proc exchangeImpl[T](location: var Atomic[T]; desired: T; order: MemoryOrder): T {.importcpp: "#.exchange(@)", inline.}
  proc compareExchangeImpl[T](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder): bool {.importcpp: "#.compare_exchange_strong(@)", inline.}
  proc compareExchangeImpl[T](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.importcpp: "#.compare_exchange_strong(@)", inline.}
  proc compareExchangeWeakImpl[T](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder): bool {.importcpp: "#.compare_exchange_weak(@)", inline.}
  proc compareExchangeWeakImpl[T](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.importcpp: "#.compare_exchange_weak(@)", inline.}

  proc exchange*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    ## Atomically replaces the value of the atomic object with the `desired`
    ## value and returns the old value.
    exchangeImpl(location, desired, order)

  proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    ## Atomically compares the value of the atomic object with the `expected`
    ## value and performs exchange with the `desired` one if equal or load if
    ## not. Returns true if the exchange was successful.
    compareExchangeImpl(location, expected, desired, order)

  proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    ## Same as above, but allows for different memory orders for success and
    ## failure.
    compareExchangeImpl(location, expected, desired, success, failure)

  proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    ## Same as above, but is allowed to fail spuriously.
    compareExchangeWeakImpl(location, expected, desired, order)

  proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    ## Same as above, but allows for different memory orders for success and
    ## failure.
    compareExchangeWeakImpl(location, expected, desired, success, failure)

  # Numerical operations

  proc fetchAdd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importcpp: "#.fetch_add(@)".}
    ## Atomically adds `value` to the atomic value and returns the original.

  proc fetchSub*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importcpp: "#.fetch_sub(@)".}
    ## Atomically subtracts `value` from the atomic value and returns the original.

  proc fetchAnd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importcpp: "#.fetch_and(@)".}
    ## Atomically performs bitwise AND with `value` and returns the original.

  proc fetchOr*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importcpp: "#.fetch_or(@)".}
    ## Atomically performs bitwise OR with `value` and returns the original.

  proc fetchXor*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importcpp: "#.fetch_xor(@)".}
    ## Atomically performs bitwise XOR with `value` and returns the original.

  # Flag operations

  proc testAndSet*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent): bool {.importcpp: "#.test_and_set(@)".}
    ## Atomically sets the atomic flag to true and returns the original value.

  proc clear*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent) {.importcpp: "#.clear(@)".}
    ## Atomically sets the value of the atomic flag to false.

  proc fence*(order: MemoryOrder) {.importcpp: "std::atomic_thread_fence(@)".}
    ## Ensures memory ordering without using atomic operations.

  proc signalFence*(order: MemoryOrder) {.importcpp: "std::atomic_signal_fence(@)".}
    ## Prevents reordering of accesses by the compiler as would fence, but
    ## inserts no CPU instructions for memory ordering.

  {.pop.}

else:
  # For the C backend, atomics map to C11 built-ins on GCC and Clang for
  # lock-free types. Other types are implemented using spin locks.

  # Since MSVC does not implement C11, we fall back to MS intrinsics
  # where available.

  type
    # 128-bit integer type for 16-byte atomics
    Int128 {.importc: "__int128", nodecl.} = object
      lo, hi: int64

  template nonAtomicType*(T: typedesc): untyped =
    ## Maps types to integers of the same size for atomic storage.
    when sizeof(T) == 1: int8
    elif sizeof(T) == 2: int16
    elif sizeof(T) == 4: int32
    elif sizeof(T) == 8: int64
    elif sizeof(T) == 16: Int128
    else:
      {.error: "nonAtomicType only supports types of size 1, 2, 4, 8, or 16 bytes".}

  when defined(vcc):

    # TODO: Lock-free types should be volatile and use VC's special volatile
    # semantics for store and loads.

    type
      MemoryOrder* = enum
        moRelaxed
        moConsume
        moAcquire
        moRelease
        moAcquireRelease
        moSequentiallyConsistent

      AtomicFlag* = distinct int8

      Atomic*[T] = object
        value: T.nonAtomicType

    {.push header: "<intrin.h>".}

    # MSVC intrinsics
    proc interlockedExchange(location: pointer; desired: int8): int8 {.importc: "_InterlockedExchange8".}
    proc interlockedExchange(location: pointer; desired: int16): int16 {.importc: "_InterlockedExchange16".}
    proc interlockedExchange(location: pointer; desired: int32): int32 {.importc: "_InterlockedExchange".}
    proc interlockedExchange(location: pointer; desired: int64): int64 {.importc: "_InterlockedExchange64".}

    proc interlockedCompareExchange(location: pointer; desired, expected: int8): int8 {.importc: "_InterlockedCompareExchange8".}
    proc interlockedCompareExchange(location: pointer; desired, expected: int16): int16 {.importc: "_InterlockedCompareExchange16".}
    proc interlockedCompareExchange(location: pointer; desired, expected: int32): int32 {.importc: "_InterlockedCompareExchange".}
    proc interlockedCompareExchange(location: pointer; desired, expected: int64): int64 {.importc: "_InterlockedCompareExchange64".}

    # 128-bit compare-exchange for 16-byte atomics (amd64/arm64)
    # Returns 1 if exchange succeeded, 0 otherwise
    # Destination is the 128-bit value to modify
    # ExchangeHigh:ExchangeLow is the new value
    # ComparandResult points to the expected value (updated on failure)
    proc interlockedCompareExchange128(destination: pointer; exchangeHigh, exchangeLow: int64;
                                        comparandResult: pointer): uint8 {.importc: "_InterlockedCompareExchange128".}

    proc interlockedAnd(location: pointer; value: int8): int8 {.importc: "_InterlockedAnd8".}
    proc interlockedAnd(location: pointer; value: int16): int16 {.importc: "_InterlockedAnd16".}
    proc interlockedAnd(location: pointer; value: int32): int32 {.importc: "_InterlockedAnd".}
    proc interlockedAnd(location: pointer; value: int64): int64 {.importc: "_InterlockedAnd64".}

    proc interlockedOr(location: pointer; value: int8): int8 {.importc: "_InterlockedOr8".}
    proc interlockedOr(location: pointer; value: int16): int16 {.importc: "_InterlockedOr16".}
    proc interlockedOr(location: pointer; value: int32): int32 {.importc: "_InterlockedOr".}
    proc interlockedOr(location: pointer; value: int64): int64 {.importc: "_InterlockedOr64".}

    proc interlockedXor(location: pointer; value: int8): int8 {.importc: "_InterlockedXor8".}
    proc interlockedXor(location: pointer; value: int16): int16 {.importc: "_InterlockedXor16".}
    proc interlockedXor(location: pointer; value: int32): int32 {.importc: "_InterlockedXor".}
    proc interlockedXor(location: pointer; value: int64): int64 {.importc: "_InterlockedXor64".}

    proc fence(order: MemoryOrder): int64 {.importc: "_ReadWriteBarrier()".}
    proc signalFence(order: MemoryOrder): int64 {.importc: "_ReadWriteBarrier()".}

    {.pop.}

    proc testAndSet*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent): bool =
      interlockedOr(addr(location), 1'i8) == 1'i8
    proc clear*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent) =
      discard interlockedAnd(addr(location), 0'i8)

    proc load*[T: LockFree](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](interlockedOr(addr(location.value), (nonAtomicType(T))0))

    proc store*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
      discard interlockedExchange(addr(location.value), cast[nonAtomicType(T)](desired))

    proc exchange*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](interlockedExchange(addr(location.value), cast[int64](desired)))

    proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
      cast[T](interlockedCompareExchange(addr(location.value), cast[nonAtomicType(T)](desired), cast[nonAtomicType(T)](expected))) == expected

    proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
      compareExchange(location, expected, desired, order, order)

    proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
      compareExchange(location, expected, desired, success, failure)

    proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
      compareExchangeWeak(location, expected, desired, order, order)

    proc fetchAdd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      var currentValue = location.load()
      while not compareExchangeWeak(location, currentValue, currentValue + value): discard
    proc fetchSub*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      fetchAdd(location, -value, order)
    proc fetchAnd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](interlockedAnd(addr(location.value), cast[nonAtomicType(T)](value)))
    proc fetchOr*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](interlockedOr(addr(location.value), cast[nonAtomicType(T)](value)))
    proc fetchXor*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](interlockedXor(addr(location.value), cast[nonAtomicType(T)](value)))

  else:
    # On Linux with GCC/Clang, 16-byte atomic operations (__atomic_load_16,
    # __atomic_store_16, etc.) may not be inlined and require libatomic.
    # See: https://github.com/STEllAR-GROUP/hpx/issues/3342
    when defined(linux) and hasLockFree16:
      {.passL: "-latomic".}

    when defined(cpp):
      {.push, header: "<atomic>".}
      template maybeWrapStd(x: string): string =
        "std::" & x
    else:
      {.push, header: "<stdatomic.h>".}
      template maybeWrapStd(x: string): string =
        x

    type
      MemoryOrder* {.importc: "memory_order".maybeWrapStd.} = enum
        moRelaxed
        moConsume
        moAcquire
        moRelease
        moAcquireRelease
        moSequentiallyConsistent

    when defined(cpp):
      type
        # Atomic*[T] {.importcpp: "_Atomic('0)".} = object

        AtomicInt8 {.importc: "std::atomic<NI8>".} = int8
        AtomicInt16 {.importc: "std::atomic<NI16>".} = int16
        AtomicInt32 {.importc: "std::atomic<NI32>".} = int32
        AtomicInt64 {.importc: "std::atomic<NI64>".} = int64
        AtomicInt128 {.importc: "std::atomic<__int128>".} = Int128
    else:
      type
        # Atomic*[T] {.importcpp: "_Atomic('0)".} = object

        AtomicInt8 {.importc: "_Atomic NI8".} = int8
        AtomicInt16 {.importc: "_Atomic NI16".} = int16
        AtomicInt32 {.importc: "_Atomic NI32".} = int32
        AtomicInt64 {.importc: "_Atomic NI64".} = int64
        AtomicInt128 {.importc: "_Atomic __int128".} = Int128

    type
      AtomicFlag* {.importc: "atomic_flag".maybeWrapStd, size: 1.} = object

      Atomic*[T] = object
        # Maps the size of a lock-free type to its internal atomic type
        when sizeof(T) == 1: value: AtomicInt8
        elif sizeof(T) == 2: value: AtomicInt16
        elif sizeof(T) == 4: value: AtomicInt32
        elif sizeof(T) == 8: value: AtomicInt64
        elif sizeof(T) == 16: value: AtomicInt128

    #proc init*[T](location: var Atomic[T]; value: T): T {.importcpp: "atomic_init(@)".}
    proc atomic_load_explicit[T, A](location: ptr A; order: MemoryOrder): T {.importc: "atomic_load_explicit".maybeWrapStd.}
    proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.importc: "atomic_store_explicit".maybeWrapStd.}
    proc atomic_exchange_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_exchange_explicit".maybeWrapStd.}
    proc atomic_compare_exchange_strong_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc: "atomic_compare_exchange_strong_explicit".maybeWrapStd.}
    proc atomic_compare_exchange_weak_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc: "atomic_compare_exchange_weak_explicit".maybeWrapStd.}

    # Numerical operations
    proc atomic_fetch_add_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_fetch_add_explicit".maybeWrapStd.}
    proc atomic_fetch_sub_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_fetch_sub_explicit".maybeWrapStd.}
    proc atomic_fetch_and_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_fetch_and_explicit".maybeWrapStd.}
    proc atomic_fetch_or_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_fetch_or_explicit".maybeWrapStd.}
    proc atomic_fetch_xor_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc: "atomic_fetch_xor_explicit".maybeWrapStd.}

    # Flag operations
    # var ATOMIC_FLAG_INIT {.importc, nodecl.}: AtomicFlag
    # proc init*(location: var AtomicFlag) {.inline.} = location = ATOMIC_FLAG_INIT
    proc testAndSet*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent): bool {.importc: "atomic_flag_test_and_set_explicit".maybeWrapStd.}
    proc clear*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent) {.importc: "atomic_flag_clear_explicit".maybeWrapStd.}

    proc fence*(order: MemoryOrder) {.importc: "atomic_thread_fence".maybeWrapStd.}
    proc signalFence*(order: MemoryOrder) {.importc: "atomic_signal_fence".maybeWrapStd.}

    {.pop.}

    proc load*[T: LockFree](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_load_explicit[nonAtomicType(T), typeof(location.value)](addr(location.value), order))

    proc store*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
      atomic_store_explicit(addr(location.value), cast[nonAtomicType(T)](desired), order)

    proc exchange*[T: LockFree](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_exchange_explicit(addr(location.value), cast[nonAtomicType(T)](desired), order))

    proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
      atomic_compare_exchange_strong_explicit(addr(location.value), cast[ptr nonAtomicType(T)](addr(expected)), cast[nonAtomicType(T)](desired), success, failure)

    proc compareExchange*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
      compareExchange(location, expected, desired, order, order)

    proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
      atomic_compare_exchange_weak_explicit(addr(location.value), cast[ptr nonAtomicType(T)](addr(expected)), cast[nonAtomicType(T)](desired), success, failure)

    proc compareExchangeWeak*[T: LockFree](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
      compareExchangeWeak(location, expected, desired, order, order)

    # Numerical operations
    proc fetchAdd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_fetch_add_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
    proc fetchSub*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_fetch_sub_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
    proc fetchAnd*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_fetch_and_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
    proc fetchOr*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_fetch_or_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
    proc fetchXor*[T: SomeAtomicInt](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
      cast[T](atomic_fetch_xor_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))

proc atomicInc*[T: SomeAtomicInt](location: var Atomic[T]; value: T = 1) {.inline.} =
  ## Atomically increments the atomic value by `value`.
  discard location.fetchAdd(value)

proc atomicDec*[T: SomeAtomicInt](location: var Atomic[T]; value: T = 1) {.inline.} =
  ## Atomically decrements the atomic value by `value`.
  discard location.fetchSub(value)

proc `+=`*[T: SomeAtomicInt](location: var Atomic[T]; value: T) {.inline.} =
  ## Atomically increments the atomic value by `value`.
  discard location.fetchAdd(value)

proc `-=`*[T: SomeAtomicInt](location: var Atomic[T]; value: T) {.inline.} =
  ## Atomically decrements the atomic value by `value`.
  discard location.fetchSub(value)

# Wait/notify operations - defined once for all backends
proc wait*[T: Waitable](location: var Atomic[T], expected: T) =
  ## Blocks the calling thread until the atomic value is no longer equal to `expected`,
  ## or until a spurious wakeup occurs. The check and wait are performed atomically.
  ##
  ## This is more efficient than spin-waiting as it allows the thread to sleep.
  ## Use `notifyOne` or `notifyAll` to wake waiting threads.
  ##
  ## Requires `T` to satisfy `Waitable` concept (platform-specific size constraints).
  let address = addr location
  when defined(linux):
    discard futexWait(cast[ptr int32](address), cast[int32](expected))
  elif defined(freebsd):
    discard freebsdWait(cast[ptr uint32](address), cast[uint32](expected))
  elif defined(openbsd):
    discard openbsdWait(cast[ptr int32](address), cast[int32](expected))
  elif defined(windows):
    discard windowsWait(cast[ptr T](address), expected)
  elif hasDarwinUlock and sizeof(T) == 4:
    discard darwinWait32(cast[ptr uint32](address), cast[uint32](expected))
  elif hasDarwinUlock and sizeof(T) == 8:
    discard darwinWait64(cast[ptr uint64](address), cast[uint64](expected))

proc wait*[T: Waitable](location: var Atomic[T], expected: T, timeout: Duration): bool =
  ## Like `wait`, but returns `false` if the timeout expires before being woken.
  ## Returns `true` if woken by notify or value change.
  ##
  ## Requires `T` to satisfy `Waitable` concept (platform-specific size constraints).
  let address = addr location
  let timeoutUs = timeout.inMicroseconds.int
  when defined(linux):
    result = futexWait(cast[ptr int32](address), cast[int32](expected), timeoutUs)
  elif defined(freebsd):
    result = freebsdWait(cast[ptr uint32](address), cast[uint32](expected), timeoutUs)
  elif defined(openbsd):
    result = openbsdWait(cast[ptr int32](address), cast[int32](expected), timeoutUs)
  elif defined(windows):
    result = windowsWait(cast[ptr T](address), expected, timeoutUs)
  elif hasDarwinUlock and sizeof(T) == 4:
    result = darwinWait32(cast[ptr uint32](address), cast[uint32](expected), timeoutUs)
  elif hasDarwinUlock and sizeof(T) == 8:
    result = darwinWait64(cast[ptr uint64](address), cast[uint64](expected), timeoutUs)

proc notifyOne*[T: Waitable](location: var Atomic[T]) =
  ## Wakes at least one thread waiting on `location`.
  ## If no threads are waiting, this is a no-op.
  ##
  ## Requires `T` to satisfy `Waitable` concept (platform-specific size constraints).
  let address = addr location
  when defined(linux):
    futexWakeOne(cast[ptr int32](address))
  elif defined(freebsd):
    freebsdWakeOne(cast[ptr uint32](address))
  elif defined(openbsd):
    openbsdWakeOne(cast[ptr int32](address))
  elif defined(windows):
    WakeByAddressSingle(address)
  elif hasDarwinUlock:
    darwinWakeOne(address)

proc notifyAll*[T: Waitable](location: var Atomic[T]) =
  ## Wakes all threads waiting on `location`.
  ## If no threads are waiting, this is a no-op.
  ##
  ## Requires `T` to satisfy `Waitable` concept (platform-specific size constraints).
  let address = addr location
  when defined(linux):
    futexWakeAll(cast[ptr int32](address))
  elif defined(freebsd):
    freebsdWakeAll(cast[ptr uint32](address))
  elif defined(openbsd):
    openbsdWakeAll(cast[ptr int32](address))
  elif defined(windows):
    WakeByAddressAll(address)
  elif hasDarwinUlock:
    darwinWakeAll(address)
