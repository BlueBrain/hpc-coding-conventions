# C++ Naming Conventions

This document provides a set of recommendations regarding how things should be named
in C++ projects.

Because there is no automatic way to ensure that a code change follows this guideline,
it is the responsibility of the code reviewers to enforce these rules over time.

Should a project decide to not apply some or all of the recommendations
below, it may provide written guidelines to the contributors with the rules
that should be followed instead, in a `CONTRIBUTING.md` document for instance.

## File Names

Follow [File Names](https://google.github.io/styleguide/cppguide.html#General_Naming_Rules)
convention of Google C++ Style Guide but use the following extension instead:

* C++ files: `.cpp`
* C++ header: `.hpp`
* C++ template implementations: `.ipp`

## Use descriptive variable names

```cpp
// no
int bufsz;

// yes
int buffer_size;
```

See [General Naming Rules](https://google.github.io/styleguide/cppguide.html#General_Naming_Rules)
in Google C++ Style Guide.

Generally use `snake_case` style as it is compliant with spell checkers.

### Exception

Function parameters and local variables used only within less than 3 lines can break this rule, for instance:

```cpp
struct Dimension {
    const int width;
    const int height;

    Dimension(int w, int h)
        : width(w)
	, height(h) {}
};
```

## Functions and variables start with a lower case

```cpp
void my_function() {
	int my_var;
};
```

## Types names use camel case

```cpp
class MyClass
using MyClassVector = std::vector<MyClass>
```

## Template parameter names use camel case: `InputIterator`

```cpp
template <class InputIterator, class Distance>
void advance(InputIterator& it, Distance n);
```

## Constants are all upper case with underscores

```cpp
const double AVOGADRO = 6.022140857e23;
const int LIGHT_SPEED = 299792458L;
```

## Namespace names are all lower-case

See [Namespace Names](https://google.github.io/styleguide/cppguide.html#Namespace_Names)
in Google C++ Style Guide.

### code comments

See [Comment Style](https://google.github.io/styleguide/cppguide.html#Comment_Style)
in Google C++ Style Guide.
