# $Id: NautilusBookmarks.pm,v 1.8 2004/04/30 16:28:04 jodrell Exp $
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
use strict;

sub configure {
	my $self = shift;
	$self->{file} = sprintf('%s/.nautilus/bookmarks.xml', $ENV{HOME});
	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('nautilusbookmarks', PerlPanel::icon_size));
	$self->{widget} = Gtk2::Button->new;
	$self->{use_gnome} = 0;
	eval 'use Gnome2 ; $self->{use_gnome} = 1';
	$self->widget->set_relief('none');
	$self->widget->add($self->{icon});
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	PerlPanel::tips->set_tip($self->widget, _('Nautilus Bookmarks'));
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
	my $bookmarks = XMLin($self->{file});
	$self->{mtime} = (stat($bookmarks))[9];
	if ($self->{use_gnome} == 1) {
		$self->{theme} = Gnome2::IconTheme->new;
	}
	foreach my $name (sort keys %{$bookmarks->{bookmark}}) {
		my $icon;
		if ($self->{use_gnome} == 1) {
			($icon, undef) = $self->{theme}->lookup_icon($bookmarks->{bookmark}->{$name}->{icon_name}, PerlPanel::icon_size_name);
		} else {
			$icon = 'gtk-jump-to',
		}
		$self->menu->append($self->menu_item(
			$name,
			$icon,
			sub { system("nautilus --no-desktop \"$bookmarks->{bookmark}->{$name}->{uri}\" &") },
		));
	}
	return 1;
}

sub get_default_config {
	return undef;
}

1;
