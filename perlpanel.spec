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
# $Id: perlpanel.spec,v 1.2 2004/01/06 12:44:35 jodrell Exp $

Summary: An X11 Panel program written in Perl.
Name: PerlPanel
Version: 0.2.0
Release: 1
Epoch: 0
Group: Applications/Accessories
License: GPL
URL: http://jodrell.net/projects/perlpanel/

Packager: Gavin Brown <gavin.brown@uk.com>
Vendor: http://jodrell.net/

Source: http://jodrell.net/download.html?file=/files/%{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/root-%{name}-%{version}
Prefix: %{_prefix}

AutoReq: no

#define __find_provides /usr/lib/rpm/find-provides.perl
#define __find_requires /usr/lib/rpm/find-requires.perl

BuildRequires: perl >= 5.8.0
Requires: perl >= 5.8.0, perl(Gtk2), perl(Gnome2::Wnck), perl(XML::Simple)

%description
PerlPanel is an attempt to build a useable, lean panel program (like Gnome's gnome-panel and KDE's Kicker) in Perl, using the Gtk2-Perl libraries.

%build
make %{_prefix}

%install
rm -rf %{buildroot}
%makeinstall PREFIX=%{buildroot}%{_prefix}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,0755)
%doc doc/README ChangeLog
%{_bindir}/*
%{_datadir}/pixmaps/*
%{_mandir}/*
%{_libdir}/perlpanel/
