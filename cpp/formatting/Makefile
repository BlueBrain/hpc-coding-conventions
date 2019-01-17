CLANG_FORMAT ?= clang-format
PANDOC ?= pandoc

SNIPPETS = $(wildcard snippets/*.cpp)

all: formatting.html

# formatting.html
.md.html: $<
	$(PANDOC) -s -S -c github-pandoc.css $< -o $@
formatting.html: github-pandoc.css

# formatting.md
formatting.md: formatting.md.jinja formatting.py $(SNIPPETS)
	$(foreach snippet,$(filter snippets/%,$?),$(CLANG_FORMAT) -i $(snippet);)
	./formatting.py $< $@

# update snippets when .clang-format is changed
$(SNIPPETS): .clang-format
	$(CLANG_FORMAT) -i $@
	touch $@

.SUFFIXES: .md .html
