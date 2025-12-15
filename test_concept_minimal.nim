## Minimal test to understand concept parsing

# Test 1: Old-style concept (has parameter) - allows arbitrary expressions
type
  OldStyleConcept = concept type T
    echo "hello"

# Test 2: New-style concept with expression - should this error?
type
  NewStyleWithExpr = concept
    echo "hello"  # Should error: "unexpected construct in the new-styled concept"

echo "OldStyleConcept defined"
echo "int is OldStyleConcept: ", int is OldStyleConcept

echo "NewStyleWithExpr defined"
