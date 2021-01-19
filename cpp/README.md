# BlueBrain HPC Team C++ Development Guidelines

This document describes both C++ development guidelines adopted by
HPC team, and the tools and processes required to
ensure they are properly followed over time.

## Contributing

Tristan CAREL (tristan0x) is in charge of this repository activity and well-being but every change is welcome through pull-request.

Should you want to contribute to the naming conventions,
please refer to the dedicated [contributing document](./formatting/CONTRIBUTING.md) first.

## Documentation

Development Guidelines are split in the following sections:
* [Tooling](./Tooling.md)
* [Development Lifecycle](./DevelopmentLifecycle.md)
* [Code Formatting](./formatting/README.md)
* [Naming Conventions](./NamingConventions.md)
* [Code Documentation](./Documentation.md)
* Best Practices
* Python bindings

## Status

This project in currently under development, and shall not provide the features
its documentation pretends. Here is a raw summary of the status:

| Feature               | Definition         | Documentation      | Integration         | Adoption (>10 proj) |
| --------------------- | ------------------ | ------------------ | ------------------  | ------------------- |
| ClangFormat           | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark:  | WIP                 |
| ClangTidy             | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark:  | WIP                 |
| Naming Conventions    | :heavy_check_mark: | :heavy_check_mark: | :no_entry_sign: N/A | :no_entry_sign: N/A |
| Writing Documentation | :heavy_check_mark: | :heavy_check_mark: |                     |                     |
| Project template      | WIP                |                    |                     |                     |
| Good Practices        |                    |                    |                     |                     |
| Memory Check          |                    |                    |                     |                     |
| UT Code Coverage      |                    |                    |                     |                     |

## CMake Project

This directory provides a CMake project that allows one to use the tools and the processes
described in this document. This project requires CMake version 3.6 or higher.

### Requirements

