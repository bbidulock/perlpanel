# $Id: Commander.pm,v 1.2 2003/05/29 12:32:18 jodrell Exp $
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
	$self->{widget} = Gtk2::Button->new;
	$self->{image} = Gtk2::Image->new_from_stock('gtk-execute', $PerlPanel::ICON_SIZE_NAME);
	$self->{widget}->add($self->{image});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub { $self->run });
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Run Command');
	return 1;
}

sub run {
	my $self = shift;
	$PerlPanel::OBJECT_REF->request_string(
		'Enter command:',
		sub {
			my $str = shift;
			my $cmd = sprintf('%s &', $str);
			if (!system($cmd)) {
				$PerlPanel::OBJECT_REF->warning(
					"Error running '$str'",
					sub { $self->run },
					sub {}
				);
			}
		}
	);
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
