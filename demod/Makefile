# SPDX-License-Identifier: MIT
PKG_CONFIG ?= pkg-config
PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin

CFLAGS += -Wall -Wextra $(shell $(PKG_CONFIG) --cflags libsystemd)
LDLIBS += $(shell $(PKG_CONFIG) --libs libsystemd)

all: demod

demod: demod.c

install: demod
	install -D -m 0755 demod $(DESTDIR)$(BINDIR)/demod

clean:
	rm -f demod

.PHONY: all install clean
