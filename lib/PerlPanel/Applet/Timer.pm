# $Id: Timer.pm,v 1.1 2005/01/19 16:24:45 jodrell Exp $
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
package PerlPanel::Applet::Timer;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->{label} = Gtk2::Label->new;
	$self->widget->add(Gtk2::HBox->new);
	$self->widget->child->pack_start(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('Timer', PerlPanel::icon_size)), 0, 0, 0);
	$self->widget->child->pack_start($self->{label}, 1, 1, 0);
	$self->widget->signal_connect('clicked', sub { $self->config_dialog });
	$self->widget->show_all;
	return 1;
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

sub config_dialog {
	my $self = shift;
	my $glade = PerlPanel::load_glade('timer');
}

1;
