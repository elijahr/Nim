Fix invalid `m_type` access in generated lifecycle hooks for generic objects (ARC/ORC/HOOKS/ATOMICARC)

### Summary
Fixes a bug where the compiler generated invalid C code for lifecycle hooks (like `=sink`, `=assign`) when dealing with distinct types based on generics, specifically under ARC, ORC, HOOKS, and ATOMICARC memory managers.

### Details
The issue occurred in `compiler/liftdestructors.nim` within `produceSym`. This function helps determine how to handle copying or moving types. It has logic to check if an object needs its hidden `m_type` field (Runtime Type Information) copied.

The problem was that the check (`isObjLackingTypeField`) was being performed on the generic instance type (e.g., `Ctx[N]`), not the concrete object definition. Because a generic instance is not strictly a `tyObject`, the check incorrectly indicated that the `m_type` field existed, causing the compiler to generate C code to copy it.

This led to C compilation errors in multi-module projects, because the actual C struct definition (for plain objects) does not include `m_type`.

This bug affects memory managers in the ARC family: ARC, ORC, HOOKS, and ATOMICARC.

**The Fix:**
The fix is to "unwrap" the generic instance type using `skipTypes` before passing it to the `isObjLackingTypeField` check. This ensures the compiler correctly identifies if the underlying object type truly has an `m_type` field, preventing the generation of invalid C code.

### Fixes
Fixes #[ISSUE_NUMBER]

### Test Plan
- Added a new regression test `tests/destructor/torc_sink_bug.nim` which compiles the reproduction case using `--mm:orc`.
- Verified that the test fails without this patch and passes with it.
- Verified bootstrapping with `./koch boot -d:release`.
