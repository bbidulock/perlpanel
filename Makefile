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
#
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
# $Id: Makefile,v 1.42 2004/08/26 14:58:34 jodrell Exp $

VERSION=0.7.1

PREFIX=/usr/local
LIBDIR=$(PREFIX)/lib/perlpanel
BINDIR=$(PREFIX)/bin
DATADIR=$(PREFIX)/share
MANDIR=$(DATADIR)/man
LOCALEDIR=$(DATADIR)/locale
CONFDIR=$(PREFIX)/etc

LC_CATEGORY=LC_MESSAGES

MAN_SECTION=man1
MAN_LIBS_SECTION=man3

#
# NB: $(DESTDIR) is usally empty. rpmbuild needs it.
#

all: perlpanel

perlpanel:
	@mkdir -p build

	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel > build/perlpanel
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel-item-edit > build/perlpanel-item-edit
	perl -ne 's!\@PREFIX\@!$(PREFIX)!g ; s!\@LIBDIR\@!$(LIBDIR)!g ; print' < src/perlpanel-run-dialog > build/perlpanel-run-dialog
	perl -ne 's!\@VERSION\@!$(VERSION)!g ; print' < lib/PerlPanel.pm > build/PerlPanel.pm
	perl -I$(PWD)/build -MPerlPanel -MXML::Simple -e 'print XMLout(\%PerlPanel::DEFAULTS)' > build/perlpanelrc
	pod2man doc/perlpanel.pod		> build/perlpanel.1
	pod2man doc/perlpanel-applet-howto.pod	> build/perlpanel-applet-howto.1
	pod2man doc/perlpanel-run-dialog.pod	> build/perlpanel-run-dialog.1
	pod2man doc/perlpanel-item-edit.pod	> build/perlpanel-item-edit.1
	pod2man lib/PerlPanel/MenuBase.pm	> build/PerlPanel::MenuBase.1

	@# similarly for other locales as they become available:
	mkdir -p  build/locale/en/$(LC_CATEGORY)
	msgfmt -o build/locale/en/$(LC_CATEGORY)/perlpanel.mo src/po/en.po

install:
	mkdir -p	$(DESTDIR)/$(LIBDIR) \
			$(DESTDIR)/$(BINDIR) \
			$(DESTDIR)/$(MANDIR)/$(MAN_SECTION) \
			$(DESTDIR)/$(MANDIR)/$(MAN_LIBS_SECTION) \
			$(DESTDIR)/$(LOCALEDIR)/en/$(LC_CATEGORY) \
			$(DESTDIR)/$(CONFDIR)
	@echo Copying library files to $(DESTDIR)/$(LIBDIR):
	@cp -Rp lib/*	$(DESTDIR)/$(LIBDIR)/
	@echo Copying share files to $(DESTDIR)/$(DATADIR):
	@cp -Rp share/*	$(DESTDIR)/$(DATADIR)/
	install -m 0755 build/perlpanel			$(DESTDIR)/$(BINDIR)/
	install -m 0755 build/perlpanel-item-edit 	$(DESTDIR)/$(BINDIR)/
	install -m 0755 build/perlpanel-run-dialog	$(DESTDIR)/$(BINDIR)/
	install -m 0644 build/PerlPanel.pm		$(DESTDIR)/$(LIBDIR)/
	install -m 0755 build/perlpanel.1		$(DESTDIR)/$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-applet-howto.1	$(DESTDIR)/$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-item-edit.1	$(DESTDIR)/$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/perlpanel-run-dialog.1	$(DESTDIR)/$(MANDIR)/$(MAN_SECTION)/
	install -m 0755 build/PerlPanel::MenuBase.1	$(DESTDIR)/$(MANDIR)/$(MAN_LIBS_SECTION)/
	install -m 0644 build/locale/en/$(LC_CATEGORY)/perlpanel.mo $(LOCALEDIR)/en/$(LC_CATEGORY)/

	@echo Installing default rcfile:
	@if [ -e $(DESTDIR)/$(CONFDIR)/perlpanelrc ] ; then \
		echo Note: old $(DESTDIR)/$(CONFDIR)/perlpanelrc has not been overwritten, default has been installed to $(DESTDIR)/$(CONFDIR)/perlpanelrc.default.; \
		install -m 0644 build/perlpanelrc	$(DESTDIR)/$(CONFDIR)/perlpanelrc.default; \
	else \
		install -m 0644 build/perlpanelrc	$(DESTDIR)/$(CONFDIR)/; \
	fi


clean:
	rm -rf build

uninstall:
	rm -rf	$(BINDIR)/perlpanel \
		$(BINDIR)/perlpanel-item-edit \
		$(BINDIR)/perlpanel-run-dialog \
		$(MANDIR)/$(MAN_SECTION)/perlpanel.1 \
		$(MANDIR)/$(MAN_SECTION)/perlpanel-applet-howto.1 \
		$(MANDIR)/$(MAN_SECTION)/perlpanel-item-edit.1 \
		$(MANDIR)/$(MAN_SECTION)/perlpanel-run-dialog.1 \
		$(MANDIR)/$(MAN_LIBS_SECTION)/PerlPanel::MenuBase.1 \
		$(DATADIR)/perlpanel \
		$(DATADIR)/pixmaps/perlpanel* \
		$(LIBDIR) \
		$(LOCALEDIR)/*/$(LC_CATEGORY)/perlpanel.mo \

release:
	./make-rpm $(VERSION)
