# Makefile for PerlPanel
# $Id: Makefile,v 1.1 2003/06/05 11:32:25 jodrell Exp $

PREFIX=/usr
LIBDIR=$(PREFIX)/lib/perlpanel
APPLETDIR=$(LIBDIR)/applets
BINDIR=$(PREFIX)/bin

all: perlpanel

perlpanel:
	mkdir build
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel

install:
	mkdir -p $(LIBDIR) $(BINDIR)
	install -m 0755 build/perlpanel $(BINDIR)
	cp -Rvp lib/* $(LIBDIR)/
	ln -s $(LIBDIR)/PerlPanel/Applet $(APPLETDIR)

clean:
	rm -rf build

uninstall:
	rm -rf $(BINDIR)/perlpanel $(LIBDIR)