This CMake project expects for the following utilities to be available:
* [Python 3.5 or higher](https://python.org)
* [ClangFormat 9](https://releases.llvm.org/9.0.0/tools/clang/docs/ClangFormat.html)
* [ClangTidy 7](https://releases.llvm.org/7.0.0/tools/clang/tools/extra/docs/clang-tidy/index.html)
* [cmake-format](https://github.com/cheshirekow/cmake_format) Python package
* [pre-commit](https://pre-commit.com/) Python package

Optionally, it will also look for:
* [valgrind](http://valgrind.org/) memory checker
* code coverage utilities like gcov, lcov, or gcov

### Installation

You can import this CMake project into your Git repository using a git submodule:
```
git submodule add https://github.com/BlueBrain/hpc-coding-conventions.git
git submodule update --init --recursive
```

Note: if your project already has a `cmake` sub-directory, it is recommended to create the
submodule in this directory instead of top-level.

Then simply add the following line in the top `CMakeLists.txt`, after your project
declaration:
```
project(mylib CXX)
# [...]
add_subdirectory(hpc-coding-conventions/cpp)
```

After cloning or updating this git submodule, run CMake to take benefits of the latest changes.
This will setup or update git [pre-commit](https://pre-commit.com) hooks of this repository.

CMake variables defined by this project are prefixed by `${PROJECT_NAME}` by default.
The CMake variable `CODING_CONV_PREFIX` allows to specify another prefix. It must be defined
before including this CMake project, for instance:
```cmake
project(mylib CXX)
# [...]
set(CODING_CONV_PREFIX Foo)
add_subdirectory(hpc-coding-conventions/cpp)
```

### Usage

#### Code Formatting

To activate code formatting of both C/C++ and CMake files,
enable CMake variable `${PROJECT}_FORMATTING` where `${PROJECT}` is the name given
to the CMake `project` function.

For instance, given a project `foo`:

`cmake -Dfoo_FORMATTING:BOOL=ON <path>`

To individually enable the formatting of C/C++ code or CMake files, use the following
CMake variables:

* `${PROJECT}_CLANG_FORMAT:BOOL`
* `${PROJECT}_CMAKE_FORMAT:BOOL`

Although it is possible to overwrite the default settings to restrict the scanned
directories, the formatting applies to the entire repository except git submodules
by default.

To enable the formatting of CMake and C++ code inside git submodules, enable the
`${PROJECT_NAME}_FORMATTING_NO_SUBMODULES:BOOL` CMake variable.

Use `${PROJECT}_FORMATTING_ON:STRING` CMake variable to apply formatting on a subset.
Possible values are:
* `all`: apply formatting on the entire repository (the default).
* `working`: apply formatting only on the git working area.
* `staging`: apply formatting only on the git staging area.
* `since-ref:GIT_REF`: apply formatting only on added and modified files in the commits
since the given ref. For instance `since-ref:origin/master` is equivalent to:
   ```
   fork_point=`git merge-base --fork-point origin/master HEAD`
   git diff --name-status $fork_point | grep '^[AM]'
   ```
* `base-branch`: an alias for `since-ref:$CHANGE_TARGET`. `CHANGE_TARGET` is a Jenkins
environment variable that contains the target or base branch to which the change
could be merged.
* `since-rev:GIT_REV`. For instance `since-ref:fcfc8b6a`

By default, a C++ file is entirely formatted.  To only reformat the lines touches
by the set of changed defined by `${PROJECT}_FORMATTING_ON:STRING` CMake variable,
enable the CMake variable `${PROJECT}_FORMATTING_CPP_CHANGES_ONLY:BOOL`.
This option is ineffective when `${PROJECT}_FORMATTING_ON:STRING` equals `all`.

##### Usage

This will add the following *make* targets:

* `clang-format`: to format C/C++ code.
* `check-clang-format`: the target fails if at least one C/C++ file has improper format.
* `cmake-format`: to format CMake files.
* `check-cmake-format`: the target fails it at least one CMake file has improper format.

##### Advanced configuration

A list of CMake cache variables can be used to customize the code formatting:

* `${PROJECT}_ClangFormat_OPTIONS`: additional options given to `clang-format` command.
  Default value is `""`.
* `${PROJECT}_ClangFormat_FILES_RE`: list of regular expressions matching C/C++ filenames
  to format. Despite the recommended extensions of this guidelines are `.cpp`, `.h`, and `.ipp`
  (see [Naming Conventions](./NamingConventions.md)), files with the following extensions
  will be formatted by default:
  * C++ implementation files: `.cpp`, `.cc`, `.cxx`, `.c`
  * C++ header files: `.h`, `.hh`, `.hpp`, `.hxx`
  * C++ files with template methods definitions: `.tpp`, `.txx`, `.tcc`, `.ipp`, `.ixx`, `.icc`

* `${PROJECT}_ClangFormat_EXCLUDES_RE`: list of regular expressions to exclude C/C++ files
  from formatting. Default value is:<br/>
  `".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"`

  Regular expressions are tested against the **full file path**.
* `${PROJECT}_ClangFormat_DEPENDENCIES`: list of CMake targets to build before
  formatting C/C++ code. Default value is `""`

Unlike `${PROJECT}_FORMATTING` which is supposed to be defined by the user,
These variables are already defined and may be overridden inside your CMake project,
**before including this CMake project**.
They are CMake _CACHE_ variables whose value must be forced.

For instance, to ignore code of third-parties located in `ext/` subdirectory
(`third[-_]part(y|ies)` regular expression by default), add this to your CMake project:

```diff
+set(
+  foo_ClangFormat_EXCLUDES_RE "${PROJECT_SOURCE_DIR}/ext/.*$$"
+  CACHE STRING "list of regular expressions to exclude C/C++ files from formatting"
+  FORCE)
 add_subdirectory(hpc-coding-conventions/cpp)
```

Default C++ file extensions are .cpp and .h. To also take .cxx and .tcc into account
during code formatting:
```diff
+set(foo_ClangFormat_FILES_RE
+    "^.*\\\\.[ch]$$" "^.*\\\\.[chi]pp$$" "^.*\\\\.tcc$$" "^.*\\\\.cxx$$"
+    CACHE STRING "List of regular expressions matching C/C++ filenames" FORCE)
 add_subdirectory(deps/hpc-coding-conventions/cpp)
```

##### Custom ClangFormat configuration

These coding conventions come with a predefined configuration of ClangFormat that
is by default copied in the top directory of the project.

It is recommended to not add this `.clang-format` to git so that it is fully
driven by this project. It will get updated along with the evolution of these
guidelines. Thus it is recommended to inform git to ignore this file by adding
it to the top `.gitignore`.

A project can however override the predefined configuration of ClangFormat
in two ways:
1. Create a `.clang-format.changes` containing only the required modifications.
1. Add `.clang-format` to the git repository. This project will never try
to modify it.

##### Custom CMakeFormat configuration

Like ClangFormat, these coding conventions already provide a CMakeFormat
configuration that the user can customize with a file named
`.cmake-format.changes.yaml` placed at the project's root directory.
This file can be used to specify the signature of owned CMake functions
and macros, for instance:

```yaml
additional_commands:
  add_mpi_test:
    kwargs:
      NAME: 1
      NUM_PROCS: 1
      COMMAND: '*'
```

will allow CMakeFormat to properly format functions calls like below:

```cmake
add_mpi_test(
  NAME OpSplitOmega_h_2D
  NUM_PROCS 2
  COMMAND $<TARGET_FILE:OpSplitOmega_h> --num-iterations 100 square.msh)
```

##### Continuous Integration

Define `${PROJECT}_TEST_FORMATTING:BOOL` CMake variable to enforce formatting during
the `test` make target.

#### Static Analysis

To activate static analysis of C++ files with clang-tidy, enable
the CMake variable `${PROJECT}_STATIC_ANALYSIS` where `${PROJECT}` is the name
given to the CMake `project` function.

For instance, given a project `foo`:

`cmake -DFoo_STATIC_ANALYSIS:BOOL=ON <path>`

##### Usage

This will provide a `clang-tidy` *make* target that will perform static analysis
of all C++ files. Target fails as soon as one defect is detected among the files.

It will also activate static analysis report during the compilation phase.

##### Advanced configuration

The following CMake cache variables can be used to customize the static analysis
of the code:

* `${PROJECT}_ClangTidy_OPTIONS`: additional options given to `clang-tidy` command.
  Default value is `""`.
* `${PROJECT}_ClangTidy_FILES_RE`: list of regular expressions matching C/C++ filenames
  to check. Default is:<br/>
  `"^.*\\\\.cc$$" "^.*\\\\.cpp$$" "^.*\\\\.cxx$$"`
* `${PROJECT}_ClangTidy_EXCLUDES_RE`: list of regular expressions to exclude C/C++ files
  from static analysis. Default value is:<br/>
  `".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"`
* `${PROJECT}_ClangTidy_DEPENDENCIES`: list of CMake targets to build before
  check C/C++ code. Default value is `""`

These variables are meant to be overridden inside your CMake project.
They are CMake _CACHE_ variables whose value must be forced
**before including this CMake project**.

##### Custom ClangTidy configuration

These coding conventions come with a `.clang-tidy` file providing a predefined
list of ClangTidy checks. By default, this file is copied in the top directory
of the project.

It is recommended to not add this `.clang-tidy` to git so that it is fully
driven by this project. It will get updated along with the evolution of these
guidelines. Thus it is recommended to inform git to ignore this file by adding
it to the top `.gitignore`.

A project can however override the predefined configuration of ClangFormat
in two ways:
1. Create a `.clang-tidy.changes` containing only the required modifications.
1. Add `.clang-tidy` to the git repository. This project will never try
to modify it.

##### Continuous Integration

Define `${PROJECT}_TEST_STATIC_ANALYSIS:BOOL` CMake variable to enforce formatting during
the `test` make target.

#### Pre-Commit

Enable CMake variable `${PROJECT}_PRECOMMIT` to enable automatic checks
before git commits.

For instance, given a project `foo`:

`cmake -Dfoo_PRECOMMIT:BOOL=ON <path>`

if `${PROJECT}_FORMATTING` CMake variable is enabled, when performing a git
commit, a succession of checks will be executed to ensure that your change
complies with the coding conventions. It will be discarded otherwise.

#### Bob

`bob.cmake` is a CMake utility file part of hpc-coding-conventions that provides
a set of convenient macros and functions used to:
* specify your project options and dependencies
* specify the proper compilation flags
* install the proper CMake export flags so that your project can be
  loaded by another project with the `find_package` CMake function.

##### Compilation flags

By default, CMake relies on the `CMAKE_BUILD_TYPE` variable to set the proper
compilation flags. Because _bob_ is now taking care of it, you must configure
your project with `CMAKE_BUILD_TYPE` empty.

_bob_ sets the compilation flags according to a set of CMake variables:
* `${PROJECT_NAME}_CXX_OPTIMIZE:BOOL`: Compile C++ with optimization (default is ON)
* `${PROJECT_NAME}_CXX_SYMBOLS:BOOL`: Compile C++ with debug symbols (default is ON)
* `${PROJECT_NAME}_CXX_WARNINGS:BOOL`: Compile C++ with warnings" (default is ON)
* `${PROJECT_NAME}_EXTRA_CXX_FLAGS:STRING`: Additional C++ compilation flags
* `${PROJECT_NAME}_CXX_FLAGS:STRING`: bypass variables above and use the specified
  compilation flags. `CMAKE_BUILD_TYPE` is ignored.
* `${PROJECT_NAME}_NORMAL_CXX_FLAGS:BOOL`: Allow `CMAKE_CXX_FLAGS` to follow _normal_ CMake behavior
  and bypass all variables above.

Default `CMAKE_CXX_FLAGS` variable value is taken into account.

##### Integration

The top-level CMakelists.txt of your project may look like:

```cmake
cmake_minimum_required(VERSION 3.6)
project(HelloWorld VERSION 1.0.0 LANGUAGES CXX)
add_subdirectory(hpc-coding-conventions/cpp)

bob_begin_package()
bob_begin_cxx_flags()
bob_cxx17_flags()
# specify custom compilation flags
find_package(OpenMP)
if(OpenMP_FOUND)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
  set(CMAKE_FLAGS "${CMAKE_FLAGS} ${OpenMP_FLAGS}")
else()
  message(WARNING "OpenMP support is disabled because it could not be found.")
endif()
bob_end_cxx_flags()

# specify your targets:
add_library(...)
add_executable(...)

bob_end_package()
```

#### Embedded third parties

External libraries required to build or test your C++ project can be either
directly added to the git repository or as a git submodule. The standard
root location for this kind of files is the `3rdparty/` directory but can be
overriden with the `${PROJECT_NAME}_3RDPARTY_DIR` CMake variable.

Adding single-file/header-only C++ libraries directly to the git repository
of your project is acceptable in general, like catch2 or the JSON library
of Niels Lohmann for instance.

More significant dependencies should be considered as pure external
dependencies. But it can also be very convenient to have them as git
submodules, and be able to switch between the two.

This project provides helper functions to deal with these dependencies:

###### cpp_cc_git_submodule

````cmake
#
# cpp_cc_git_submodule(source_dir
#                      [DISABLED]
#                      SUBDIR path
#                      [BUILD] [<arguments>]
#                      [PACKAGE] [<arguments>]
#                      GIT_ARGS [<arguments>])
#
# Add a CMake option in the cache to control whether the
# submodule is used or not (default ON). The option is named after the source
# directory passed in first argument, for instance:
#   cpp_cc_git_submodule(src/eigen)
# adds the following CMake cached option:
#  ${PROJECT_NAME}_3RDPARTY_USE_SRC_EIGEN:BOOL=ON
#
# If enabled, then the submodule is fetched if missing in the working copy.
#
# If the DISABLED argument is provided, then the default value for the CMake
# option is OFF.
#
# If the BUILD argument is provided then the directory is added to the build
# through the add_subdirectory CMake function. Arguments following the BUILD
# arguments are passed to the add_subdirectory function call.
#
# The optional SUBDIR argument is used by the BUILD argument to determine
# the path to the directory added to the build. The path specified is relative
# to the path to the git submodule.
#
# If the PACKAGE argument is provided and the CMake option to determine whether
# the git submodule should be used or not is FALSE, then a call to the find_package
# function is made with the arguments specified to the PACKAGE option.
#
# Default options passed to the `git submodule update` command are `--init --recursive`.
# If the GIT_ARGS argument is provided, then its value supersedes the default options.
#
````
