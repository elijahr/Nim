import std/typetraits

import std/macros

template thisTriggers*(T: typedesc): bool =
  ## Returns `true` if `Atomic[T]` uses lock-free hardware atomics,
  ## `false` if it falls back to a spinlock.
  ##
  ## Lock-free requires:
  ## - `sizeof(T)` must be 1, 2, 4, or 8 bytes (valid atomic sizes)
  ## - `supportsCopyMem(T)` (no managed memory) for destructor-based MMs (arc/orc/atomicArc)
  ## - For non-destructor MMs (refc/none/etc), managed types are pointer-sized and qualify
  sizeof(T) == 8


type
  MyType*[T] = object
    when thisTriggers(T):
      eight: T
    else:
      when sizeof(T) == 4:
        four: T
      else:
        other: T

var mine1 = MyType[int64](eight: 42)
var mine2 = MyType[int32](four: 42)
var mine3 = MyType[int16](other: 42)
