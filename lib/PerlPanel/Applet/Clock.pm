# $Id: Clock.pm,v 1.2 2003/05/27 16:00:32 jodrell Exp $
package PerlPanel::Applet::Clock;
use Config::Simple;
use POSIX qw(strftime);
use vars qw($FORMAT $INTERVAL);
use strict;

our $FORMAT	= '%H:%M:%S';
our $INTERVAL	= 1;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Label->new();
	$self->update;
	return 1;
}

sub update {
	my $self = shift;
	$self->{widget}->set_text(strftime($FORMAT, localtime(time())));
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

1;
