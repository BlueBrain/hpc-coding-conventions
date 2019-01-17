CLANG_FORMAT ?= clang-format
PANDOC ?= pandoc

SNIPPETS = $(wildcard snippets/*.cpp)

all: code-formatting.html

code-formatting.md: code-formatting.md.jinja  code-formatting.py $(SNIPPETS)
	./code-formatting.py $< $@

$(SNIPPETS): .clang-format
	$(CLANG_FORMAT) -i $<

.md.html: $<
	$(PANDOC) $< -o $@

.SUFFIXES: .md .html
