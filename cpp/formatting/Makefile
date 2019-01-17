CLANG_FORMAT ?= clang-format
PANDOC ?= pandoc

SNIPPETS = $(wildcard snippets/*.cpp)

all: formatting.html

formatting.md: formatting.md.jinja formatting.py $(SNIPPETS)
	./formatting.py $< $@

$(SNIPPETS): .clang-format
	$(CLANG_FORMAT) -i $<

.md.html: $<
	$(PANDOC) -s -S -c github-pandoc.css $< -o $@

.SUFFIXES: .md .html
