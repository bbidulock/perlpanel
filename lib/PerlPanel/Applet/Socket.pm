# $Id: Socket.pm,v 1.3 2003/08/12 16:03:14 jodrell Exp $
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
package PerlPanel::Applet::Socket;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Socket->new;
	$self->{id} = $self->{widget}->get_id;
	$self->{socketfile} = sprintf('%s/.$s/socketid', $ENV{HOME}, lc($PerlPanel::NAME));
	open(SOCKETFILE, "$self->{socketfile}") or $PerlPanel::OBJECT_REF->error("Error opening '$self->{socketfile}': $!", sub { $PerlPanel::OBJECT_REF->shutdown });
	print SOCKETFILE $self->{id};
	close(SOCKETFILE);
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
