# $Id: NautilusBookmarks.pm,v 1.3 2004/01/11 23:07:45 jodrell Exp $
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
package PerlPanel::Applet::NautilusBookmarks;
use Gnome2::NautilusBookmarks;
use vars qw($ICON_DIR);
use strict;

our $ICON_DIR  = sprintf('%s/share/pixmaps/%s/applets', $PerlPanel::PREFIX, lc($PerlPanel::NAME));

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	my $file = "$ICON_DIR/nautilusbookmarks.png";
	my $pbf = Gtk2::Gdk::Pixbuf->new_from_file($file);
	if ($pbf->get_height != $PerlPanel::OBJECT_REF->icon_size) {
		$pbf = $pbf->scale_simple($PerlPanel::OBJECT_REF->icon_size, $PerlPanel::OBJECT_REF->icon_size, 'bilinear');
	}
	$self->{widget} = Gnome2::NautilusBookmarks->new(Gtk2::Image->new_from_pixbuf($pbf));
	$self->widget->set_relief('none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->widget, 'Nautilus Bookmarks');
	$self->widget->signal_connect('clicked', sub {
		$self->widget->get_menu->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, $self->widget, undef);
	});
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x, undef) = $PerlPanel::OBJECT_REF->get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if ($PerlPanel::OBJECT_REF->position eq 'top') {
		return ($x, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		$self->widget->get_menu->realize;
		$self->widget->get_menu->show_all;
		return ($x, $PerlPanel::OBJECT_REF->screen_height - $self->widget->get_menu->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
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
