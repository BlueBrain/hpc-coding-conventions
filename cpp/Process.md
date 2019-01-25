# Development Process

## Daily work

Developers should ensure that their C++ contributions are well indented. To save both time and effort, they can:
1. Configure they favorite IDE so that it complies to these conventions.
1. Use git precommit hooks to prevent committing unformatted code.

## Continuous Integration

Continuous integration may control coding convention by:
* executing ClangFormat to ensure code is well formatted
* executing ClangTidy and/or Cppcheck linters

It can also perform additional checks that should also fail if a new error is spotted:
* execute Valgrind memory checker
* compute unit-tests code coverage and reject
the merge request if below a certain value.




