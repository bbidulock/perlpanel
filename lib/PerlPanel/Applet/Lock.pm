# $Id: Lock.pm,v 1.6 2004/02/11 17:04:09 jodrell Exp $
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
package PerlPanel::Applet::Lock;
use vars qw($DEFAULT_LOCK_PROGRAM $DEFAULT_ARGS);
use strict;

chomp(our $DEFAULT_LOCK_PROGRAM = `which xscreensaver-command`);
our $DEFAULT_ARGS = '-lock';

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Lock');
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('lock', PerlPanel::icon_size)));
	$self->widget->signal_connect('clicked', sub { $self->lock });
	$self->widget->set_relief('none');
	PerlPanel::tips->set_tip($self->widget, 'Lock the Screen');
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
	return {
		program => $DEFAULT_LOCK_PROGRAM,
		args	=> $DEFAULT_ARGS,
	};
}

sub lock {
	my $self = shift;
	my $cmd = sprintf(
		'%s %s &',
		$self->{config}->{program},
		$self->{config}->{args},
	);
	system($cmd);
	return 1;
}

1;
