# $Id: ShowDesktop.pm,v 1.9 2004/06/28 19:54:06 jodrell Exp $
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
package PerlPanel::Applet::ShowDesktop;
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
	$self->{widget} = Gtk2::ToggleButton->new;
	$self->{config} = PerlPanel::get_config('ShowDesktop');

	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('ShowDesktop', PerlPanel::icon_size)));
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	$self->widget->set_relief('none');

	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->signal_connect('showing-desktop-changed', sub {
		$self->widget->set_active($self->{screen}->get_showing_desktop);
	});

	PerlPanel::tips->set_tip($self->{widget}, _('Show the Desktop'));
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

sub get_default_config {
	return undef;
}

sub clicked {
	my $self = shift;
	if ($self->widget->get_active) {
		PerlPanel::tips->set_tip($self->{widget}, _('Restore Windows'));
	} else {
		PerlPanel::tips->set_tip($self->{widget}, _('Show the Desktop'));
	}
	$self->{screen}->toggle_showing_desktop($self->widget->get_active);
	return 1;
}

1;
