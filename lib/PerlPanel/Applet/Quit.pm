# $Id: Quit.pm,v 1.2 2003/05/27 16:00:32 jodrell Exp $
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
	$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-quit', 'menu');
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->signal_connect('clicked', sub { eval caller()."->shutdown(\$".caller()."::OBJECT_REF)" });
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
