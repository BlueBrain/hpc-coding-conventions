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

| Feature            | Definition         | Documentation      | Integration | Adoption |
| ------------------ | ------------------ | ------------------ | ----------- | -------- |
| ClangFormat        | :heavy_check_mark: | :heavy_check_mark: | WIP         |          |
| ClangTidy          | WIP                |                    |             |          |
| Naming Conventions |                    |                    |             |          |
| Good Practices?    |                    |                    |             |          |
| Memory Check       |                    |                    |             |          |
| UT Code Coverage   |                    |                    |             |          |

## CMake Project

This repository provides a CMake project that allows you to use the tools and the processes described in this document.

### Requirements

This CMake project expects for the following utilities to be available:
* [ClangFormat 7](https://releases.llvm.org/7.0.0/tools/clang/docs/ClangFormat.html)
* [ClangTidy 7](https://releases.llvm.org/7.0.0/tools/clang/tools/extra/docs/clang-tidy/index.html)
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

And in the top `CMakeLists.txt`, simply add:
```
add_subdirectory(hpc-coding-conventions/cpp)
```

### Setup

After clone this git submodule, or when it
gets updated, you should always re-run CMake, and launch the following make target: `bbp-hpc-setup` to take benefits of the latest changes. For instance:

```sh
cd build
cmake ..
make bbp-hpc-setup
```

This will setup or update git precommit hooks of
this repository.

### Usage

#### Configuration

You can control both behavior and configuration
of this CMake project through CMake variables, among them:

* `BBP_USE_CLANG_FORMAT`: to enable helpers to keep your code properly formatted.
* `BBP_USE_CLANG_TIDY`: to enable static analysis at compile time.
  This feature requires CMake 3.8 or higher.
* `BBP_USE_CODE_COVERAGE`: to enable tests code coverage.

#### New features

Importing this CMake project provides a couple of additional make targets:
* bbp-format: to format your code
* bbp-static-analysis: to launch ClangTidy

#### Git pre-commit

Now, when performing a git commit, a serie of checks will be automatically
executed to ensure that your change complies with the C++ guideline.
It will be discarded otherwise.
