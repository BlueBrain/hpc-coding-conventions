# C++ Project Documentation

This document provides instructions and hints to document C++ projects.

## How to document code?

### C++ code

Public APIs should be documented with Doxygen.

### Python code

Python code is documented with docstrings formatted using the
[Google style](https://github.com/google/styleguide/blob/gh-pages/pyguide.md#38-comments-and-docstrings).

## Doxygen and Sphinx

Today, the standard documentation tool for C++ projects is Doxygen, Sphinx is more used
in the Python community and widely used within Blue Brain Project.

Breathe and Exhale are two Sphinx extensions that allow a seemsless integration
of Doxygen in the Sphinx documentation pipeline.

Furthermore, because most of C++ projects within HPC team provide Python bindings.

This is why Sphinx documentation is the one chosen by HPC team.

## Sphinx documentation pipeline

`sphinx-build` is the main command line utility to generate documentation. This process
gathers a collection of documents in reStructedText to then generate the documentation
in the desired format, in HTML for instance.

There are many Sphinx extensions to emit reStructuredText from other sources. Here is a
non-exhaustive list of recommended extensions:

### m2r

This extension provides a reStructuredText command named `mdinclude` to import a Mardown document.
For instance you can have a `readme.rst` file that looks like:

```rst
Introduction
============

.. mdinclude:: ../README.md
```

### breathe

Doxygen is known to generated LaTex or HTML, but it can also generate an XML document
containing the same level of information.
Breathe is a Sphinx extension to generate reStructuredText files from such XML file.

### exhale

Exhale is a Sphinx extension that does not really emits reStructuredText but allow
instead to configure and run Doxygen to generate the XML file used by Breathe.

### autodoc

Autodoc is a Sphinx extension that imports your Python modules, and emits
reStructuredText from the docstrings of the symbols.

### napoleon

Napoleon is a Sphinx extension that allows autodoc to parse docstrings formatted
with the NumPy and Google coding styles.

### doctest

When enabled, Sphinx will execute the code snippets embedded in the documentation
and fail if they produce unexpected output.

For instance, let us consider the following `hello` Python module, part of a package to document:

```python
__version__ = '1.0.0'

def hello_world(recipient="World"):
	"""Write greeting message to standard output

	Args:
	   recipient(str): person included in the message

       >>> hello_world()
	   Hello World!
	   >>> hello_world("Alice")
	   Hello Alice!
	"""
	print("Hello", recipient)
```

* If _autodoc_ extension is enabled and properly configured, then Sphinx will load
  this module, and extract the docstring from the `hello_world` function.
* If _napoleon_ extension is enabled, then Sphinx will be able to properly extract
  the description and the information of the function parameter, formatted using
  the Google style, to produce a nice HTML document with the code snippet embedded.
* If this _doctest_ extension is enabled, the document generation with run the
  code snippet, and will fail because the output is not the one expected.
  You realize that you are missing a trailing "!" in the written message.

This is a very interesting feature that ensure that the documentation remains
up to date, and continuously tested.

### coverage

This extension provides the symbols of the Python package that have not been
called by the code snippets. The report is written a text file named
`doctest/output.txt`.

## Getting Started

### Generate skeleton

At the project root directory:

```
mkdir docs
cd docs
sphinx-quickstart
git add *
git commit -m 'Create Sphinx documentation skeleton with sphinx-quickstart'
```

### Add Python package to the PYTHONPATH used by sphinx

For package `hello`:

```diff
diff --git a/docs/conf.py b/docs/conf.py
index 41dc1a7..4b51de3 100644
--- a/docs/conf.py
+++ b/docs/conf.py
@@ -12,9 +12,9 @@
 # add these directories to sys.path here. If the directory is relative to the
 # documentation root, use os.path.abspath to make it absolute, like shown here.
 #
-# import os
-# import sys
-# sys.path.insert(0, os.path.abspath('.'))
+import os
+import sys
+sys.path.insert(0, os.path.abspath('..'))
+import hello


 # -- Project information -----------------------------------------------------
@@ -24,9 +25,9 @@ copyright = '2019, BlueBrain HPC Team'
 author = 'BlueBrain HPC Team'

 # The short X.Y version
-version = ''
+version = hello.__version__
 # The full version, including alpha/beta/rc tags
-release = '0.0.1'
+release = hello.__version__


 # -- General configuration ---------------------------------------------------
```

### Generate skeleton or reStructuredText files for Python package

The `sphinx-apidoc` utility analyzes Python packages and generates one reStructuredText
file per Python module, containing _automodule_ directives.

For instance, `sphinx-apidoc -o docs hello` command generates file `docs/hello.rst` that
looks like:

```rst
Module contents
================

.. automodule:: hello
    :members:
    :undoc-members:
    :show-inheritance:
```

This is enough to generate documentation of the `hello` module.
To generate documentation of symbols imported by `hello` module, consider using
the `:imported-members:` option of the `automodule` command.


### Integrates documentation of C++ code

```diff
diff --git a/docs/conf.py b/docs/conf.py
index 4b51de3..f1109d9 100644
--- a/docs/conf.py
+++ b/docs/conf.py
@@ -39,6 +39,8 @@ release = '0.0.1'
 # extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
 # ones.
 extensions = [
+    'breathe',
+    'exhale',
     'sphinx.ext.autodoc',
     'sphinx.ext.doctest',
     'sphinx.ext.coverage',
@@ -47,6 +49,27 @@ extensions = [
     'sphinx.ext.githubpages',
 ]

+# Setup the breathe extension
+breathe_projects = {
+    "Basalt C++ Library": "./doxyoutput/xml"
+}
+breathe_default_project = "Basalt C++ Library"
+
+# Setup the exhale extension
+exhale_args = {
+    # These arguments are required
+    "containmentFolder":     "./cpp_api",
+    "rootFileName":          "library_root.rst",
+    "rootFileTitle":         "C++ API",
+    "doxygenStripFromPath":  "..",
+    # Suggested optional arguments
+    "createTreeView":        True,
+    # TIP: if using the sphinx-bootstrap-theme, you need
+    # "treeViewIsBootstrap": True,
+    "exhaleExecutesDoxygen": True,
+    "exhaleDoxygenStdin":    "INPUT = ../include"
+}
+
 # Add any paths that contain templates here, relative to this directory.
 templates_path = ['_templates']

diff --git a/docs/index.rst b/docs/index.rst
index d218dc5..8c1cdd0 100644
--- a/docs/index.rst
+++ b/docs/index.rst
@@ -11,6 +11,7 @@ Welcome to Basalt's documentation!
    :caption: Contents:

    modules.rst
+   cpp_api/library_root

```

## Toward a decent `setup.py`
