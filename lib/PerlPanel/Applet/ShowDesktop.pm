# $Id: ShowDesktop.pm,v 1.8 2004/02/24 17:07:18 jodrell Exp $
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
	if (-e $self->{config}->{icon}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($self->{config}->{icon});
		$self->{pixbuf} = $self->{pixbuf}->scale_simple(PerlPanel::icon_size, PerlPanel::icon_size, 'bilinear');
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-missing-image', PerlPanel::icon_size_name);
	}
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->signal_connect('clicked', sub { $self->clicked });
	$self->{widget}->set_relief('none');
	$self->{screen} = Gnome2::Wnck::Screen->get_default;
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

sub end {
	return 'start';
}

sub get_default_config {
	return {
		icon => PerlPanel::get_applet_pbf_filename('showdesktop'),
	};

}

sub clicked {
	my $self = shift;
	if ($self->widget->get_active) {
		PerlPanel::tips->set_tip($self->{widget}, _('Restore Windows'));
	} else {
		PerlPanel::tips->set_tip($self->{widget}, _('Show the Desktop'));
	}
	$self->{screen}->toggle_showing_desktop(($self->widget->get_active ? 1 : 0));
	return 1;
}

1;
