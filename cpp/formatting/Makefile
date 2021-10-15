# Targets:
#
#   README.md: rebuild the Markdown documentation (default target)
#
#   all: alias for README.md
#
#   clean: remove top generated files
#
#   distclean: clean + remove intermediate files
#

CLANG_FORMAT ?= clang-format
PANDOC ?= pandoc

SNIPPETS = $(wildcard snippets/*.cpp)
CLANG_FORMAT_MAJOR = $(shell $(CLANG_FORMAT) --version | sed -e "s/(.*)//" | awk '{print $$NF}' | awk -v FS=. '{print $$1}')
CLANG_FORMAT_CONFIG = $(shell for i in `seq $(CLANG_FORMAT_MAJOR) -1 7`; do if [ -f ../clang-format-$$i ] ; then echo ../clang-format-$$i ; break; fi; done)

all: README.md

clean:
	$(RM) README.md README.html

distclean: clean
	$(RM) .clang-format

# README.html
.md.html: $<
	$(PANDOC) -s -c github-pandoc.css $< -o $@
README.html: github-pandoc.css

# README.md
README.md: README.md.jinja formatting.py .clang-format $(SNIPPETS)
	@# format snippets that triggered rebuild of target
	$(foreach snippet,$(filter snippets/%,$?),$(CLANG_FORMAT) -style=file -i $(snippet);)

	./formatting.py $< $@

# update all snippets when .clang-format is changed
$(SNIPPETS): .clang-format
	$(CLANG_FORMAT) -style=file -i $@
	touch $@

.clang-format: $(CLANG_FORMAT_CONFIG)
	cp $? $@

.SUFFIXES: .md .html
