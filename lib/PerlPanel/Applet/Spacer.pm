# $Id: Spacer.pm,v 1.5 2004/11/07 16:25:51 jodrell Exp $
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
package PerlPanel::Applet::Spacer;
use base 'PerlPanel::MenuBase';
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::EventBox->new;
	$self->widget->add(Gtk2::Label->new);
	$self->widget->signal_connect('button_release_event', sub {
		if ($_[1]->button == 3) {
			$self->popup;
		}
	});
	$self->create_menu;
	$self->widget->show_all;
	return 1;

}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;
	$self->add_control_items;
}

sub popup_position {
	my $self = shift;
	my ($mouse_pos_x, undef) = PerlPanel::get_mouse_pointer_position;
	if (PerlPanel::position eq 'top') {
		return ($mouse_pos_x, PerlPanel::panel->allocation->height);
	} else {
		$self->menu->realize;
		return ($mouse_pos_x, PerlPanel::screen_height() - $self->menu->allocation->height - PerlPanel::panel->allocation->height);
	}
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 1;
}

sub fill {
	return 1;
}

sub end {
	return 'start';
}

sub get_default_config {
	return undef;
}

1;
