# =============================================================================
#
# Copyright (c) 2008-2014  Monavacon Limited <http://www.monavacon.com/>
# Copyright (c) 2001-2008  OpenSS7 Corporation <http://www.openss7.com/>
# Copyright (c) 1997-2001  Brian F. G. Bidulock <bidulock@openss7.org>
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 675 Mass
# Ave, Cambridge, MA 02139, USA.
#
# =============================================================================

package PerlPanel::Applet::XDGMenu;
use base qw(PerlPanel::MenuBase);
use Encode qw(encode decode);
use Glib qw(TRUE FALSE);
use Gtk2;
use strict;
use warnings;

require XDG::Menu::Parser;

sub configure {
	my $self = shift;
	my $icon;

	my $wg = $self->{widget} = Gtk2::Button->new;
	my $cf = $self->{config} = PerlPanel::get_config('XDGMenu');
	$self->widget->set_relief($self->{config}{relief} eq 'true' ? 'half' : 'none');
	my $pb = $self->{pixbuf} = PerlPanel::get_applet_pbf('BBMenu', PerlPanel::icon_size);
	if ($cf->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($pb), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(
		"$PerlPanel::PREFIX/share/\L$PerlPanel::NAME\E/menu-arrow-\L".PerlPanel::position."\E");
		my $x = $pb->get_width - $arrow->get_width;
		my $y = PerlPanel::position eq 'bottom' ? 0 : $pb->get_height - $arrow->get_height;
		$fixed->put(Gtk2::Image->new_from_pixbuf($arrow), $x, $y);
		$icon = $self->{icon} = Gtk2::Alignment->new(0.5, 0.5, 0, 0);
		$icon->add($fixed);
	} else {
		$icon = $self->{icon} = Gtk2::Image->new_from_pixbuf($pb);
	}
	if ($cf->{label} eq '') {
		$self->widget->add($icon);
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($icon, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($cf->{label}), 1, 1, 0);
	}
	PerlPanel::tips->set_tip($widget, _('Menu'));
	$self->widget->show_all;

	$self->{HOME} = $ENV{HOME} if $ENV{HOME};
	$self->{HOME} = '~' unless $self->{HOME};

	$self->{XDG_CURRENT_DESKTOP} = $ENV{XDG_CURRENT_DESKTOP} if $ENV{XDG_CURRENT_DESKTOP};
	$self->{XDG_CURRENT_DESKTOP} = '' unless $self->{XDG_CURRENT_DESKTOP};
	$ENV{XDG_CURRENT_DESKTOP} = $self->{XDG_CURRENT_DESKTOP} if $self->{XDG_CURRENT_DESKTOP};

	$self->{XDG_CONFIG_HOME} = $ENV{XDG_CONFIG_HOME} if $ENV{XDG_CONFIG_HOME};
	$self->{XDG_CONFIG_HOME} = "$self->{HOME}/.config" unless $self->{XDG_CONFIG_HOME};
	$ENV{XDG_CONFIG_HOME} = $self->{XDG_CONFIG_HOME} if $self->{XDG_CONFIG_HOME};

	$self->{XDG_CONFIG_DIRS} = $ENV{XDG_CONFIG_DIRS} if $ENV{XDG_CONFIG_DIRS};
	$self->{XDG_CONFIG_DIRS} = "/etc/xdg" unless $self->{XDG_CONFIG_DIRS};
	$ENV{XDG_CONFIG_DIRS} = $self->{XDG_CONFIG_DIRS} if $self->{XDG_CONFIG_DIRS};

	$self->{XDG_CONFIG_DIRS} = [split(/:/,join(':',$self->{XDG_CONFIG_HOME},$self->{XDG_CONFIG_DIRS}))];

	$self->{XDG_DATA_HOME} = $ENV{XDG_DATA_HOME} if $ENV{XDG_DATA_HOME};
	$self->{XDG_DATA_HOME} = "$self->{HOME}/.local/share" unless $self->{XDG_DATA_HOME};
	$ENV{XDG_DATA_HOME} = $self->{XDG_DATA_HOME} if $self->{XDG_DATA_HOME};

	$self->{XDG_DATA_DIRS} = $ENV{XDG_DATA_DIRS} if $ENV{XDG_DATA_DIRS};
	$self->{XDG_DATA_DIRS} = "/usr/local/share:/usr/share" unless $self->{XDG_DATA_DIRS};
	$ENV{XDG_DATA_DIRS} = $self->{XDG_DATA_DIRS} if $self->{XDG_DATA_DIRS};

	$self->{XDG_DATA_DIRS} = [split(/:/,join(':',$self->{XDG_DATA_HOME},$self->{XDG_DATA_DIRS}))];

	$self->{XDG_MENU_PREFIX} = $ENV{XDG_MENU_PREFIX} if $ENV{XDG_MENU_PREFIX};
	$self->{XDG_MENU_PREFIX} = '' unless $self->{XDG_MENU_PREFIX};
	$ENV{XDG_MENU_PREFIX} = $self->{XDG_MENU_PREFIX} if $self->{XDG_MENU_PREFIX};

	$self->{XDG_MENU_NAME} = 'applications';
	$self->{XDG_MENU_DIRS} = [ map {"$_/menus"} @{$self->{XDG_CONFIG_DIRS}} ];
	$self->{XDG_ROOT_MENU} = '';
	foreach my $name (
			"$self->{XDG_MENU_PREFIX}$self->{XDG_MENU_NAME}.menu",
			"$self->{XDG_MENU_NAME}.menu") {
		foreach (@{$self->{XDG_MENU_DIRS}}) {
			if (-f "$_/$name") {
				$self->{XDG_ROOT_MENU} = "$_/$name";
				last;
			}
		}
		last if $self->{XDG_ROOT_MENU};
	}

	$self->{XDG_ICON_THEME} = $ENV{XDG_ICON_THEME} if $ENV{XDG_ICON_THEME};
	unless ($self->{XDG_ICON_THEME}) {
		if (-f "$HOME/.gtkrc-2.0") {
			my @lines = (`cat $ENV{HOME}/.gtkrc-2.0`);
			foreach (@lines) { chomp;
				if (m{gtk-icon-theme-name=["]?(.*[^"])["]?$}) {
					$self->{XDG_ICON_THEME} = "$1";
					last;
				}
			}
		} else {
			$self->{XDG_ICON_THEME} = 'hicolor';
		}
	}

	$self->{XDG_ICON_DIRS} = join(':',"$HOME/.icons",map{"$_/icons"}@{$self->{XDG_DATA_DIRS}},'/usr/share/pixmaps');
	$self->{XDG_ICON_DIRS} = [ split(/:/,$self->{XDG_ICON_DIRS}) ];

	return 0 unless $self->{XDG_ROOT_MENU} and -f $self->{XDG_ROOT_MENU};

	$self->create_menu;
	$self->widget->signal_connect('clicked', sub { $self->popup });
	$self->widget->show_all;
	return 1;
}

sub create_menu {
	my $self = shift;
	my $parser = $self->{parser} = new XDG::Menu::Parser;
	my $tree = $self->{tree} = $parser->parse_menu($self->{XDG_ROOT_MENU});
	my $tray = $self->{tray} = new XDG::Menu::Tray;
	my $menu = $self->{menu} = $tray->create($tree);
	if ($self->{config}->{show_control_items} eq 'true' && !PerlPanel::has_action_menu) {
		$self->add_control_items(
				menu_data => $self->get_menu_data,
				);
	}
	return 1;
}

# does nothting:
sub get_menu_data {
	return [];
}

sub get_default_config {
	return {
		show_control_items => 'true',
		label => _('Menu'),
		relief => 'false',
		apps_in_submenu => 'false',
		submenu_label => _('Applications'),
	};
}
