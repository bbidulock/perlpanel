# $Id: PerlPanel.pm,v 1.1 2003/05/27 14:54:42 jodrell Exp $
package PerlPanel;
use XML::Simple;
use Gtk2;
use Data::Dumper;
use vars qw($NAME $VERSION $PREFIX @APPLETSDIR %DEFAULTS $TOOLTIP_REF);
use strict;

our $NAME	= 'PerlPanel';
our $VERSION	= '0.01';
our $PREFIX	= '/usr';

our @APPLETSDIR = (
	sprintf('%s/share/%s/applets', $PREFIX, lc($NAME)),
	sprintf('%s/.%s/applets', $ENV{HOME}, lc($NAME)),
);

our %DEFAULTS = (
	panel => {
		width	=> 1024,
		height	=> 16,
		x	=> 0, #744,
		y	=> 0,
		spacing	=> 2,
	},
	applets => [
		'Quit',
		#'IconBar',
		'Clock',
	],
	applet => {
		padding	=> 0,
	},
);

Gtk2->init();

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{rcfile}		= sprintf('%s/.%src', $ENV{HOME}, lc($NAME));
	bless($self, $self->{package});
	return $self;
}

sub init {
	my $self = shift;
	$self->load_config;
	$self->build_ui;
	map { push(@INC, $_) } @APPLETSDIR;
	$self->load_applets;
	$self->show_all;
	Gtk2->main();
	return 1;
}

sub load_config {
	my $self = shift;
	$self->{config} = (-e $self->{rcfile} ? XMLin($self->{rcfile}) : \%DEFAULTS);
	return 1;
}

sub save_config {
}

sub build_ui {
	my $self = shift;
	$self->{tooltips} = Gtk2::Tooltips->new;
	our $TOOLTIP_REF = $self->{tooltips};
	$self->{panel} = Gtk2::Window->new('popup');
	$self->{panel}->set_default_size($self->{config}{panel}{width}, $self->{config}{panel}{height});
	$self->{panel}->move($self->{config}{panel}{y}, $self->{config}{panel}{x});
	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_spacing($self->{config}{panel}{spacing});
	$self->{panel}->add($self->{hbox});
	return 1;
}

sub load_applets {
	my $self = shift;
	foreach my $appletname (@{$self->{config}{applets}}) {
		my $applet;
		my $expr = sprintf('require("%s.pm") ; $applet = %s::Applet::%s->new', ucfirst($appletname), $self->{package}, ucfirst($appletname));
		eval($expr);
		if ($@) {
			print STDERR $@;
			exit 1;
		} else {
			$applet->configure;
			$self->add($applet->widget, $applet->expand, $applet->fill);
		}
	}
}

sub add {
	my ($self, $widget, $expand, $fill) = @_;
	$self->{hbox}->pack_start($widget, $expand, $fill, $self->{config}{applet}{padding});
}

sub show_all {
	$_[0]->{panel}->show_all();
}

1;
