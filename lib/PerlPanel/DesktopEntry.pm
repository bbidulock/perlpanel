# $Id: DesktopEntry.pm,v 1.11 2005/01/03 14:14:18 jodrell Exp $
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
# Copyright: (C) 2004 Gavin Brown <gavin.brown@uk.com>
#

package PerlPanel::DesktopEntry;
use Carp;
use X11::FreeDesktop::DesktopEntry;
use base 'X11::FreeDesktop::DesktopEntry';
use Gnome2::VFS;
use strict;

sub new {
	my ($package, $uri) = @_;
	Gnome2::VFS->init;

	my $data = get_file_contents($uri);
	if ($data eq '') {
		carp("got no data for $uri");
		return undef;
	}

	my $self = X11::FreeDesktop::DesktopEntry->new_from_data($data);

	if (!defined($self)) {
		return undef;

	} else {
		bless($self, $package);
		return $self;

	}
}

sub get_file_contents {
	my $uri = shift;
	my ($result, $info) = Gnome2::VFS->get_file_info($uri, 'default');
	if ($result eq 'ok' && $info->{type} eq 'regular') {
		return Gnome2::VFS->read_entire_file($uri);
	} else {
		return undef;
	}
}

1;
