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
# $Id: Makefile,v 1.15 2004/01/06 16:13:13 jodrell Exp $

PREFIX=/usr/local
LIBDIR=$(PREFIX)/lib/perlpanel
BINDIR=$(PREFIX)/bin
DATADIR=$(PREFIX)/share
MANDIR=$(DATADIR)/man/
IMGDIR=$(DATADIR)/pixmaps

MAN_SECTION=man1

all: perlpanel

perlpanel:
	mkdir build
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel
	pod2man doc/perlpanel.pod > build/perlpanel.1
	pod2man doc/perlpanel-applet-howto.pod > build/perlpanel-applet-howto.1

install:
	mkdir -p $(LIBDIR) $(BINDIR) $(MANDIR)/$(MAN_SECTION) $(IMGDIR)
	install -m 0755 build/perlpanel $(BINDIR)/
	install -m 0755 src/perlpaneld $(BINDIR)/
	install -m 0755 src/perlpanel-item-edit $(BINDIR)/
	cp -Rvp lib/* $(LIBDIR)/
	install -m 0755 build/perlpanel.1 $(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-applet-howto.1 $(MANDIR)/$(MAN_SECTION)/
	install -m 0644 share/pixmaps/perlpanel.png $(IMGDIR)/
	install -m 0644 share/pixmaps/perlpanel-menu-icon.png $(IMGDIR)/
	install -m 0644 share/pixmaps/perlpanel-lock-screen.png $(IMGDIR)/
	install -m 0644 share/pixmaps/perlpanel-show-desktop.png $(IMGDIR)/

clean:
	rm -rf build

uninstall:
	rm -rf $(BINDIR)/perlpanel $(BINDIR)/perlpaneld $(BINDIR)/perlpanel-item-edit $(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel.1 $(MANDIR)/perlpanel-applet-howto.1
