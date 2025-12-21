=======================
Nim's Memory Management
=======================

.. default-role:: code
.. include:: rstcommon.rst

:Author: Andreas Rumpf
:Version: |nimversion|

..


> "The road to hell is paved with good intentions."


Multi-paradigm Memory Management Strategies
===========================================

.. default-role:: option

Nim offers multiple different memory management strategies.
To choose the memory management strategy use the `--mm:` switch.

 .. hint:: **The recommended switch for newly written Nim code is `--mm:orc`.**


ARC/ORC
-------

ORC is the default memory management strategy. It is a memory
management mode primarily based on reference counting. Reference cycles are
handled by a cycle collection mechanism based on "trial deletion".
Since algorithms based on "tracing" are not used, the runtime behavior is oblivious to the involved heap and stack sizes.

The reference counting operations (= "RC ops") do not use atomic instructions and do not have to --
instead entire subgraphs are *moved* between threads. The Nim compiler also aggressively
optimizes away RC ops and exploits [move semantics](destructors.html#move-semantics).

Nim performs a fair share of optimizations for ARC/ORC; you can inspect what it did
to your time critical function via `--expandArc:functionName`. Likewise, you can inspect the whole module via `--expandArc:fileName`.

`--mm:arc` uses the same mechanism as `--mm:orc`, but it leaves out the cycle collector.
Both ARC and ORC offer deterministic performance for `hard realtime`:idx: systems, but
ARC can be easier to reason about for people coming from Ada/C++/C -- roughly speaking
the memory for a variable is freed when it goes "out of scope".

We generally advise you to use the `acyclic` annotation in order to optimize away the
cycle collector's overhead
but `--mm:orc` also produces more machine code than `--mm:arc`, so if you're on a target
where code size matters and you know that your code does not produce cycles, you can
use `--mm:arc`. Notice that the default `async`:idx: implementation produces cycles
and leaks memory with `--mm:arc`, in other words, for `async` you need to use `--mm:orc`.


Atomic ARC: Lock-Free Reference Operations
-------------------------------------------

When using `--mm:atomicArc`, Nim provides low-level primitives for safe lock-free access
to shared references. These primitives are necessary because with atomic reference counting,
simply loading a reference from shared memory and then incrementing its refcount is not
atomic - another thread could decrement the refcount to zero and destroy the object between
the load and the increment, causing a use-after-free bug.

atomicLoadAndRef
~~~~~~~~~~~~~~~~

.. code-block:: nim

  proc atomicLoadAndRef*[T](location: ptr (ref T)): ref T

Atomically loads a reference from a shared location and increments its reference count
in a single logical operation. This prevents the use-after-free race condition that would
occur with separate load and increment operations.

**Returns:** The loaded reference, or `nil` if:

- The location contains `nil`
- The object is being concurrently destroyed (refcount reached zero)

**Usage:**

.. code-block:: nim

  var sharedHead: ref Node  # Shared between threads

  # Thread A: Safe load
  let node = atomicLoadAndRef(addr sharedHead)
  if node != nil:
    use(node)
    GC_unref(node)  # Release when done

atomicStoreAndUnref
~~~~~~~~~~~~~~~~~~~

.. code-block:: nim

  proc atomicStoreAndUnref*[T](location: ptr (ref T), newValue: ref T)

Atomically stores a new reference and properly manages the reference counts of both
the new and old values.

**Usage:**

.. code-block:: nim

  # Thread B: Safe store
  let newNode = new(Node)
  atomicStoreAndUnref(addr sharedHead, newNode)

When to Use
~~~~~~~~~~~

Use these primitives when:

- Building lock-free data structures (stacks, queues, lists)
- Sharing `ref` objects between threads without locks
- Implementing concurrent algorithms with managed memory

**Important:** These are low-level primitives. Most applications should use higher-level
abstractions like channels or thread-safe queues.


Other MM modes
--------------

.. note:: The `refc` GC is incremental, thread-local and not "stop-the-world".

--mm:refc    It's a deferred reference counting based garbage collector
  with a simple Mark&Sweep backup GC in order to collect cycles.
  Heaps are thread-local. [This document](refc.html) contains further information.
--mm:markAndSweep  Simple Mark-And-Sweep based garbage collector.
  Heaps are thread-local.
--mm:boehm    Boehm based garbage collector, it offers a shared heap.
--mm:go    Go's garbage collector, useful for interoperability with Go.
  Offers a shared heap.

--mm:none    No memory management strategy nor a garbage collector. Allocated memory is
  simply never freed. You should use `--mm:arc` instead.

Here is a comparison of the different memory management modes:

================== ======== ================= ============== ====== =================== ===================
Memory Management  Heap     Reference Cycles  Stop-The-World Atomic Valgrind compatible Command line switch
================== ======== ================= ============== ====== =================== ===================
ORC                Shared   Cycle Collector   No             No     Yes                 `--mm:orc`
ARC                Shared   Leak              No             No     Yes                 `--mm:arc`
Atomic ARC         Shared   Leak              No             Yes    Yes                 `--mm:atomicArc`
RefC               Local    Cycle Collector   No             No     No                  `--mm:refc`
Mark & Sweep       Local    Cycle Collector   No             No     No                  `--mm:markAndSweep`
Boehm              Shared   Cycle Collector   Yes            No     No                  `--mm:boehm`
Go                 Shared   Cycle Collector   Yes            No     No                  `--mm:go`
None               Manual   Manual            Manual         Manual Manual              `--mm:none`
================== ======== ================= ============== ====== =================== ===================

.. default-role:: code
.. include:: rstcommon.rst

JavaScript's garbage collector is used for the [JavaScript and NodeJS](
backends.html#backends-the-javascript-target) compilation targets.
The [NimScript](nims.html) target uses the memory management strategy built into
the Nim compiler.
