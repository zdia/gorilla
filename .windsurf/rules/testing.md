---
description: Testing policy for Password Gorilla
---

Always add or update unit tests when making changes to the codebase.

- Tests live in `unit-tests/` with one subfolder per test category
- Each subfolder contains a `.test` file using the `tcltest 2.2` framework
- New test folders must be added to the `testFolderList` in `unit-tests/RunAllTests.tcl`
- Run tests with: `tclsh sources/gorilla.tcl --tcltest`
- All tests must pass before committing
