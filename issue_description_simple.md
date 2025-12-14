Compiler crash in hooks for distinct generic objects (ARC/ORC/HOOKS)

### Nim Version
Affects Nim versions 1.6.10+, 2.0.0+, and devel.

### Description
There is a bug in the Nim compiler when using memory managers like ARC, ORC, HOOKS, or ATOMICARC. If you have a generic object (like `Ctx[N]`) and create a "distinct" type from it (like `Ready[N]`) with custom hooks (like `=copy`), the compiler might crash during the C compilation step.

This happens specifically when:
1.  You use the types across multiple files (importing them).
2.  You try to move/sink the variable (like passing it to a function).

The error message usually says something like `error: no member named 'm_type'`, meaning the compiler wrote C code trying to access a field that doesn't exist.

### Reproduction
See `ts.nim` and `main.nim` example in the full issue description, but with clearer names like `BaseObject`, `DistinctObject`, `makeUnused`, and `consume`. Running `nim c --mm:orc main.nim` triggers the error.
