# $Id: Lock.pm,v 1.2 2003/07/14 11:31:39 jodrell Exp $
package PerlPanel::Applet::Lock;
use vars qw($DEFAULT_LOCK_PROGRAM, $DEFAULT_ARGS $DEFAULT_LOCK_ICON);
use strict;

chomp(our $DEFAULT_LOCK_PROGRAM = `which xscreensaver-command`);
our $DEFAULT_ARGS = '-lock';
our $DEFAULT_LOCK_ICON = sprintf('%s/share/pixmaps/perlpanel-lock-screen.png', $PerlPanel::PREFIX);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	if (-e $PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{icon}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{icon});
		$self->{pixbuf} = $self->{pixbuf}->scale_simple($PerlPanel::OBJECT_REF->icon_size, $PerlPanel::OBJECT_REF->icon_size, 'bilinear');
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-dialog-error', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->signal_connect('clicked', sub { $self->lock });
	$self->{widget}->set_relief('none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Lock the Screen');
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
	return {
		program => $DEFAULT_LOCK_PROGRAM,
		args	=> $DEFAULT_ARGS,
		icon	=> $DEFAULT_LOCK_ICON,
	};
}

sub lock {
	my $self = shift;
	my $cmd = sprintf(
		'%s %s &',
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{program},
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Lock}{args},
	);
	system($cmd);
	return 1;
}

1;
