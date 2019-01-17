# C++ Code Formatting Documentation Generation Utility

This directory provides both documentation chunks and scripts to build 
an HTML document describing C++ code formatting conventions adopted by the BlueBrain
HPC team.

## Requirements

* A Python environment with *pyyaml* and *jinja* packages installed.
A `Pipfile` is provided at repository top-level as a courtesy to setup
such environment with *pipenv*.
* ClangFormat 7
* Pandoc to generate HTML document (optional)

## How to build the documentation

* execute command `make` to generate `formatting.html`
* execute command `make formatting.md` to generate the documentation in Markdown

## How to edit the documentation?

Use GitHub pull-request. Make sure the HTML documentation (or at least the Markdown one)
builds properly.

Edit `formatting.md.jinja` template or C++ code snippets in [`snippets/`](./snippets) directory.
A C++ snippet has the following structure:

```cpp
// TITLE

// optional *markown* description
// Multiline description is supported

template <typename T>
your cpp(code);
```
A C++ snippet should be named after the clang-format configuration key it highlights, if any.
