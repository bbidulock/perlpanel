# $Id: WindowMenu.pm,v 1.7 2004/02/23 17:29:12 jodrell Exp $
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
package PerlPanel::Applet::WindowMenu;
use base 'PerlPanel::MenuBase';
use Gnome2::Wnck;
use strict;

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('WindowMenu');
	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;
	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('windowmenu', PerlPanel::icon_size));
	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	if ($self->{config}->{label} ne '') {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	} else {
		$self->widget->add($self->{icon});
	}
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	PerlPanel::tips->set_tip($self->widget, 'Window List');
	return 1;
}

sub clicked {
	my $self = shift;
	$self->create_menu;
	$self->popup;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;
	my $workspace = $self->{screen}->get_active_workspace;
	my @windows;
	foreach my $window ($self->{screen}->get_windows) {
		if (!$window->is_skip_tasklist && $window->get_workspace->get_number == $workspace->get_number) {
			push(@windows, $window);
		}
	}
	if (scalar(@windows) < 1) {
		my $item = Gtk2::MenuItem->new_with_label('No Windows Open');
		$item->set_sensitive(0);
		$self->menu->append($item);
	} else {
		foreach my $window (@windows) {
			my $pbf = $window->get_icon;
			my $x0 = $pbf->get_width;
			my $y0 = $pbf->get_height;
			if ($x0 != PerlPanel::icon_size || $y0 != PerlPanel::icon_size) {
				my ($x1, $y1);
				if ($x0 > $y0) {
					# image is landscape:
					$x1 = PerlPanel::icon_size;
					$y1 = int(($y0 / $x0) * PerlPanel::icon_size);
				} elsif ($x0 == $y0) {
					# image is square:
					$x1 = PerlPanel::icon_size;
					$y1 = PerlPanel::icon_size;
				} else {
					# image is portrait:
					$x1 = int(($x0 / $y0) * PerlPanel::icon_size);
					$y1 = PerlPanel::icon_size;
				}
				$pbf = $pbf->scale_simple($x1, $y1, 'bilinear');
			}
			my $label = $window->get_name;
			$label = (length($label) < 25 ? $label : substr($label, 0, 22).'...');
			$self->menu->append($self->menu_item(
				$label,
				$pbf,
				sub { $window->activate },
			));
		}
	}
	return 1;
}

sub get_default_config {
	return undef;
}

1;
