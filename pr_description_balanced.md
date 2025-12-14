Fix invalid `m_type` access in generated hooks for generic objects (ARC/ORC/HOOKS)

### Summary
Fixes a bug where the compiler generated invalid C code for lifecycle hooks (like `=sink`, `=assign`) when dealing with distinct types based on generics, specifically under ARC, ORC, HOOKS, and ATOMICARC memory managers.

### Explanation
The compiler has a function that generates code for copying or moving data (hooks). This function sometimes needs to copy a special internal field called `m_type` (Runtime Type Information) if the object supports certain advanced features like inheritance.

The bug happened because when dealing with generic types (like `MyGeneric[int]`), the compiler got confused. It looked at the "wrapper" type for the generic instead of the actual object inside. This made it incorrectly assume that every generic object has an `m_type` field, even plain ones that don't.

So, the compiler would write C code to copy this `m_type` field. But for plain objects, the `m_type` field doesn't actually exist in the generated C structure. This caused the C compiler (like GCC or Clang) to complain with an error like `no member named 'm_type'`.

The fix makes the compiler "unwrap" the generic type first, so it always looks at the true object definition. This way, it only tries to copy `m_type` when the object genuinely has it, leading to correct C code.

### Fixes
Fixes #[ISSUE_NUMBER]
