# Tooling

## C++ Compiler

Recommended flags are:

* Clang: `-Werror -Weverything`. And then disable then one you dislike.
* GCC: `-Werror -Wall -Wextra -Wcast-align -Wconversion -Wdouble-promotion -Wformat=2 -Wnon-virtual-dtor -Wold-style-cast -Woverloaded-virtual -Wunused`
* GCC 6+: `-Wduplicated-conf -Wmisleading-indentation -Wnull-dereference`
* GCC 7+: `-Wlogical-op -Wrestrict -Wduplicated-branches`

Continuous integration should compilation your code with as many compilers as possible to get best feedback.

## Code formatting

C++ code can be formatted to meet the conventions with
[ClangFormat](https://releases.llvm.org/7.0.0/tools/clang/docs/ClangFormat.html) utility.
The ClangFormat configuration file to comply to these conventions can be found [here](./.clang-format).
Only ClangFormat 7 is supported, the LLVM stable version by the time
of the writing of this document.

## Static Analysis

You may use C++ linter tools to identify well known design mistakes like ClangTidy. A generic
configuration file can be found
[here](./.clang-tidy)
Only ClangTidy 7 is supported, the LLVM stable
version by the time of the writing of this document.

## GitHook

[pre-commit](https://pre-commit.com/) allows
you to identify simple issues before committing
changes.

## External C++ Libraries

* [cereal](https://github.com/USCiLab/cereal)
  A C++ header-only library for serialization
* [{fmt}](https://github.com/fmtlib/fmt) a Python like formatting library.
* [google-benchmark](https://github.com/google/benchmark) A microbenchmark support library
* [spdlog](https://github.com/gabime/spdlog)
  Fast C++ logging library
* [pybind11](https://github.com/pybind/pybind11)
  Lightweight header-only library to create Python bindings of existing C++ code.
* [nlohmann/json](https://github.com/nlohmann/json) JSON for Modern C++
* [gsl-lite](https://github.com/martinmoene/gsl-lite) A single-file header-only version
  of ISO C++ Guideline Support Library (GSL)
