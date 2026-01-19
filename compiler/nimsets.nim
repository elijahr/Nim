#
#
#           The Nim Compiler
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# this unit handles Nim sets; it implements symbolic sets

import
  ast, astalgo, lineinfos, bitsets, types, options, modulegraphs

when defined(nimPreviewSlimSystem):
  import std/assertions

proc inSet*(s: PNode, elem: PNode): bool =
  assert s.kind == nkCurly
  if s.kind != nkCurly:
    #internalError(s.info, "inSet")
    return false
  for i in 0..<s.len:
    if s[i].kind == nkRange:
      if leValue(s[i][0], elem) and
          leValue(elem, s[i][1]):
        return true
    else:
      if sameValue(s[i], elem):
        return true
  result = false

proc overlap*(a, b: PNode): bool =
  if a.kind == nkRange:
    if b.kind == nkRange:
      # X..Y and C..D overlap iff (X <= D and C <= Y)
      result = leValue(a[0], b[1]) and
               leValue(b[0], a[1])
    else:
      result = leValue(a[0], b) and leValue(b, a[1])
  else:
    if b.kind == nkRange:
      result = leValue(b[0], a) and leValue(a, b[1])
    else:
      result = sameValue(a, b)

proc someInSet*(s: PNode, a, b: PNode): bool =
  # checks if some element of a..b is in the set s
  assert s.kind == nkCurly
  if s.kind != nkCurly:
    #internalError(s.info, "SomeInSet")
    return false
  for i in 0..<s.len:
    if s[i].kind == nkRange:
      if leValue(s[i][0], b) and leValue(b, s[i][1]) or
          leValue(s[i][0], a) and leValue(a, s[i][1]):
        return true
    else:
      # a <= elem <= b
      if leValue(a, s[i]) and leValue(s[i], b):
        return true
  result = false

proc toBitSet*(graph: ModuleGraph; s: PNode): TBitSet =
  result = @[]
  var first: Int128 = Zero
  var j: Int128 = Zero
  first = firstOrd(graph.config, s.typ.elementType)
  bitSetInit(result, int(getSize(graph, s.typ)))
  for i in 0..<s.len:
    if s[i].kind == nkRange:
      j = getOrdValue(s[i][0], first)
      while j <= getOrdValue(s[i][1], first):
        bitSetIncl(result, toInt64(j - first))
        inc(j)
    else:
      bitSetIncl(result, toInt64(getOrdValue(s[i]) - first))

proc toTreeSet*(graph: ModuleGraph; s: TBitSet, settype: PType, info: TLineInfo): PNode =
  var
    a, b, e, first: BiggestInt # a, b are interval borders
    elemType: PType
    n: PNode
  elemType = settype[0]
  first = firstOrd(graph.config, elemType).toInt64
  result = newNodeI(nkCurly, info)
  result.typ = settype
  result.info = info
  e = 0
  while e < s.len * ElemSize:
    if bitSetIn(s, e):
      a = e
      b = e
      while true:
        inc(b)
        if (b >= s.len * ElemSize) or not bitSetIn(s, b): break
      dec(b)
      let aa = newIntTypeNode(a + first, elemType)
      aa.info = info
      if a == b:
        result.add aa
      else:
        n = newNodeI(nkRange, info)
        n.typ = elemType
        n.add aa
        let bb = newIntTypeNode(b + first, elemType)
        bb.info = info
        n.add bb
        result.add n
      e = b
    inc(e)

template nodeSetOp(a, b: PNode, op: untyped) {.dirty.} =
  var x = toBitSet(graph, a)
  let y = toBitSet(graph, b)
  op(x, y)
  result = toTreeSet(graph, x, a.typ, a.info)

proc unionSets*(graph: ModuleGraph; a, b: PNode): PNode = nodeSetOp(a, b, bitSetUnion)
proc diffSets*(graph: ModuleGraph; a, b: PNode): PNode = nodeSetOp(a, b, bitSetDiff)
proc intersectSets*(graph: ModuleGraph; a, b: PNode): PNode = nodeSetOp(a, b, bitSetIntersect)
proc symdiffSets*(graph: ModuleGraph; a, b: PNode): PNode = nodeSetOp(a, b, bitSetSymDiff)

proc containsSets*(graph: ModuleGraph; a, b: PNode): bool =
  let x = toBitSet(graph, a)
  let y = toBitSet(graph, b)
  result = bitSetContains(x, y)

proc equalSets*(graph: ModuleGraph; a, b: PNode): bool =
  let x = toBitSet(graph, a)
  let y = toBitSet(graph, b)
  result = bitSetEquals(x, y)

proc complement*(graph: ModuleGraph; a: PNode): PNode =
  var x = toBitSet(graph, a)
  for i in 0..high(x): x[i] = not x[i]
  result = toTreeSet(graph, x, a.typ, a.info)

proc deduplicate*(graph: ModuleGraph; a: PNode): PNode =
  let x = toBitSet(graph, a)
  result = toTreeSet(graph, x, a.typ, a.info)

proc cardSet*(graph: ModuleGraph; a: PNode): BiggestInt =
  let x = toBitSet(graph, a)
  result = bitSetCard(x)

proc setHasRange*(s: PNode): bool =
  assert s.kind == nkCurly
  if s.kind != nkCurly:
    return false
  for i in 0..<s.len:
    if s[i].kind == nkRange:
      return true
  result = false

proc emptyRange*(a, b: PNode): bool =
  result = not leValue(a, b)  # a > b iff not (a <= b)
