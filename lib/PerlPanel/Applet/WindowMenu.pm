# $Id: WindowMenu.pm,v 1.15 2005/11/14 14:38:53 mcummings Exp $
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
	$self->{icon} = Gtk2::Image->new;
	$self->{screen}->signal_connect('active-window-changed', sub { $self->update_icon });
	my $callback = sub {
		if (scalar($self->get_workspace_windows) < 1) {
			$self->{icon}->set_from_pixbuf(PerlPanel::get_applet_pbf('WindowMenu', PerlPanel::icon_size));
		}
	};
	$self->{screen}->signal_connect('active-workspace-changed', $callback);
	$self->{screen}->signal_connect('window-closed', $callback);
	$self->update_icon;
	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_border_width(0);
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
	PerlPanel::tips->set_tip($self->widget, _('Window List'));
	$self->widget->show_all;
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
	my @windows = $self->get_workspace_windows;
	if (scalar(@windows) < 1) {
		my $item = Gtk2::MenuItem->new_with_label(_('No Windows Open'));
		$item->set_sensitive(0);
		$self->menu->append($item);
	} else {
		foreach my $window (@windows) {
			my $label = $window->get_name;
			$label = (length($label) < 25 ? $label : substr($label, 0, 22).'...');
			my $icon = $window->get_icon;
			if ($icon->get_height > PerlPanel::menu_icon_size()) {
				$icon = $icon->scale_simple(($icon->get_width * (PerlPanel::menu_icon_size() / $icon->get_height)), PerlPanel::menu_icon_size(), 'bilinear');
			}
			$self->menu->append($self->menu_item(
				$label,
				($window->get_icon_is_fallback ? PerlPanel::get_applet_pbf('WindowMenu-default', PerlPanel::icon_size) : $icon),
				sub { $window->activate(time()) },
			));
		}
	}
	return 1;
}

sub get_default_config {
	return undef;
}

sub update_icon {
	my $self = shift;
	my $window = $self->{screen}->get_active_window;
	if (!defined($window)) {
		return undef;
	} else {
		my $pbf;
		if (lc($window->get_name) eq 'perlpanel') {
			if (scalar($self->get_workspace_windows) < 1) {
				$pbf = PerlPanel::get_applet_pbf('WindowMenu', PerlPanel::icon_size);
			} else {
				return undef;
			}
		} else {
			$pbf = ($window->get_icon_is_fallback ? PerlPanel::get_applet_pbf('WindowMenu-default', PerlPanel::icon_size) : $window->get_icon);
		}
		if ($pbf->get_height > PerlPanel::icon_size()) {
			$pbf = $pbf->scale_simple(($pbf->get_width * (PerlPanel::icon_size() / $pbf->get_height)), PerlPanel::icon_size(), 'bilinear');
		}
		$self->{icon}->set_from_pixbuf($pbf);
		return 1;
	}
}

sub get_workspace_windows {
	my $self = shift;
	my $workspace = $self->{screen}->get_active_workspace;
	my @windows;
	foreach my $window ($self->{screen}->get_windows) {
		if (!$window->is_skip_tasklist && $window->get_workspace->get_number == $workspace->get_number) {
			push(@windows, $window);
		}
	}
	return @windows;
}

1;
