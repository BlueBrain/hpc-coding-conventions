# BlueBrain HPC Team C++ Development Guidelines

This document describes both C++ Best Practices adopted by
HPC team, and the tools and processes required to
ensure they are properly followed over time.

## Documentation

Development Guidelines are split in the following sections:
* [Tooling](./Tooling.md)
* [Process](./Process.md)
* [Code Formatting](./formatting/README.md)
* Best Practices
* Python bindings

## Status

This project in currently under development, and shall not provide the features
its documentation pretends. Here is a raw summary of the status:

| Feature               | Definition         | Documentation      | Integration        | Adoption |
| --------------------- | ------------------ | ------------------ | ------------------ | -------- |
| ClangFormat           | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |          |
| ClangTidy             | :heavy_check_mark: |                    |                    |          |
| Naming Conventions    |                    |                    |                    |          |
| Writing Documentation |                    |                    |                    |          |
| Good Practices        |                    |                    |                    |          |
| Memory Check          |                    |                    |                    |          |
| UT Code Coverage      |                    |                    |                    |          |

## CMake Project

This repository provides a CMake project that allows you to use the tools and the processes described in this document.

### Requirements

This CMake project expects for the following utilities to be available:
* [ClangFormat 7](https://releases.llvm.org/7.0.0/tools/clang/docs/ClangFormat.html)
* [ClangTidy 7](https://releases.llvm.org/7.0.0/tools/clang/tools/extra/docs/clang-tidy/index.html)
* [cmake-format](https://github.com/cheshirekow/cmake_format) Python package
* [pre-commit](https://pre-commit.com/) Python package
Optionally, it will also looks for:
* [valgrind](http://valgrind.org/) memory checker
* code coverage utilities like gcov, lcov, or gcov

### Installation

You can import this CMake project into your Git repository using a git submodule:
```
git submodule add git@github.com:BlueBrain/hpc-coding-conventions.git
git submodule update --init --recursive
```

Then simply add the following line in the top `CMakeLists.txt`, after your project
declaration:
```
project(mylib CXX)
# [...]
add_subdirectory(hpc-coding-conventions/cpp)
```

After cloning of updating this git submodule, run CMake to take benefits of the latest changes.
This will setup or update git [pre-commit](https://pre-commit.com) hooks of this repository.

### Usage

#### Code Formatting

Enable CMake variable `BBP_USE_FORMATTING` to activate code formatting of both C++ and CMake files.
On an existing CMake build directory:

`cmake -DBBP_USE_FORMATTING:BOOL=ON .`

##### Usage

This will add the following *make* targets:

* `bbp-cpp-format`: to format C/C++ code
* `bbp-check-cpp-format`: task fails it at least one C/C++ file has improper format.

##### Advanced configuration

A list of CMake cache variables can be used to customize code formatting:

* `BBP_ClangFormat_OPTIONS`: additional options given to `clang-format` command.
  Default value is `""`.
* `BBP_ClangFormat_FILES_RE`: list of regular expressions matching C/C++ filenames
  to format. Default is:<br/>
  `"^.*\\\\.c$$" "^.*\\\\.h$$" "^.*\\\\.cpp$$" "^.*\\\\.hpp$$"`
* `BBP_ClangFormat_EXCLUDES_RE`: list of regular expressions to exclude C/C++ files from formatting
  Default value is:<br/>
  `".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"`
* `BBP_ClangFormat_DEPENDENCIES`: list of CMake targets to build before
  formatting C/C++ code. Default value is `""`

Where `BBP_USE_FORMATTING` CMake variable is supposed to be defined by the user,
these variables are meant to be overridden inside CMake project directly.

Those are CMake CACHE variables whose value must be forced.
For instance, to ignore code of third-parties located in `ext/` subdirectory,
add this to your CMake project:

```cmake
set(
  BBP_ClangFormat_EXCLUDES_RE "${PROJECT_SOURCE_DIR}/ext/.*$$"
  CACHE STRING "list of regular expressions to exclude C/C++ files from formatting"
  FORCE)
```

#### Pre-Commit

Enable CMake variable `BBP_USE_PRECOMMIT` to enable automatic checks before git commits

`cmake -DBBP_USE_PRECOMMIT:BOOL=ON .`

if `BBP_USE_FORMATTING` CMake variable is enabled, when performing a git commit,
a serie of checks will be automatically executed to ensure that your change
complies with the C++ guideline. It will be discarded otherwise.

##### Configuration

You can control both behavior and configuration
of this CMake project through CMake variables, among them:

* `BBP_USE_CLANG_FORMAT`: to enable helpers to keep your code properly formatted.
* `BBP_USE_CLANG_TIDY`: to enable static analysis at compile time.
  This feature requires CMake 3.8 or higher.
* `BBP_USE_CODE_COVERAGE`: to enable tests code coverage.
