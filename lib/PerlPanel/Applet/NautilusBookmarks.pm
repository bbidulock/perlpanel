# $Id: NautilusBookmarks.pm,v 1.14 2004/06/04 09:02:12 jodrell Exp $
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

	Glib::Timeout->add(1000, sub {
		$self->create_menu if ($self->file_age > $self->{mtime});
		return 1;
	});

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

	$self->{mtime} = $self->file_age;

	my $bookmarks = XMLin($self->{file});
	foreach my $name (sort keys %{$bookmarks->{bookmark}}) {
		$self->menu->append($self->menu_item(
			$name,
			PerlPanel::lookup_icon($bookmarks->{bookmark}->{$name}->{icon_name}),
			sub { system("nautilus --no-desktop \"$bookmarks->{bookmark}->{$name}->{uri}\" &") },
		));
	}
	return 1;
}

sub file_age {
	my $self = shift;
	return (stat($self->{file}))[9];
}

sub get_default_config {
	return undef;
}

1;
