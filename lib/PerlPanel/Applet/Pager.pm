# $Id: Pager.pm,v 1.8 2004/02/24 17:07:18 jodrell Exp $
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
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel::Applet::Pager;
use Gnome2::Wnck;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{config} = PerlPanel::get_config('Pager');

	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;

	$self->{widget} = Gnome2::Wnck::Pager->new($self->{screen});
	$self->widget->set_shadow_type('in');
	$self->widget->set_n_rows($self->{config}->{rows});

	$self->widget->set_size_request(-1, PerlPanel::icon_size);

	PerlPanel::tips->set_tip($self->widget, _('Workspace Pager'));
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 0;
}

sub end {
	return 'end';
}

sub get_default_config {
	return {rows => 1};
}

1;
