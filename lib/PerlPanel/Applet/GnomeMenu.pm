# $Id: GnomeMenu.pm,v 1.18 2004/09/24 14:49:13 jodrell Exp $
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
use PerlPanel::DesktopEntry;
use Gnome2::VFS;
use strict;

$PerlPanel::DesktopEntry::SILENT = 1;

sub configure {
	my $self = shift;

	Gnome2::VFS->init;

	$self->{widget} = Gtk2::Button->new;

	$self->{config} = PerlPanel::get_config('GnomeMenu');

	$self->{pixbuf} = PerlPanel::get_applet_pbf('gnomemenu', PerlPanel::icon_size);

	if ($self->{config}->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($self->{pixbuf}), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/%s/menu-arrow-%s.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME), lc(PerlPanel::position)));
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

	$self->widget->show_all;

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
		$self->add_control_items;
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
				my $entry = PerlPanel::DesktopEntry->new($dfile);
				my $icon;
				if (defined($entry)) {
					$icon = $entry->Icon(PerlPanel::locale);
				}

				if ($icon eq '') {
					$menu_icon = PerlPanel::lookup_icon('gnome-fs-directory');

				} else {
					$menu_icon = PerlPanel::lookup_icon($icon);
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
			my $entry = PerlPanel::DesktopEntry->new($path);

			my $name	= $entry->Name(PerlPanel::locale);
			my $comment	= $entry->Comment(PerlPanel::locale);
			my $program	= $entry->Exec(PerlPanel::locale);
			my $icon	= $entry->Icon(PerlPanel::locale);

			$icon = PerlPanel::lookup_icon($icon);

			if ($name ne '' && $program ne '') {
				my $item = $self->menu_item(
					$name,
					(-e $icon ? $icon : 'gtk-execute'),
					sub { PerlPanel::launch($program, $entry->StartupNotify) },
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

sub get_default_config {
	return {
		label			=> _('Applications'),
		arrow			=> 'false',
		show_control_items	=> 'true',
		apps_in_submenu		=> 'true',
		base			=> 'applications:',
	};
}

1;
