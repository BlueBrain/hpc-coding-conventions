subdirs = cpp

all clean distclean:
	$(foreach dir,$(subdirs),$(MAKE) -C $(dir) $(MAKEFLAGS) $@;)
