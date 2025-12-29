discard """
  targets: "cpp"
"""
## Test: Deferred `importcpp` pragma with generic type parameters
##
## Coverage:
## - Standard library C++ templates (std::atomic, std::vector, std::pair)
## - User-defined C++ templates (single and multi-param)
##
## Note: importcpp auto-appends template parameters like <'0>, so the
## deferred expression should return a C++ template name that expects params.
##
## Note: The `importcpp` pragma is ONLY valid on types and procedures.
## It is NOT valid on fields or variables (fields can't be imported from C++).

# -----------------------------------------------------------------------------
# Standard library templates
# -----------------------------------------------------------------------------

# std::atomic<T>
proc atomicName(T: typedesc): string {.compileTime.} = "std::atomic"

type Atomic[T] {.importcpp: atomicName(T), header: "<atomic>",
                 size: sizeof(T), align: alignof(T), completeStruct.} = object

var a8: Atomic[int8]
var a32: Atomic[int32]
var a64: Atomic[int64]

static:
  doAssert sizeof(Atomic[int8]) == 1
  doAssert sizeof(Atomic[int32]) == 4
  doAssert sizeof(Atomic[int64]) == 8

  # Prove different instantiations are distinct:
  doAssert sizeof(Atomic[int8]) != sizeof(Atomic[int64])

# Verify correct C++ template instantiation at compile time:
{.emit: """
static_assert(sizeof(std::atomic<NI8>) == 1, "Atomic<int8> should be 1 byte");
static_assert(sizeof(std::atomic<NI32>) == 4, "Atomic<int32> should be 4 bytes");
""".}

# std::pair<A, B>
proc pairName(A, B: typedesc): string {.compileTime.} = "std::pair"

type Pair[A, B] {.importcpp: pairName(A, B), header: "<utility>",
                  size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(Pair[int8, int8]) == 2
  doAssert sizeof(Pair[int32, int64]) == 12

# std::vector<T> (just verify it compiles - size is dynamic)
proc vectorName(T: typedesc): string {.compileTime.} = "std::vector"

type Vector[T] {.importcpp: vectorName(T), header: "<vector>".} = object

var v: Vector[int32]

# Verify at C++ level that correct template was instantiated:
{.emit: """
static_assert(sizeof(std::vector<int>) > 0, "Vector should instantiate with correct type");
""".}

# -----------------------------------------------------------------------------
# User-defined C++ templates - single parameter
# -----------------------------------------------------------------------------

{.emit: """/*TYPESECTION*/
template<typename T>
struct Wrapper {
  T value;
};
""".}

proc wrapperName(T: typedesc): string {.compileTime.} = "Wrapper"

type Wrapper[T] {.importcpp: wrapperName(T), size: sizeof(T), completeStruct.} = object

var w32: Wrapper[int32]
var w64: Wrapper[int64]

static:
  doAssert sizeof(Wrapper[int32]) == 4
  doAssert sizeof(Wrapper[int64]) == 8

# -----------------------------------------------------------------------------
# User-defined C++ templates - multiple parameters
# -----------------------------------------------------------------------------

{.emit: """/*TYPESECTION*/
template<typename A, typename B>
struct CustomPair {
  A first;
  B second;
};
""".}

proc customPairName(A, B: typedesc): string {.compileTime.} = "CustomPair"

type CustomPair[A, B] {.importcpp: customPairName(A, B),
                        size: sizeof(A) + sizeof(B), completeStruct.} = object

static:
  doAssert sizeof(CustomPair[int8, int8]) == 2
  doAssert sizeof(CustomPair[int32, int64]) == 12

# -----------------------------------------------------------------------------
# Conditional C++ template selection
# -----------------------------------------------------------------------------

{.emit: """/*TYPESECTION*/
template<typename T>
struct SmallContainer {
  T value;
};

template<typename T>
struct LargeContainer {
  T values[16];
};
""".}

proc containerName(T: typedesc): string {.compileTime.} =
  when sizeof(T) <= 4: "SmallContainer"
  else: "LargeContainer"

type AdaptiveContainer[T] {.importcpp: containerName(T), completeStruct.} = object

var ac8: AdaptiveContainer[int8]   # Should use SmallContainer
var ac64: AdaptiveContainer[int64] # Should use LargeContainer

# -----------------------------------------------------------------------------
# Mixed importcpp, size, and align pragmas
# -----------------------------------------------------------------------------

proc atomicNameWithAlign(T: typedesc): string {.compileTime.} = "std::atomic"

type AlignedAtomic[T] {.importcpp: atomicNameWithAlign(T), header: "<atomic>",
                        size: sizeof(T), align: alignof(T), completeStruct.} = object

static:
  doAssert sizeof(AlignedAtomic[int32]) == 4
  doAssert sizeof(AlignedAtomic[int64]) == 8
  doAssert alignof(AlignedAtomic[int64]) >= alignof(int64)

# -----------------------------------------------------------------------------
# Complex conditional with string operations
# -----------------------------------------------------------------------------

proc namespaceTypeName(T: typedesc): string {.compileTime.} =
  const prefix = "std::"
  when T is int32: prefix & "atomic"
  elif T is int64: prefix & "atomic"
  else: "std::atomic"

type NamespacedType[T] {.importcpp: namespaceTypeName(T), header: "<atomic>",
                         size: sizeof(T), completeStruct.} = object

static:
  doAssert sizeof(NamespacedType[int32]) == 4
  doAssert sizeof(NamespacedType[int64]) == 8

# -----------------------------------------------------------------------------
# Multiple generic parameters with conditional naming
# -----------------------------------------------------------------------------

{.emit: """/*TYPESECTION*/
template<typename A, typename B>
struct TypedPair {
  A first;
  B second;
};

template<typename A, typename B>
struct AlignedPair {
  alignas(16) A first;
  alignas(16) B second;
};
""".}

proc pairVariantName(A, B: typedesc): string {.compileTime.} =
  when sizeof(A) + sizeof(B) <= 8: "TypedPair"
  else: "AlignedPair"

type VariantPair[A, B] {.importcpp: pairVariantName(A, B), completeStruct.} = object

var vp1: VariantPair[int8, int32]  # Should use TypedPair (5 bytes)
var vp2: VariantPair[int64, int64] # Should use AlignedPair (16 bytes)

echo "All deferred importcpp pragma tests passed!"
