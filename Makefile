# Makefile for PerlPanel
# This file is part of PerlPanel.
# 
# PerlPanel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PerlPanel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PerlPanel; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id: Makefile,v 1.10 2003/08/12 16:03:14 jodrell Exp $

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
	mkdir -p $(LIBDIR) $(BINDIR) $(MANDIR) $(IMGDIR)
	install -m 0755 build/perlpanel $(BINDIR)/
	install -m 0755 src/perlpanel-item-edit $(BINDIR)/
	cp -Rvp lib/* $(LIBDIR)/
	install -m 0755 build/perlpanel.1 $(MANDIR)/
	install -m 0755 build/perlpanel-applet-howto.1 $(MANDIR)/
	install -m 0644 share/perlpanel.png $(IMGDIR)/
	install -m 0644 share/perlpanel-menu-icon.png $(IMGDIR)/
	install -m 0644 share/perlpanel-lock-screen.png $(IMGDIR)/

clean:
	rm -rf build

uninstall:
	rm -rf $(BINDIR)/perlpanel $(LIBDIR) $(MANDIR)/perlpanel.1 $(MANDIR)/perlpanel-applet-howto.1
