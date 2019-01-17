# C++ Code Formatting Documentation Generation Utility

This directory provides both documentation chunks and scripts to build 
BBP HPC team guidelines regarding C++ code formatting.

## Requirements

* A Python environment with *pyyaml* and *jinja* packages installed.
A `Pipfile` is provided at repository top-level as a courtesy to setup
such environment with *pipenv*.
* ClangFormat 7
* Pandoc to generate HTML document

## How to build the documentation

* execute command `make` to generate an HTML document
* execute command `make formatting.md` to generate the documentation in Markdown

## How to edit the documentation?

Edit `formatting.md.jinja` template or C++ code snippets in `snippets/` directory.
A C++ snippet has the following structure:

```cpp
// TITLE

// optional *markown* description
// Multiline description is supported

template <typename T>
your cpp(code);
```
A C++ snippet should be named after the clang-format configuration key it highlights, if any.
