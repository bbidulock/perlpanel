# $Id: NautilusBookmarks.pm,v 1.6 2004/02/17 12:30:31 jodrell Exp $
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
use Gnome2::NautilusBookmarks;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gnome2::NautilusBookmarks->new(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('nautilusbookmarks', PerlPanel::icon_size)));
	$self->widget->set_relief('none');
	PerlPanel::tips->set_tip($self->widget, 'Nautilus Bookmarks');
	$self->widget->signal_connect('clicked', sub {
		$self->widget->get_menu->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, $self->widget, undef);
	});
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x, undef) = PerlPanel::get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);
	} else {
		$self->widget->get_menu->realize;
		$self->widget->get_menu->show_all;
		return ($x, (PerlPanel::screen_height) - $self->widget->get_menu->allocation->height - PerlPanel::panel->allocation->height);
	}
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 0;
}

sub end {
	return 'start';
}

sub get_default_config {
	return undef;
}

1;
