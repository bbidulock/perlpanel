# $Id: Lock.pm,v 1.4 2004/01/16 00:31:21 jodrell Exp $
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
use vars qw($DEFAULT_LOCK_PROGRAM, $DEFAULT_ARGS $DEFAULT_ICON);
use strict;

chomp(our $DEFAULT_LOCK_PROGRAM = `which xscreensaver-command`);
our $DEFAULT_ARGS = '-lock';
our $DEFAULT_ICON = sprintf('%s/share/pixmaps/%s/applets/lock.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME));

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	if (-e $PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{icon}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{icon});
		$self->{pixbuf} = $self->{pixbuf}->scale_simple($PerlPanel::OBJECT_REF->icon_size, $PerlPanel::OBJECT_REF->icon_size, 'bilinear');
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-dialog-error', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->signal_connect('clicked', sub { $self->lock });
	$self->{widget}->set_relief('none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Lock the Screen');
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
		icon	=> $DEFAULT_ICON,
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
