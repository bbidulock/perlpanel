# $Id: GnomeMenu.pm,v 1.9 2004/06/25 14:36:43 jodrell Exp $
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
package PerlPanel::Applet::GnomeMenu;
use base 'PerlPanel::MenuBase';
use Gnome2::VFS;
use vars qw ($DESKTOP_NAMESPACE);
use strict;

our $DESKTOP_NAMESPACE = 'Desktop Entry';

sub configure {
	my $self = shift;

	Gnome2::VFS->init;

	$self->{widget} = Gtk2::Button->new;

	$self->{config} = PerlPanel::get_config('GnomeMenu');

	$self->{pixbuf} = PerlPanel::get_applet_pbf('gnomemenu', PerlPanel::icon_size);

	if ($self->{config}->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($self->{pixbuf}), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/pixmaps/%s/menu-arrow-%s.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME), lc(PerlPanel::position)));
		my $x = ($self->{pixbuf}->get_width - $arrow->get_width);
		my $y = (PerlPanel::position eq 'bottom' ? 0 : ($self->{pixbuf}->get_height - $arrow->get_height));
		$fixed->put(Gtk2::Image->new_from_pixbuf($arrow), $x, $y);
		$self->{icon} = Gtk2::Alignment->new(0.5, 0.5, 0, 0);
		$self->{icon}->add($fixed);
	} else {
		$self->{icon} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	}

	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}

	$self->widget->set_relief('none');
	PerlPanel::tips->set_tip($self->widget, _('Menu'));

	$self->{language} = $ENV{LANG} || 'en_US';
	$self->{language} =~ s/\..*$//g;

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;

	if ($self->{config}->{apps_in_submenu} eq 'true' && !PerlPanel::has_action_menu) {

		my $item = $self->menu_item(
			$self->{config}->{label},
			PerlPanel::get_applet_pbf('gnomemenu', PerlPanel::menu_icon_size),
		);

		my $menu = Gtk2::Menu->new;
		$item->set_submenu($menu);
		$self->menu->append($item);

		$self->create_submenu_for($self->{config}->{base}, $menu);

	} else {
		$self->create_submenu_for($self->{config}->{base}, $self->menu);

	}

	if ($self->{config}->{show_control_items} eq 'true' && !PerlPanel::has_action_menu) {
		$self->add_control_items(
			menu_edit_command  => "nautilus --no-desktop \"$self->{config}->{base}\"",
		);
	}

	return 1;
}

sub create_submenu_for {
	my ($self, $uri, $menu) = @_;

	my ($result, @files) = Gnome2::VFS::Directory->list_load($uri, 'default');

	if ($result ne 'ok') {
		return undef;

	} else {

		my %files;
		my %dirs;
		foreach my $file (@files) {
			next if ($file->{name} =~ /^\./);

			if ($file->{type} eq 'directory') {
				$dirs{$file->{name}} = $file;

			} else {
				$files{$file->{name}} = $file;

			}
		}

		foreach my $dirname (sort keys %dirs) {

			my $dir  = $dirs{$dirname};
			my $path = sprintf('%s/%s', $uri, $dir->{name});

			# the metadata for directories is held in $dir/.directory:
			my $dfile = sprintf('%s/.directory', $path);
			my ($result, undef) = Gnome2::VFS->get_file_info($dfile, 'default');

			my $menu_icon;

			if ($result eq 'ok') {
				my $data = $self->get_file_contents($dfile);

				my (undef, undef, $icon, undef) = $self->parse_desktopfile($data);

				if ($icon eq '') {
					$menu_icon = PerlPanel::lookup_icon('gnome-fs-directory');

				} else {
					$menu_icon = $icon;
				}
			} else {
				$menu_icon = PerlPanel::lookup_icon('gnome-fs-directory');

			}

			my $item = $self->menu_item(
				$dir->{name},
				$menu_icon
			);
			my $sub_menu = Gtk2::Menu->new;
			$item->set_submenu($sub_menu);
			$menu->append($item);

			$self->create_submenu_for($path, $sub_menu);
		}

		foreach my $filename (sort keys %files) {

			my $file = $files{$filename};
			my $path = sprintf('%s/%s', $uri, $file->{name});
			my $data = $self->get_file_contents($path);
			my ($name, $comment, $icon, $program) = $self->parse_desktopfile($data);
			if ($name ne '' && $program ne '') {
				my $item = $self->menu_item(
					$name,
					(-e $icon ? $icon : 'gtk-execute'),
					sub { system("$program &") },
				);
				if ($comment ne '') {
					PerlPanel::tips->set_tip($item, $comment);
				}
				$menu->append($item);
			}

		}

		return 1;
	}
}

sub parse_desktopfile {
	my ($self, $data) = @_;
	my ($name, $comment, $icon, $program);
	my $namespace;
	my $params = {};
	foreach my $line (split(/\n/, $data)) {
		my ($name, $value) = split(/=/, $line, 2);
		if ($name =~ /^\[($DESKTOP_NAMESPACE)\]/i) {
			$namespace = $1;
		} elsif ($namespace ne '') {
			$params->{$namespace}->{$name} = $value;
		} else {
			$params->{orphans}->{$name} = $value;
		}
	}
	$name    = ($params->{$DESKTOP_NAMESPACE}{"Name[$self->{language}]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Name[$self->{language}]"} : $params->{$DESKTOP_NAMESPACE}{Name});
	$comment = ($params->{$DESKTOP_NAMESPACE}{"Comment[$self->{language}]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Comment[$self->{language}]"} : $params->{$DESKTOP_NAMESPACE}{Comment});
	$program = $params->{$DESKTOP_NAMESPACE}{Exec};

	if (-e $params->{$DESKTOP_NAMESPACE}{Icon}) {
		$icon = $params->{$DESKTOP_NAMESPACE}{Icon};
	} else {
		$icon = PerlPanel::lookup_icon($params->{$DESKTOP_NAMESPACE}{Icon});
		if (! -e $icon) {
			if (-e "/usr/share/pixmaps/$params->{$DESKTOP_NAMESPACE}{Icon}") {
				$icon = PerlPanel::lookup_icon($params->{$DESKTOP_NAMESPACE}{Icon});
			}
		}
	}

	return ($name, $comment, $icon, $program);
}

sub get_file_contents {
	my ($self, $path) = @_;
	my ($result, $info) = Gnome2::VFS->get_file_info($path, 'default');
	if ($result eq 'ok' && $info->{type} eq 'regular') {
		return Gnome2::VFS->read_entire_file($path);
	} else {
		return undef;
	}
}

sub get_default_config {
	return {
		label			=> _('Applications'),
		arrow			=> 'true',
		show_control_items	=> 'true',
		apps_in_submenu		=> 'true',
		base			=> 'applications:',
	};
}

1;
