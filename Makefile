# Makefile for PerlPanel
# $Id: Makefile,v 1.2 2003/06/05 23:25:53 jodrell Exp $

PREFIX=/usr
LIBDIR=$(PREFIX)/lib/perlpanel
BINDIR=$(PREFIX)/bin

all: perlpanel

perlpanel:
	mkdir build
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel

install:
	mkdir -p $(LIBDIR) $(BINDIR)
	install -m 0755 build/perlpanel $(BINDIR)/
	cp -Rvp lib/* $(LIBDIR)/

clean:
	rm -rf build

uninstall:
	rm -rf $(BINDIR)/perlpanel $(LIBDIR)
