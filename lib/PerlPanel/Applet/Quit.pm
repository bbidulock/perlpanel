# $Id: Quit.pm,v 1.5 2003/06/05 11:32:10 jodrell Exp $
package PerlPanel::Applet::Quit;
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
	$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-quit', $PerlPanel::OBJECT_REF->icon_size_name);
	$self->{widget}->add($self->{pixmap});
	my $code = '$PerlPanel::OBJECT_REF->shutdown';
	$self->{widget}->signal_connect('clicked', sub { eval $code ; if ($@) { print STDERR "Error shutting down: $@\n" ; exit 1 } });
	$self->{widget}->set_relief('none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Quit');
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
