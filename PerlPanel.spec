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
# $Id: PerlPanel.spec,v 1.27 2004/09/27 10:39:19 jodrell Exp $

Summary: An X11 Panel program written in Perl.
Name: PerlPanel
Version: 0.8.0
Release: 1
Epoch: 0
Group: Applications/Accessories
License: GPL
URL: http://jodrell.net/projects/perlpanel/

Packager: Gavin Brown <gavin.brown@uk.com>
Vendor: http://jodrell.net/

#define __find_provides /usr/lib/rpm/find-provides.perl
#define __find_requires /usr/lib/rpm/find-requires.perl

Source: http://jodrell.net/download.html?file=/files/%{name}/%{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/root-%{name}-%{version}
Prefix: %{_prefix}

AutoReq: no

BuildRequires: perl >= 5.8.0, gettext
Requires: gettext, perl >= 5.8.0, gtk2 >= 2.4.0, libglade2, perl-Gtk2, perl-Gtk2-GladeXML, perl-Xmms-Perl, perl-XML-Simple, perl-XML-Parser, perl-Locale-gettext, perl-Gnome2-Wnck, perl-Gnome2-VFS, perl-Gtk2::TrayManager

%description
PerlPanel is an attempt to build a useable, lean panel program (like Gnome's
gnome-panel and KDE's Kicker) in Perl, using the Gtk2-Perl libraries.

%package themes
Summary: Themes for PerlPanel
Group: applications/Accessories
Requires: %{name}

%description themes
This package contains themes for PerlPanel.

%prep
%setup

%build
make PREFIX=%{_prefix} MANDIR=%{_mandir} VERSION=%{version}

%install
rm -rf %{buildroot}
%makeinstall PREFIX=%{buildroot}%{_prefix} MANDIR=%{buildroot}%{_mandir}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,0755)
%doc doc/README doc/README-IL8N ChangeLog
%{_bindir}/*
%{_datadir}/man/*
%{_datadir}/locale/*
%{_datadir}/icons/hicolor/*
%{_datadir}/perlpanel
%{_libdir}/perlpanel

%files themes
%{_datadir}/icons/Bluecurve/*
%{_datadir}/icons/crystalsvg/*
