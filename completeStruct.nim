import std/macros  # Required to trigger the bug


template checkSize*(T: typedesc): bool =
  sizeof(T) <= 8

type Generic*[T] = object
  when checkSize(T):
    small: T
  else:
    large: ptr T


type
  IsGenericSmall*[T] = concept
    sizeof(T) <= 8

var x: Generic[int]
var y: Generic[array[100, int]]

doAssert x.small == 0
doAssert y.large == nil


proc echoSmallOnly*[T: IsGenericSmall](g: Generic[T]) =
  echo g.small

proc echoLargeOnly*[T: not IsGenericSmall](g: Generic[T]) =
  echo g.large

# Works
echoSmallOnly(Generic[int](small: 42))
echoLargeOnly(Generic[array[100, int]](large: nil))

# Fails
echoSmallOnly(Generic[array[100, int]](large: nil))
echoLargeOnly(Generic[int](small: 42))
