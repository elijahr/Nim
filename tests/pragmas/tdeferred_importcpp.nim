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

echo "All deferred importcpp pragma tests passed!"
