# $Id: Webcam.pm,v 1.1 2005/01/31 21:59:01 jodrell Exp $
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
package PerlPanel::Applet::Webcam;
use Gnome2::VFS;
use vars qw($MULTI);
use strict;

our $MULTI = 1;

Gnome2::VFS->init;

sub new {
	my ($package, $id) = @_;
	my $self = {
		package	=> $package,
		id	=> $id,
	};
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('webcam', PerlPanel::icon_size)));
	PerlPanel::tips->set_tip($self->{widget}, _('Webcam'));
	$self->widget->set_relief('none');
	$self->widget->signal_connect('button_release_event', sub {
		if ($_[1]->button == 1) {
			$self->dialog;

		} elsif ($_[1]->button == 3) {
			$self->popup;

		}
	});
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
	return 'end';
}

sub get_default_config {
	return undef;
}

1;
