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
# $Id: Makefile,v 1.31 2004/02/17 14:23:04 jodrell Exp $

VERSION=0.4.0

PREFIX=/usr/local
LIBDIR=$(PREFIX)/lib/perlpanel
BINDIR=$(PREFIX)/bin
DATADIR=$(PREFIX)/share
MANDIR=$(DATADIR)/man

MAN_SECTION=man1
MAN_LIBS_SECTION=man3

#
# NB: $(DESTDIR) is usally empty.
#

all: perlpanel

perlpanel:
	mkdir build
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel-item-edit > build/perlpanel-item-edit
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel-run-dialog > build/perlpanel-run-dialog
	perl -ne 's!\@VERSION\@!$(VERSION)!g ; print' < lib/PerlPanel.pm > build/PerlPanel.pm
	pod2man doc/perlpanel.pod > build/perlpanel.1
	pod2man doc/perlpanel-applet-howto.pod > build/perlpanel-applet-howto.1
	pod2man doc/perlpanel-run-dialog.pod > build/perlpanel-run-dialog.1
	pod2man doc/perlpanel-item-edit.pod > build/perlpanel-item-edit.1
	pod2man lib/PerlPanel/MenuBase.pm > build/PerlPanel::MenuBase.1

install:
	mkdir -p $(DESTDIR)$(LIBDIR) $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/$(MAN_SECTION) $(DESTDIR)$(MANDIR)/$(MAN_LIBS_SECTION)
	install -m 0755 build/perlpanel $(DESTDIR)$(BINDIR)/
	install -m 0755 build/perlpanel-item-edit $(DESTDIR)$(BINDIR)/
	install -m 0755 build/perlpanel-run-dialog $(DESTDIR)$(BINDIR)/
	install -m 0755 src/perlpaneld $(DESTDIR)$(BINDIR)/
	cp -Rvp lib/* $(DESTDIR)$(LIBDIR)/
	install -m 0644 build/PerlPanel.pm $(DESTDIR)$(LIBDIR)/
	install -m 0755 build/perlpanel.1 $(DESTDIR)$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-applet-howto.1 $(DESTDIR)$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-item-edit.1 $(DESTDIR)$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-run-dialog.1 $(DESTDIR)$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/PerlPanel::MenuBase.1 $(DESTDIR)$(MANDIR)/$(MAN_LIBS_SECTION)/
	cp -Rvp share/* $(DESTDIR)$(DATADIR)/

clean:
	rm -rf build

uninstall:
	rm -rf	$(BINDIR)/perlpanel \
		$(BINDIR)/perlpaneld \
		$(BINDIR)/perlpanel-item-edit \
		$(BINDIR)/perlpanel-run-dialog \
		$(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel.1 \
		$(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel-applet-howto.1 \
		$(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel-run-dialog.1 \
		$(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel-item-edit.1 \
		$(LIBDIR) $(MANDIR)/$(MAN_SECTION)/perlpanel.1 \
		$(MANDIR)/perlpanel-applet-howto.1 \
		$(MANDIR)/$(MAN_LIBS_SECTION)/PerlPanel::MenuBase.1 \
		$(DATADIR)/perlpanel \
		$(DATADIR)/pixmaps/perlpanel*

release:
	./make-rpm $(VERSION)
