# $Id: PerlPanel.pm,v 1.26 2003/07/03 16:07:39 jodrell Exp $
package PerlPanel;
use Gtk2;
use Data::Dumper;
use vars qw($NAME $VERSION $DESCRIPTION $VERSION @LEAD_AUTHORS @CO_AUTHORS $URL $LICENSE $PREFIX %DEFAULTS %SIZE_MAP $TOOLTIP_REF $OBJECT_REF);
use strict;

our $NAME		= 'PerlPanel';
our $VERSION		= '0.0.5';
our $DESCRIPTION	= 'A lean, mean panel program written in Perl.';
our @LEAD_AUTHORS	= (
	'Gavin Brown <gavin.brown@uk.com>',
);
our @CO_AUTHORS		= (
	'Scott Arrington <muppet@asofyet.org>',
	'Eric Andreychek <eric@openthought.net>',
);

our $URL		= 'http://jodrell.net/projects/perlpanel';
our $LICENSE		= "This program is Free Software. You may use it\nunder the terms of the GNU General Public License.";

chomp(our $PREFIX = `gtk-config --prefix`);

our %DEFAULTS = (
	version	=> $VERSION,
	panel => {
		position => 'bottom',
		spacing => 2,
		size => 'medium',
	},
	appletconf => {
		null => {},
	},
	applets => [
		'BBMenu',
		'IconBar',
		'Clock',
		'Configurator',
		'Commander',
	],
);

our %SIZE_MAP = (
	tiny	=> ['16', 'menu'],
	small	=> ['18', 'small-toolbar'],
	medium	=> ['24', 'large-toolbar'],
	large	=> ['48', 'dialog'],
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
	chdir($ENV{HOME});
	my $self = shift;
	$self->check_deps;
	$self->load_config;
	$self->get_screen || $self->parse_xdpyinfo;
	$self->build_ui;
	push(@INC, sprintf('%s/lib/%s/%s/Applet', $PREFIX, lc($NAME), $NAME), sprintf('%s/.%s/applets', $ENV{HOME}, lc($NAME)));
	$self->load_applets;
	$self->show_all;
	$self->move;
	Gtk2->main;
	return 1;
}

sub check_deps {
	my $self = shift;
	eval 'use XML::Simple;';
	if ($@) {
		$self->error("Couldn't load the XML::Simple module!", sub { exit });
		Gtk2->main();
	} else {
		return 1;
	}
}

sub get_screen {
	my $self = shift;
	my $code = '$self->{screen} = Gtk2::Gdk::Screen->get_screen';
	return eval($code);
}

sub parse_xdpyinfo {
	my $self = shift;
	chomp($self->{xdpyinfo} = `which xdpyinfo`);
	open(XDPYINFO, "$self->{xdpyinfo} -display $ENV{DISPLAY} |") or $self->error("Can't open pipe from '$self->{xdpyinfo}': $!", sub { exit });
	while (<XDPYINFO>) {
		if (/dimensions:\s+(\d+)x(\d+)\s+pixels/i) {
			$self->{screen_width}  = $1;
			$self->{screen_height} = $2;
		}
	}
	close(XDPYINFO);
	return 1;
}

sub load_config {
	my $self = shift;
	$self->{config} = (-e $self->{rcfile} ? XMLin($self->{rcfile}) : \%DEFAULTS);
	if ($self->{config}{version} ne $VERSION) {
		$self->error("Your config file is from an earlier\nversion ($self->{config}{version}). Please delete it and\nrestart $NAME.", sub { exit });
		Gtk2->main;
		return undef;
	}
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
	$self->{panel}->set_default_size($self->screen_width, 0);
	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_spacing($self->{config}{panel}{spacing});
	$self->{port} = Gtk2::Viewport->new;
	$self->{port}->set_shadow_type('out');
	$self->{port}->add($self->{hbox});
	$self->{panel}->add($self->{port});
	$self->{icon} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/pixmaps/%s-menu-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)));
	return 1;
}

sub load_applets {
	my $self = shift;
	if (ref($self->{config}{applets}) ne 'ARRAY') {
		$self->{config}{applets} = [ $self->{config}{applets} ];
	}
	foreach my $appletname (@{$self->{config}{applets}}) {
		my $applet;
		my $expr = sprintf('require("%s.pm") ; $applet = %s::Applet::%s->new', ucfirst($appletname), $self->{package}, ucfirst($appletname));
		eval($expr);
		print STDERR $@;
		if ($@) {
			my $message = "Error loading $appletname applet.\n";
			if ($@ =~ /can't locate/i) {
				$message = "Error: couldn't load applet file $appletname.pm in\n\n\t".join("\n\t", @INC);
			}
			$self->error($message, sub { $self->shutdown });
			return undef;
		} else {
			if (!defined($self->{config}{appletconf}{$appletname})) {
				my $hashref;
				eval '$hashref = $applet->get_default_config';
				$self->{config}{appletconf}{$appletname} = $hashref if (defined($hashref));
			}
			$applet->configure;
			$self->add($applet->widget, $applet->expand, $applet->fill, $applet->end);
			$applet->widget->show_all;
		}
	}
	return 1;
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
	$_[0]->{panel}->show_all;
	return 1;
}

