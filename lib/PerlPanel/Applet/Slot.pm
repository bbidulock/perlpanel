# $Id: Slot.pm,v 1.2 2004/02/11 17:04:09 jodrell Exp $
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
package PerlPanel::Applet::Slot;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{widget} = Gtk2::ScrolledWindow->new;

	my $socket = Gtk2::Socket->new;

	$self->widget->add_with_viewport($socket);

	$self->widget->set_policy('never', 'never');
	$self->widget->set_border_width(0);
	$self->widget->child->set_border_width(0);
	$self->widget->child->set_shadow_type('in');


	$self->{socketfile} = sprintf('%s/.%s/socketid', $ENV{HOME}, lc($PerlPanel::NAME));

	$socket->signal_connect('realize', sub {
		open(SOCKETFILE, ">$self->{socketfile}") or PerlPanel::error("Error opening '$self->{socketfile}': $!", sub { $PerlPanel::OBJECT_REF->shutdown });
		print SOCKETFILE $socket->get_id;
		close(SOCKETFILE);
	});

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

1;
