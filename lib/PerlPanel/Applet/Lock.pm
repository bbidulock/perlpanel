# $Id: Lock.pm,v 1.5 2004/01/26 00:50:58 jodrell Exp $
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
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf($PerlPanel::OBJECT_REF->get_applet_pbf('lock', $PerlPanel::OBJECT_REF->icon_size)));	$self->widget->signal_connect('clicked', sub { $self->lock });
	$self->widget->set_relief('none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->widget, 'Lock the Screen');
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
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{program},
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{args},
	);
	system($cmd);
	return 1;
}

1;
