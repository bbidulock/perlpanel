# $Id: XMMS.pm,v 1.3 2003/07/05 12:41:14 jodrell Exp $
package PerlPanel::Applet::XMMS;
use vars qw(%TOOLTIPS %STOCK_IDS %CALLBACKS);
use Xmms::Remote;
use strict;

our %TOOLTIPS = (
	prev	=> 'Play Previous Track',
	stop	=> 'Stop Playing',
	play	=> 'Play',
	next	=> 'Play Next Track',
	open	=> 'Play File or Directory',
);

our %STOCK_IDS = (
	prev	=> 'gtk-goto-first',
	stop	=> 'gtk-stop',
	play	=> 'gtk-go-forward',
	next	=> 'gtk-goto-last',
	open	=> 'gtk-open',
);

our %CALLBACKS = (
	prev	=> sub { Xmms::Remote->new->playlist_prev },
	stop	=> sub { Xmms::Remote->new->stop },
	play	=> sub { Xmms::Remote->new->play },
	next	=> sub { Xmms::Remote->new->playlist_next },
	open	=> sub { Xmms::Remote->new->pl_win_toggle(1) },
);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	foreach my $name (qw(prev stop play next open)) {
		$self->{buttons}{$name} = $self->stock_button($STOCK_IDS{$name});
		$self->{buttons}{$name}->signal_connect('clicked', $CALLBACKS{$name});
		$PerlPanel::TOOLTIP_REF->set_tip($self->{buttons}{$name}, $TOOLTIPS{$name});
		$self->{widget}->pack_start($self->{buttons}{$name}, 0, 0, 0);
	}
	return 1;
}

sub stock_button {
	my ($self, $stock_id) = @_;
	my $button = Gtk2::Button->new;
	my $icon = Gtk2::Image->new_from_stock($stock_id, $PerlPanel::OBJECT_REF->icon_size_name);
	$button->set_relief('none');
	$button->add($icon);
	return $button;
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

sub get_default_config {
	return undef;
}

1;
