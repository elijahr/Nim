discard """
action: "run"
output: '''
int is Trivial: true
MyInt is Trivial: true
MyMyInt is Trivial: true
DeepInt is Trivial: true
float is Trivial: false
string is Trivial: false
char is Base: true
ptr int is Base: true
'''
"""

# Test recursive concepts with cycle detection
# This tests the fix for concepts that reference themselves via distinctBase

import std/typetraits

block: # Basic recursive concept with distinctBase
  type
    Base = SomeInteger | bool | char | ptr | pointer

    # Recursive concept: matches Base directly OR any distinct type whose base is Trivial
    Trivial = concept x
      x is Base or distinctBase(x) is Trivial

    MyInt = distinct int
    MyMyInt = distinct MyInt
    DeepInt = distinct MyMyInt

  # Direct base types should match
  echo "int is Trivial: ", int is Trivial

  # Single-level distinct should match
  echo "MyInt is Trivial: ", MyInt is Trivial

  # Two-level distinct should match
  echo "MyMyInt is Trivial: ", MyMyInt is Trivial

  # Three-level distinct should match
  echo "DeepInt is Trivial: ", DeepInt is Trivial

  # Non-trivial types should NOT match
  echo "float is Trivial: ", float is Trivial
  echo "string is Trivial: ", string is Trivial

block: # Ensure base type matching still works
  type
    Base = SomeInteger | bool | char | ptr | pointer

  echo "char is Base: ", char is Base
  echo "ptr int is Base: ", (ptr int) is Base

block: # Test that cycle detection doesn't break normal concept matching
  type
    Addable = concept x, y
      x + y is typeof(x)

  doAssert int is Addable
  doAssert float is Addable
  # Note: string uses & for concat, not +, so it's not Addable

block: # Test non-matching recursive case
  type
    OnlyInt = SomeInteger

    IntOrDistinctInt = concept x
      x is OnlyInt or distinctBase(x) is IntOrDistinctInt

    MyFloat = distinct float

  doAssert int is IntOrDistinctInt
  doAssert not(float is IntOrDistinctInt)
  doAssert not(MyFloat is IntOrDistinctInt)  # float base doesn't match

block: # Test deep distinct chains (5+ levels)
  type
    Base = SomeInteger

    DeepTrivial = concept x
      x is Base or distinctBase(x) is DeepTrivial

    D1 = distinct int
    D2 = distinct D1
    D3 = distinct D2
    D4 = distinct D3
    D5 = distinct D4

  doAssert int is DeepTrivial
  doAssert D1 is DeepTrivial
  doAssert D2 is DeepTrivial
  doAssert D3 is DeepTrivial
  doAssert D4 is DeepTrivial
  doAssert D5 is DeepTrivial
  doAssert not(float is DeepTrivial)

block: # Test 3-way mutual recursion (co-dependent concepts)
  # This tests that cycle detection properly handles A -> B -> C -> A cycles
  type
    ConceptA = concept
      proc toB(x: Self): ConceptB

    ConceptB = concept
      proc toC(x: Self): ConceptC

    ConceptC = concept
      proc toA(x: Self): ConceptA

    Chain = object
      value: int

  proc toB(x: Chain): Chain = x
  proc toC(x: Chain): Chain = x
  proc toA(x: Chain): Chain = x

  # Chain should satisfy all three mutually recursive concepts
  doAssert Chain is ConceptA
  doAssert Chain is ConceptB
  doAssert Chain is ConceptC

block: # Test multiple operations in same concept
  type
    Arithmetic = concept a, b
      a + b is typeof(a)
      a - b is typeof(a)
      a * b is typeof(a)

  doAssert int is Arithmetic
  doAssert float is Arithmetic

block: # Test concept with method returning same type
  type
    Duplicable = concept
      proc dup(x: Self): Self

    MyObj = object
      data: int

  proc dup(x: MyObj): MyObj = x

  doAssert MyObj is Duplicable
