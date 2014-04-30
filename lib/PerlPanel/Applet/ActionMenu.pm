# $Id: ActionMenu.pm,v 1.8 2004/09/17 11:28:53 jodrell Exp $
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
package PerlPanel::Applet::ActionMenu;
use base 'PerlPanel::MenuBase';
use strict;

sub configure {
	my $self = shift;

	$self->{widget}	= Gtk2::Button->new;
	$self->{menu}	= Gtk2::Menu->new;
	$self->{config} = PerlPanel::get_config('ActionMenu');

	$self->widget->set_relief($self->{config}->{relief} eq 'true' ? 'half' : 'none');

	$self->{pixbuf} = PerlPanel::get_applet_pbf('ActionMenu', PerlPanel::icon_size);

	$self->{icon} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}

	PerlPanel::tips->set_tip($self->{widget}, _('Action Menu'));

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });
	$self->widget->show_all;
	return 1;
}

sub create_menu {
	my $self = shift;
	$self->add_control_items;
	return 1;
}

sub get_default_config {
	return {
		label	=> _('Actions'),
		relief	=> 'true',
	};
}

1;
