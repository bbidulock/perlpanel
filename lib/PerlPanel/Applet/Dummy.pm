# $Id: Dummy.pm,v 1.2 2003/06/02 13:17:06 jodrell Exp $
package PerlPanel::Applet::Dummy;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new('Click Me!');
	$self->{widget}->signal_connect(
		'clicked',
		sub {
			$PerlPanel::OBJECT_REF->alert('Hello World!');
		}
	);
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

1;
