# $Id: NautilusBookmarks.pm,v 1.21 2004/11/04 16:12:01 jodrell Exp $
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
package PerlPanel::Applet::NautilusBookmarks;
use base 'PerlPanel::MenuBase';
use XML::Simple;
use Gnome2::VFS;
use strict;

sub configure {
	my $self = shift;
	$self->{file} = sprintf('%s/.nautilus/bookmarks.xml', $ENV{HOME});
	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('nautilusbookmarks', PerlPanel::icon_size));
	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	$self->{config} = PerlPanel::get_config('NautilusBookmarks');
	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	PerlPanel::tips->set_tip($self->widget, _('Nautilus Bookmarks'));

	PerlPanel::add_timeout(1000, sub {
		$self->create_menu if ($self->file_age > $self->{mtime});
		return 1;
	});

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

	my ($major, $minor) = Gnome2::VFS->GET_VERSION_INFO;

	if (PerlPanel::position eq 'top') {
		$self->add_places if ($major >= 2 && $minor >= 6);
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
		$self->add_bookmarks;
	} else {
		$self->add_bookmarks;
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
		$self->add_places if ($major >= 2 && $minor >= 6);
	}

	return 1;
}

sub add_places {
	my $self = shift;

	my $item = $self->menu_item(_('Places'), PerlPanel::lookup_icon('gnome-fs-directory'), undef);
	my $submenu = Gtk2::Menu->new;
	$item->set_submenu($submenu);
	$self->menu->append($item);

	# there's no way to magically load these from nautilus, so we just clone them:
	$submenu->append($self->menu_item(
		_('Home'),
		'gtk-home',
		sub { PerlPanel::launch("nautilus --no-desktop $ENV{HOME}") }
	));
	$submenu->append($self->menu_item(
		_('Computer'),
		PerlPanel::lookup_icon('gnome-fs-client'),
		sub { PerlPanel::launch("nautilus --no-desktop computer:") }
	));
	$submenu->append($self->menu_item(
		_('Templates'),
		PerlPanel::lookup_icon('gnome-fs-directory'),
		sub { PerlPanel::launch("nautilus --no-desktop $ENV{HOME}/Templates") }
	));
	$submenu->append($self->menu_item(
		_('Trash'),
		PerlPanel::lookup_icon('gnome-fs-trash-full'),
		sub { PerlPanel::launch("nautilus --no-desktop $ENV{HOME}/.Trash") }
	));
	$submenu->append($self->menu_item(
		_('CD Burner'),
		PerlPanel::lookup_icon('gnome-dev-cdrom'),
		sub { PerlPanel::launch("nautilus --no-desktop burn:") }
	));

	return 1;
}

sub add_bookmarks {
	my $self = shift;

	$self->{mtime} = $self->file_age;

	my $bookmarks = XMLin($self->{file});
	foreach my $name (sort keys %{$bookmarks->{bookmark}}) {
		$self->menu->append($self->menu_item(
			$name,
			PerlPanel::lookup_icon($bookmarks->{bookmark}->{$name}->{icon_name}),
			sub { PerlPanel::launch("nautilus --no-desktop \"$bookmarks->{bookmark}->{$name}->{uri}\"") },
		));
	}

	return 1;
}

sub get_default_config {
	return undef;
}

1;
