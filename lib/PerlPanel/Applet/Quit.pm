# $Id: Quit.pm,v 1.3 2003/05/29 12:32:18 jodrell Exp $
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
	$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-quit', $PerlPanel::ICON_SIZE_NAME);
	$self->{widget}->add($self->{pixmap});
	my $code = sprintf('$%s::OBJECT_REF->shutdown', caller());
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

1;
