# $Id: PerlPanel.pm,v 1.29 2003/08/13 13:47:42 jodrell Exp $
# This file is part of PerlPanel.
# 
# PerlPanel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PerlPanel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PerlPanel; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package PerlPanel;
use Gtk2;
use Data::Dumper;
use vars qw($NAME $VERSION $DESCRIPTION $VERSION @LEAD_AUTHORS @CO_AUTHORS $URL $LICENSE $PREFIX %DEFAULTS %SIZE_MAP $TOOLTIP_REF $OBJECT_REF);
use strict;

our $NAME		= 'PerlPanel';
our $VERSION		= '0.1.0';
our $DESCRIPTION	= 'A lean, mean panel program written in Perl.';
our @LEAD_AUTHORS	= (
	'Gavin Brown <gavin.brown@uk.com>',
);
our @CO_AUTHORS		= (
	'Eric Andreychek <eric@openthought.net>',
	'Scott Arrington <muppet@asofyet.org>',
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
	$self->configure;
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
		$XML::Simple::PREFERRED_PARSER = 'XML::Parser';
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
	$self->{hbox} = Gtk2::HBox->new;
	$self->{port} = Gtk2::Viewport->new;
	$self->{port}->add($self->{hbox});
	$self->{panel}->add($self->{port});
	$self->{icon} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/pixmaps/%s-menu-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)));
	return 1;
}

sub configure {
	my $self = shift;
	$self->{panel}->set_default_size($self->screen_width, 0);
	$self->{hbox}->set_spacing($self->{config}{panel}{spacing});
	$self->{port}->set_shadow_type('out');
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
	foreach my $applet ($self->{hbox}->get_children) {
		$applet->destroy;
	}
	$self->load_applets;
	$self->configure;
	$self->move;
	$self->{panel}->set_sensitive(1);
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
	if ($visible == 1) {
		$entry->set_visibility(0);
	}

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
	my ($self, $message, $ok_callback, $cancel_callback, $type) = @_;

	my $buttons = 'ok';
	if (defined($ok_callback) && defined($cancel_callback)) {
		$buttons = 'ok-cancel';
	}

	my $dialog = Gtk2::MessageDialog->new($self->{window}, 'modal', $type, $buttons, $message);
	$dialog->set_title($NAME);
	$dialog->set_icon($self->icon);

	$dialog->signal_connect(
		'response',
		sub {
			if ($_[1] == -5) {
				$ok_callback->() if $ok_callback;
			} else {
				$cancel_callback->() if $cancel_callback;
			}
			$dialog->destroy;
		}
	);

	$dialog->run;

	return 1;
}

sub question {
	my ($self, $message, $ok_callback, $cancel_callback) = @_;
	return $self->alert($message, $ok_callback, $cancel_callback, 'question');
}

sub error {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'error');
}

sub warning {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'warning');
}

sub notify {
	my ($self, $message, $ok_callback) = @_;
	return $self->alert($message, $ok_callback, undef, 'info');
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
