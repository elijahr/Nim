Fix compiler crash in hooks with ARC/ORC/HOOKS and generic distinct types

### Summary
Fixes a bug where the compiler generated bad C code for hooks (like `=sink`) when using ARC/ORC/HOOKS/ATOMICARC with distinct types based on generics (e.g., `distinct MyGeneric[int]`).

### Explanation
The compiler has a function responsible for creating "sink" hooks (code that handles moving data efficiently). This function needs to decide whether to copy a hidden internal field called `m_type`.

The bug was that the compiler got confused by the generic wrapper. It looked at the wrapper (`MyGeneric[int]`) instead of the actual object inside it. Because of this confusion, it incorrectly assumed the object had an `m_type` field and wrote C code to copy it.

Since the actual C struct for the object didn't have that field, the C compiler (gcc/clang) would fail with an error.

This fix simply tells the compiler to "unwrap" the generic layer and look at the real object underneath before deciding whether to copy the field. This ensures it makes the correct decision and generates valid C code.

### Fixes
Fixes #[ISSUE_NUMBER]
