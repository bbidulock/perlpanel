# $Id: BBMenu.pm,v 1.1 2003/05/29 12:32:18 jodrell Exp $
package PerlPanel::Applet::BBMenu;
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
	$self->{icon} = Gtk2::Image->new_from_stock('gtk-jump-to', $PerlPanel::ICON_SIZE_NAME);
	$self->{widget}->add($self->{icon});
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Menu');
	$self->{widget}->set_relief('none');
	#
	# menu code goes here :-)
	#
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
