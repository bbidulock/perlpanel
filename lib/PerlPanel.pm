# $Id: PerlPanel.pm,v 1.4 2003/06/02 13:17:06 jodrell Exp $
package PerlPanel;
use XML::Simple;
use Gtk2;
use Data::Dumper;
use vars qw($NAME $VERSION $PREFIX @APPLETSDIR %DEFAULTS $TOOLTIP_REF $OBJECT_REF $ICON_SIZE_NAME $ICON_SIZE);
use strict;

our $NAME	= 'PerlPanel';
our $VERSION	= '0.01';
our $PREFIX	= '/usr';

our $ICON_SIZE		= 24;
our $ICON_SIZE_NAME	= 'large-toolbar';

our @APPLETSDIR = (
	sprintf('%s/share/%s/applets', $PREFIX, lc($NAME)),
	sprintf('%s/.%s/applets', $ENV{HOME}, lc($NAME)),
);

our %DEFAULTS = (
	panel => {
		width	=> 1024,
		height	=> 24,
		x	=> 736,
		y	=> 0,
		spacing	=> 0,
	},
	applets => [
		'BBMenu',
		'IconBar',
		'Clock',
		'Quit',
		'Reload',
	],
	applet => {
		padding	=> 3,
	},
);

Gtk2->init;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{rcfile}		= sprintf('%s/.%src', $ENV{HOME}, lc($NAME));
	$OBJECT_REF		= $self;
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
	Gtk2->main;
	return 1;
}

sub load_config {
	my $self = shift;
	$self->{config} = (-e $self->{rcfile} ? XMLin($self->{rcfile}) : \%DEFAULTS);
	return 1;
}

sub save_config {
	my $self = shift;
	open(RCFILE, ">$self->{rcfile}") or print STDERR "Error writing to '$self->{rcfile}': $!\n" and exit 1;
	print RCFILE XMLout($self->{config});
	close(RCFILE);
	return 1;
}

sub build_ui {
	my $self = shift;
	$self->{tooltips} = Gtk2::Tooltips->new;
	our $TOOLTIP_REF = $self->{tooltips};
	$self->{panel} = Gtk2::Window->new('popup');
	$self->{panel}->set_default_size($self->{config}{panel}{width}, $self->{config}{panel}{height});
	$self->{panel}->move($self->{config}{panel}{y}, $self->{config}{panel}{x});
	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_spacing($self->{config}{applet}{padding});
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
			$self->add($applet->widget, $applet->expand, $applet->fill, $applet->end);
		}
	}
}

sub add {
	my ($self, $widget, $expand, $fill, $end) = @_;
	if ($end == 'end') {
		$self->{hbox}->pack_start($widget, $expand, $fill, 0);
	} else {
		$self->{hbox}->pack_end($widget, $expand, $fill, 0);
	}
	return 1;
}

sub show_all {
	$_[0]->{panel}->show_all();
}

sub shutdown {
	my $self = shift;
	$self->save_config;
	exit;
}

sub reload {
	my $self = shift;
	$self->{panel}->destroy;
	my $panel = PerlPanel->new;
	$panel->init;
}

sub request_string {
	my ($self, $message, $callback, $visible) = @_;

	my $dialog = Gtk2::Dialog->new;
	$dialog->set_border_width(8);
	$dialog->vbox->set_spacing(8);

	my $entry = Gtk2::Entry->new;
	#if ($visible == 1) {
	#	$entry->set_visible(1);
	#}
	$entry->signal_connect('activate', sub { $dialog->destroy ; &$callback($entry->get_text) });

	my $table = Gtk2::Table->new(2, 2, 0);
	$table->set_col_spacings(8);
	$table->set_row_spacings(8);

	$table->attach_defaults(Gtk2::Image->new_from_stock('gtk-dialog-question', 'dialog'), 0, 1, 0, 2);
	$table->attach_defaults(Gtk2::Label->new($message), 1, 2, 0, 1);
	$table->attach_defaults($entry, 1, 2, 1, 2);

	$dialog->vbox->pack_start($table, 1, 1, 0);

	my $cancel_button = Gtk2::Button->new_from_stock('gtk-cancel');
	$cancel_button->signal_connect('clicked', sub { $dialog->destroy });

	my $ok_button = Gtk2::Button->new_from_stock('gtk-ok');
	$ok_button->signal_connect('clicked', sub { $dialog->destroy ; &$callback($entry->get_text) });

	$dialog->action_area->pack_start($cancel_button, 0, 1, 0);
	$dialog->action_area->pack_end($ok_button, 0, 1, 0);

	$dialog->show_all;

	$entry->grab_focus;

	return 1;
}

sub request_password {
	my ($self, $message, $callback) = @_;
	$self->request_string($message, $callback, 1);
}

# you shouldn't need to access this directly -
# instead use one of the wrappers below:
sub alert {
	my ($self, $message, $ok_callback, $cancel_callback, $stock) = @_;

	my $dialog = Gtk2::Dialog->new;
	$dialog->set_border_width(8);
	$dialog->vbox->set_spacing(8);

	my $hbox = Gtk2::HBox->new;
	$hbox->set_spacing(8);
	$hbox->pack_start(Gtk2::Image->new_from_stock($stock, 'dialog'), 0, 0, 0);
	$hbox->pack_start(Gtk2::Label->new($message), 1, 1, 0);

	$dialog->vbox->pack_start($hbox, 1, 1, 0);

	# only display if $cancel_callback is defined:
	if (defined($cancel_callback)) {
		my $cancel_button = Gtk2::Button->new_from_stock('gtk-cancel');
		$cancel_button->signal_connect('clicked', sub { $dialog->destroy, &$cancel_callback() });
		$dialog->action_area->pack_start($cancel_button, 0, 1, 0);
	}

	my $ok_button = Gtk2::Button->new_from_stock('gtk-ok');
	$ok_button->signal_connect('clicked', sub { $dialog->destroy });
	# only add callback if $ok_callback is defined:
	if (defined($cancel_callback)) {
		$ok_button->signal_connect('clicked', sub { &$ok_callback() });
	}

	$dialog->action_area->pack_end($ok_button, 0, 1, 0);

	$dialog->show_all;

	return 1;
}

sub question {
	my ($self, $message, $ok_callback, $cancel_callback) = @_;
	return $self->alert($message, $ok_callback, $cancel_callback, 'gtk-dialog-question');
}

sub error {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'gtk-dialog-error');
}

sub warning {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'gtk-dialog-warning');
}

sub notify {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'gtk-dialog-info');
}

1;
