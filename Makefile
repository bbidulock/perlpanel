# Makefile for PerlPanel
# $Id: Makefile,v 1.7 2003/06/27 13:26:17 jodrell Exp $

PREFIX=/usr
LIBDIR=$(PREFIX)/lib/perlpanel
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man/man1
IMGDIR=$(PREFIX)/share/pixmaps

all: perlpanel

perlpanel:
	mkdir build
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel
	pod2man doc/perlpanel.pod > build/perlpanel.1
	pod2man doc/perlpanel-applet-howto.pod > build/perlpanel-applet-howto.1

install:
	mkdir -p $(LIBDIR) $(BINDIR) $(MANDIR)
	install -m 0755 build/perlpanel $(BINDIR)/
	install -m 0755 src/perlpanel-item-edit $(BINDIR)/
	cp -Rvp lib/* $(LIBDIR)/
	install -m 0755 build/perlpanel.1 $(MANDIR)/
	install -m 0755 build/perlpanel-applet-howto.1 $(MANDIR)/
	install -m 0644 share/perlpanel.png $(IMGDIR)/
	install -m 0644 share/perlpanel-menu-icon.png $(IMGDIR)/

clean:
	rm -rf build

uninstall:
	rm -rf $(BINDIR)/perlpanel $(LIBDIR) $(MANDIR)/perlpanel.1 $(MANDIR)/perlpanel-applet-howto.1 $(IMGDIR)/perlpanel.png $(IMGDIR)/perlpanel-menu-icon.png
