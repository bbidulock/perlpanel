# $Id: PerlPanel.pm,v 1.17 2003/06/13 15:43:33 jodrell Exp $
package PerlPanel;
use Time::HiRes qw(time);
use Gtk2;
use Data::Dumper;
use vars qw($NAME $VERSION $DESCRIPTION $VERSION @AUTHORS $URL $LICENSE $PREFIX %DEFAULTS %SIZE_MAP $TOOLTIP_REF $OBJECT_REF);
use strict;

our $NAME		= 'PerlPanel';
our $VERSION		= '0.0.3';
our $DESCRIPTION	= 'A lean, mean panel program written in Perl.';
our @AUTHORS		= (
	'Gavin Brown &lt;gavin.brown@uk.com&gt;',
);
our $URL		= 'http://jodrell.net/projects/perlpanel';
our $LICENSE		= "This program is Free Software. You may use it\nunder the terms of the GNU General Public License.";

chomp(our $PREFIX = `gtk-config --prefix`);

our %DEFAULTS = (
	version	=> $VERSION,
	screen => {
		width => 1024,
		height => 768,
	},
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
		'Reload',
		'About',
		'Quit',
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
	my $self = shift;
	$self->check_deps;
	$self->load_config;
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
	$self->{panel}->set_default_size($self->{config}{screen}{width}, $self->icon_size);
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
	$_[0]->{panel}->show_all();
	return 1;
}

sub move {
	my $self = shift;
	if ($self->{config}{panel}{position} eq 'top') {
		$self->{panel}->move(0, 0);
	} elsif ($self->{config}{panel}{position} eq 'bottom') {
		$self->{panel}->move(0, ($self->{config}{screen}{height} - $self->{panel}->allocation->height));
	} else {
		$self->error("Invalid panel position '$self->{config}{panel}{position}'.", sub { $self->shutdown });
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

	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title("$NAME: $message");
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
	$dialog->set_title($NAME);
	$dialog->set_border_width(8);
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

	# only display if $cancel_callback is defined:
	if (defined($cancel_callback)) {
		my $cancel_button = Gtk2::Button->new_from_stock('gtk-cancel');
		$cancel_button->signal_connect('clicked', sub { $dialog->destroy, &$cancel_callback() });
		$dialog->action_area->pack_start($cancel_button, 0, 1, 0);
	}

	my $ok_button = Gtk2::Button->new_from_stock('gtk-ok');

	if (defined($ok_callback)) {
		$ok_button->signal_connect('clicked', sub { $dialog->destroy ; &$ok_callback() });
	} else {
		$ok_button->signal_connect('clicked', sub { $dialog->destroy });
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

sub icon_size {
	return @{$SIZE_MAP{$_[0]->{config}{panel}{size}}}[0];
}

sub icon_size_name {
	return @{$SIZE_MAP{$_[0]->{config}{panel}{size}}}[1];
}

1;
