# $Id: Socket.pm,v 1.1 2003/06/30 15:29:36 jodrell Exp $
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
	close (SOCKETFILE);
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
