# $Id: Clock.pm,v 1.22 2004/09/17 11:28:53 jodrell Exp $
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
package PerlPanel::Applet::Clock;
use POSIX qw(strftime);
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self,		$self->{package});
	return			$self;
}

sub configure {
	my $self = shift;
	$self->{label} = Gtk2::Label->new;
	$self->{widget} = Gtk2::EventBox->new;
	$self->widget->add($self->{label});
	$self->{config} = PerlPanel::get_config('Clock');
	$self->widget->show_all;
	$self->update;
	Glib::Timeout->add(1000, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;
	$self->{label}->set_text(' '.strftime($self->{config}{format}, localtime(time())).' ');
	PerlPanel::tips->set_tip($self->widget, strftime($self->{config}{date_format}, localtime(time())));
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

sub get_default_config {
	return {
		format		=> '%H:%M',
		date_format	=> '%c',
	}
}

1;
