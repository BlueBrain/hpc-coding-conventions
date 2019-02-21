# BlueBrain HPC Team C++ Naming Conventions

This document describes how C++ symbols should be named.

## Common Conventions

### Use descriptive names

```cpp
// no
int bufsz;

// yes
int buffer_size;
```

Generally use `snake_case` style as it is compliant with spell checkers.

#### Exception

Function parametres and local variables used only within less than 3 lines can break this rule, for instance:

```cpp
struct Dimension {
    const int width;
    const int height;

    Dimension(int w, int h)
        : width(w)
	, height(h) {}
};
```

### Functions and variables start with a lower case

```cpp
void my_function() {
	int my_var;
};
```

### Types names use camel case

```cpp
class MyClass
using MyClassVector = std::vector<MyClass>
```

### Template parameter names use camel case: `InputIterator`

```cpp
template <class InputIterator, class Distance>
void advance(InputIterator& it, Distance n);
```

### Constants are all upper case with underscores

```cpp
const double AVOGADRO = 6.022140857e23;
const int LONG_MAX = 9223372036854775807L;
```

## Distinguish symbols

Distinguish private member variables, function parameters, and local variables.
There are several alternatives we can consider:

### Add a prefix to both private members and function parameters

* unexposed member variables are prefixed with `m_`
* function parameters are prefixed with `t_`
* do not use prefix for local variables and exposed member variables

#### Examples

```cpp
struct Size {
    int width;
    int height;

    Size(int t_width, int t_height)
        : width(t_width)
        , height(t_height) {}
};

class PrivateSize {
  public:
    int width() const {
        return m_width;
    }
    int height() const {
        return m_height;
    }
    PrivateSize(int t_width, int t_height)
        : m_width(t_width)
        , m_height(t_height) {}

  private:
    int m_width;
    int m_height;
};
```

```cpp
class MyClass {
  public:
    MyClass(int t_data)
        : m_data(t_data) {}

    int data() const {
        return m_data;
    }

  private:
    int m_data;
};
```

### Add prefix to private members and a suffix to function parameters

* unexposed member variables are prefixed with `m_`
* function parameters are suffixed with `_`
* do not use prefix for local variables and exposed member variables

#### Examples

```cpp
struct Size {
    int width;
    int height;

    Size(int width_, int height_)
        : width(width_)
        , height(height_) {}
};

class PrivateSize {
  public:
    int width() const {
        return m_width;
    }
    int height() const {
        return m_height;
    }
    PrivateSize(int width_, int height_)
        : m_width(width_)
        , m_height(height_) {}

  private:
    int m_width;
    int m_height;
};
```

```cpp
class MyClass {
  public:
    MyClass(int data_)
        : m_data(data_) {}

    int data() const {
        return m_data;
    }

  private:
    int m_data;
};
```


## Comments

Comment blocks should use `//`, not `/* */`. Using `//` makes it much easier to comment
out a block of code while debugging.

```cpp
// this function does something
int myFunc() {
}
```

To comment out this function during debugging, it is easy to do:
```cpp
/*
// this function does something
int myFunc() {
}
*/
```
This would be impossible is function header was commented with `/* */`.