sub move {
	my $self = shift;
	if ($self->position eq 'top') {
		$self->{panel}->move(0, 0);
	} elsif ($self->position eq 'bottom') {
		my $screen_height= $self->screen_height;
		my $panel_height = $self->{panel}->allocation->height;
		$self->{panel}->move(0, ($screen_height - $panel_height));
	} else {
		$self->error("Invalid panel position '".$self->position."'.", sub { $self->shutdown });
	}
	return 1;
}

sub shutdown {
	my $self = shift;
	$self->save_config;
	exit;
}

sub reload {
	my $self = shift;
	$self->{panel}->set_sensitive(0);
	$self->save_config;
	$self->{panel}->destroy;
	undef $self;
	my $panel = PerlPanel->new;
	$panel->init;
	return 1;
}

sub request_string {
	my ($self, $message, $callback, $visible) = @_;

	my $dialog = Gtk2::Dialog->new(
		"$NAME: $message",
		undef,
		[],
		'gtk-cancel'	=> 0,
		'gtk-ok'	=> 1
	);
	$dialog->set_border_width(8);
	$dialog->set_icon($self->icon);
	$dialog->vbox->set_spacing(8);

	my $entry = Gtk2::Entry->new;
	# this is broken at the moment:
	#if ($visible == 1) {
	#	$entry->set_visible(1);
	#}

	my $table = Gtk2::Table->new(2, 2, 0);
	$table->set_col_spacings(8);
	$table->set_row_spacings(8);

	$table->attach_defaults(Gtk2::Image->new_from_stock('gtk-dialog-question', 'dialog'), 0, 1, 0, 2);
	$table->attach_defaults(Gtk2::Label->new($message), 1, 2, 0, 1);
	$table->attach_defaults($entry, 1, 2, 1, 2);

	$dialog->vbox->pack_start($table, 1, 1, 0);

	$dialog->set_default_response(1);
	$entry->set_activates_default(1);
	$dialog->signal_connect(
		'response',
		sub {
			$dialog->destroy;
			if ($_[1] eq 1) {
				# only destroy the window if the callback
				# returns true.
				return unless $callback->($entry->get_text);
				$callback->($entry->get_text);
			}
		}
	);

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
	$dialog->set_title($NAME);
	$dialog->set_border_width(8);
	$dialog->set_icon($self->icon);
	$dialog->vbox->set_spacing(8);

	my $hbox = Gtk2::HBox->new;
	$hbox->set_spacing(8);
	$hbox->pack_start(Gtk2::Image->new_from_stock($stock, 'dialog'), 0, 0, 0);

	my $width = 0;
	map { chomp ; $width = length($_) if length($_) > $width } split(/[\r\n]/, $message);
	if ($width > 50 || scalar(split(/[\r\n]/, $message)) > 10) {
		$dialog->set_default_size(350, 150);
		my $scrwin = Gtk2::ScrolledWindow->new;
		$scrwin->set_policy('automatic', 'automatic');
		$scrwin->add_with_viewport(Gtk2::Label->new($message));
		$hbox->pack_start($scrwin, 1, 1, 0);
	} else {
		$hbox->pack_start(Gtk2::Label->new($message), 1, 1, 0);
	}

	$dialog->vbox->pack_start($hbox, 1, 1, 0);

	$dialog->add_button('gtk-cancel', 0) if ($cancel_callback);
	$dialog->add_button('gtk-ok', 1);
	$dialog->set_default_response(1);
	$dialog->signal_connect(
		'response',
		sub {
			if (1 == $_[1]) {
				$ok_callback->() if $ok_callback;
			} else {
				$cancel_callback->() if $cancel_callback;
			}
			$dialog->destroy;
		}
	);

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

sub icon {
	return $_[0]->{icon};
}

sub icon_size {
	return @{$SIZE_MAP{$_[0]->{config}{panel}{size}}}[0];
}

sub icon_size_name {
	return @{$SIZE_MAP{$_[0]->{config}{panel}{size}}}[1];
}

sub screen_width {
	my $self = shift;
	return (defined($self->{screen}) ? $self->{screen}->get_width : $self->{screen_width});
}

sub screen_height {
	my $self = shift;
	return (defined($self->{screen}) ? $self->{screen}->get_height : $self->{screen_height});
}

sub position {
	my $self = shift;
	return $self->{config}{panel}{position};
}

1;
