# $Id: Clock.pm,v 1.4 2003/05/29 16:04:46 jodrell Exp $
package PerlPanel::Applet::Clock;
use Config::Simple;
use POSIX qw(strftime);
use vars qw($FORMAT $INTERVAL);
use strict;

our $FORMAT	= '%H:%M';
our $INTERVAL	= 5;

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
	Glib::Timeout->add($INTERVAL, sub { $self->update });
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
