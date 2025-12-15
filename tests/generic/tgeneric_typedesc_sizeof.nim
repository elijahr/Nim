discard """
  description: '''
  Regression test for semtypinst.nim hasValuelessStatics bug.

  Bug: hasValuelessStatics only checked for tyStatic, missing tyTypeDesc(tyGenericParam)
  Fix: Added check for tyTypeDesc wrapping tyGenericParam in compiler/semtypinst.nim

  The bug triggers when:
  1. A generic type has `when isLockFree(T):` in its definition
  2. A generic proc on that type ALSO has `when isLockFree(T):` in its body
  3. The proc is called, triggering instantiation of both

  Error without fix: 'sizeof' requires '.importc' types to be '.completeStruct'
  '''
  output: '''
42
'''
"""

import std/typetraits

template isLockFree*(T: typedesc): bool =
  (sizeof(T) == 1 or sizeof(T) == 2 or sizeof(T) == 4 or sizeof(T) == 8) and supportsCopyMem(T)

# Generic type with when isLockFree(T) in definition
type MyAtomic*[T] = object
  when isLockFree(T):
    value: T
  else:
    value: T
    guard: int8

# Generic proc with when isLockFree(T) in body
proc load*[T](location: var MyAtomic[T]): T {.inline.} =
  when isLockFree(T):
    result = location.value
  else:
    result = location.value

var x: MyAtomic[int]
x.value = 42
echo x.load()
