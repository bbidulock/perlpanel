# $Id: ShowDesktop.pm,v 1.5 2004/01/26 00:50:58 jodrell Exp $
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
	if (-e $PerlPanel::OBJECT_REF->{config}{appletconf}{ShowDesktop}{icon}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{ShowDesktop}{icon});
		$self->{pixbuf} = $self->{pixbuf}->scale_simple($PerlPanel::OBJECT_REF->icon_size, $PerlPanel::OBJECT_REF->icon_size, 'bilinear');
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-missing-image', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->signal_connect('clicked', sub { $self->clicked });
	$self->{widget}->set_relief('none');
	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, "Show the Desktop");
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
		icon => $PerlPanel::OBJECT_REF->get_applet_pbf_filename('showdesktop'),
	};

}

sub clicked {
	my $self = shift;
	if ($self->widget->get_active) {
		$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, "Restore Programs");
	} else {
		$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, "Show the Desktop");
	}
	$self->{screen}->toggle_showing_desktop(($self->widget->get_active ? 1 : 0));
	return 1;
}

1;
