# $Id: Reload.pm,v 1.2 2003/06/03 16:10:21 jodrell Exp $
package PerlPanel::Applet::Reload;
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
	$self->{icon} = Gtk2::Image->new_from_stock('gtk-refresh', $PerlPanel::OBJECT_REF->icon_size_name);
	$self->{widget}->add($self->{icon});
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Reload');
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub {
		$PerlPanel::OBJECT_REF->reload;
	});
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
