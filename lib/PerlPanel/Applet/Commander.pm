# $Id: Commander.pm,v 1.1 2003/05/27 16:00:32 jodrell Exp $
package PerlPanel::Applet::Commander;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Entry->new();
	$self->{widget}->signal_connect('activate', sub { $self->activate });
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Run Command');
	$self->{widget}->grab_focus();
	return 1;
}

sub activate {
	my $self = shift;
	my $command = sprintf('%s &', $self->{widget}->get_text());
	system($command);
	$self->{widget}->set_text('');
	$self->{widget}->grab_focus();
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

1;
