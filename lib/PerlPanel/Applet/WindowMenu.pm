# $Id: WindowMenu.pm,v 1.4 2004/02/11 17:04:09 jodrell Exp $
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
package PerlPanel::Applet::WindowMenu;
use Gnome2::Wnck;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('windowmenu', PerlPanel::icon_size)));
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	PerlPanel::tips->set_tip($self->widget, 'Window List');
	return 1;
}

sub clicked {
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
		$self->{menu}->append($item);
	} else {
		foreach my $window (@windows) {
			my $pbf = $window->get_icon;
			my $x0 = $pbf->get_width;
			my $y0 = $pbf->get_height;
			if ($x0 != 16 || $y0 != 16) {
				my ($x1, $y1);
				if ($x0 > $y0) {
					# image is landscape:
					$x1 = 16;
					$y1 = int(($y0 / $x0) * 16);
				} elsif ($x0 == $y0) {
					# image is square:
					$x1 = 16;
					$y1 = 16;
				} else {
					# image is portrait:
					$x1 = int(($x0 / $y0) * 16);
					$y1 = 16;
				}
				$pbf = $pbf->scale_simple($x1, $y1, 'bilinear');
			}
			my $label = $window->get_name;
			$label = (length($label) < 25 ? $label : substr($label, 0, 22).'...');
			my $item = Gtk2::ImageMenuItem->new_with_label($label);
			$item->set_image(Gtk2::Image->new_from_pixbuf($pbf));
			$item->signal_connect('activate', sub { $window->activate });
			$self->{menu}->append($item);
		}
	}
	$self->{menu}->show_all;
	$self->{menu}->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, undef, undef);
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x, undef) = PerlPanel::get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);
	} else {
		$self->{menu}->realize;
		$self->{menu}->show_all;
		return ($x, PerlPanel::screen_height() - $self->{menu}->allocation->height - PerlPanel::panel->allocation->height);
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
