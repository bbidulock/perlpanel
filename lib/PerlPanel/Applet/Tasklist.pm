# $Id: Tasklist.pm,v 1.5 2004/02/11 17:04:09 jodrell Exp $
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
package PerlPanel::Applet::Tasklist;
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
	$self->{tasklist} = Gnome2::Wnck::Tasklist->new($self->{screen});
	$self->{tasklist}->set_minimum_width(50);
	$self->{widget} = Gtk2::Alignment->new(0.5, 0.5, 1, 0);
	$self->widget->set_border_width(2);
	$self->widget->set_size_request(50, PerlPanel::icon_size);
	$self->widget->add($self->{tasklist});
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 1;
}

sub fill {
	return 1;
}

sub end {
	return 'start';
}

sub get_default_config {
	return undef;
}

1;
