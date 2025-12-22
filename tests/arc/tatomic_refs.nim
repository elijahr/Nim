discard """
  cmd: "nim c -r --mm:atomicArc --threads:on $file"
  output: '''
Basic tests passed
Refcount tests passed
Multi-threaded stress test starting
Multi-threaded stress test passed
Edge case tests passed
All tests passed!
'''
"""

type
  Node = object
    value: int
    next: ref Node

# Test 1: Basic functionality
proc testBasicFunctionality() =
  var shared: ref Node

  # Test loading nil
  let loaded = atomicLoadAndRef(addr shared)
  doAssert loaded == nil, "Expected nil when loading from nil location"

  # Test storing a value
  var node = new(Node)
  node.value = 42
  atomicStoreAndUnref(addr shared, node)

  # Test loading the stored value
  let loaded2 = atomicLoadAndRef(addr shared)
  doAssert loaded2 != nil, "Expected non-nil after storing"
  doAssert loaded2.value == 42, "Expected value 42"
  GC_unref(loaded2)

  # Test storing nil (cleanup)
  atomicStoreAndUnref(addr shared, nil)
  let loaded3 = atomicLoadAndRef(addr shared)
  doAssert loaded3 == nil, "Expected nil after storing nil"

  echo "Basic tests passed"

# Test 2: Refcount correctness
proc testRefcounts() =
  var shared: ref Node
  var node = new(Node)
  node.value = 100

  # Store the node - should increment refcount
  atomicStoreAndUnref(addr shared, node)

  # Load it multiple times - each should increment refcount
  let ref1 = atomicLoadAndRef(addr shared)
  doAssert ref1 != nil and ref1.value == 100

  let ref2 = atomicLoadAndRef(addr shared)
  doAssert ref2 != nil and ref2.value == 100

  # All refs should point to the same object
  doAssert cast[pointer](ref1) == cast[pointer](ref2)
  doAssert cast[pointer](ref1) == cast[pointer](node)

  # Cleanup - unref the loaded references
  GC_unref(ref1)
  GC_unref(ref2)

  # Store nil to cleanup
  atomicStoreAndUnref(addr shared, nil)

  echo "Refcount tests passed"

# Test 3: Multi-threaded stress test
var sharedHead: ref Node
const NumThreads = 4
const OpsPerThread = 100

proc readerThread(head: ptr (ref Node)) {.thread.} =
  for i in 0..<OpsPerThread:
    let node = atomicLoadAndRef(head)
    if node != nil:
      # Verify we can read the value safely
      let val = node.value
      doAssert val >= 0
      GC_unref(node)

proc writerThread(head: ptr (ref Node)) {.thread.} =
  # Create nodes and store them
  for i in 0..<OpsPerThread:
    var newNode = new(Node)
    newNode.value = i + 1  # Ensure value is > 0
    atomicStoreAndUnref(head, newNode)

proc testMultiThreaded() =
  echo "Multi-threaded stress test starting"

  # Initialize with a node
  sharedHead = new(Node)
  sharedHead.value = 0

  var threads: array[NumThreads, Thread[ptr (ref Node)]]

  # Spawn reader and writer threads
  for i in 0..<(NumThreads div 2):
    createThread(threads[i*2], readerThread, addr sharedHead)
    createThread(threads[i*2 + 1], writerThread, addr sharedHead)

  # Wait for all threads
  for i in 0..<NumThreads:
    joinThread(threads[i])

  # Cleanup - just store nil
  atomicStoreAndUnref(addr sharedHead, nil)

  echo "Multi-threaded stress test passed"

# Test 4: Edge cases
proc testEdgeCases() =
  var shared: ref Node

  # Rapid store/load cycles
  for i in 0..<100:
    var node = new(Node)
    node.value = i
    atomicStoreAndUnref(addr shared, node)

    let loaded = atomicLoadAndRef(addr shared)
    if loaded != nil:
      doAssert loaded.value == i
      GC_unref(loaded)

  # Multiple consecutive loads
  var node = new(Node)
  node.value = 999
  atomicStoreAndUnref(addr shared, node)

  var refs: seq[ref Node]
  for i in 0..<10:
    let loaded = atomicLoadAndRef(addr shared)
    if loaded != nil:
      refs.add(loaded)

  # All should point to the same object
  for r in refs:
    doAssert r.value == 999

  # Cleanup
  for r in refs:
    GC_unref(r)
  atomicStoreAndUnref(addr shared, nil)

  echo "Edge case tests passed"

# Main test runner
proc main() =
  testBasicFunctionality()
  testRefcounts()
  testMultiThreaded()
  testEdgeCases()
  echo "All tests passed!"

main()
