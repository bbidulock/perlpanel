# $Id: PerlPanel.pm,v 1.45 2004/01/17 00:56:19 jodrell Exp $
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
our $VERSION		= '@VERSION@'; # this is replaced at build time.
our $DESCRIPTION	= 'A lean, mean panel program written in Perl.';
our @LEAD_AUTHORS	= (
	'Gavin Brown <gavin.brown@uk.com>',
);
our @CO_AUTHORS		= (
	'Eric Andreychek <eric@openthought.net> (Applet development)',
	'Scott Arrington <muppet@asofyet.org> (Bug fixes)',
	'Torsten Schoenfeld <kaffeetisch@web.de> (libwnck libraries)',
);

our $URL		= 'http://jodrell.net/projects/perlpanel';
our $LICENSE		= "This program is Free Software. You may use it\nunder the terms of the GNU General Public License.";

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
		'Tasklist',
		'Clock',
		'Configurator',
		'Commander',
		'Pager',
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
	$self->{rcfile}		= (defined($ARGV[0]) ? $ARGV[0] : sprintf('%s/.%src', $ENV{HOME}, lc($NAME)));
	$OBJECT_REF		= $self;
	bless($self, $self->{package});
	return $self;
}

sub init {
	chdir($ENV{HOME});
	my $self = shift;
	$self->{normal_cursor}	= Gtk2::Gdk::Cursor->new('left_ptr');
	$self->{busy_cursor}	= Gtk2::Gdk::Cursor->new('watch');
	$self->check_deps;
	$self->load_config;
	$self->get_screen || $self->parse_xdpyinfo;
	$self->build_ui;
	$self->configure;
	push(@INC, sprintf('%s/lib/%s/%s/Applet', $PREFIX, lc($NAME), $NAME), sprintf('%s/.%s/applets', $ENV{HOME}, lc($NAME)));
	$self->load_applets;
	$self->{panel}->get_root_window->set_cursor($self->{normal_cursor});
	$self->show_all;
	if ($self->{config}{panel}{autohide} eq 'true') {
		$self->autohide;
	} else {
		$self->move;
	}
	Gtk2->main;
	return 1;
}

sub check_deps {
	my $self = shift;
	eval 'use XML::Simple;';
	if ($@) {
		$self->error("Couldn't load the XML::Simple module!", sub { exit });
		Gtk2->main;
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
		print STDERR "Warning: Your config file is from an earlier version, strange things may happen!\n";
	#	$self->error("Your config file is from an earlier\nversion ($self->{config}{version}). Please delete it and\nrestart $NAME.", sub { exit });
	#	Gtk2->main;
	#	return undef;
	}
	return 1;
}

sub save_config {
	my $self = shift;
	$self->{config}{version} = $VERSION;
	open(RCFILE, ">$self->{rcfile}") or print STDERR "Error writing to '$self->{rcfile}': $!\n" and exit 1;
	print RCFILE XMLout($self->{config});
	close(RCFILE);
	return 1;
}

sub build_ui {
	my $self = shift;
	$self->{tooltips} = Gtk2::Tooltips->new;
	our $TOOLTIP_REF = $self->{tooltips};
	$self->{panel} = Gtk2::Window->new;

	$self->{panel}->get_root_window->set_cursor($self->{busy_cursor});

	$self->{panel}->set_type_hint('dock');
	$self->{panel}->stick; # needed for some window managers

	$self->{hbox} = Gtk2::HBox->new;
	$self->{port} = Gtk2::Viewport->new;
	$self->{port}->add($self->{hbox});
	$self->{panel}->add($self->{port});
	$self->{icon} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/pixmaps/%s-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)));

	return 1;
}

sub configure {
	my $self = shift;
	$self->{panel}->set_default_size($self->screen_width, 0);
	$self->{hbox}->set_spacing($self->{config}{panel}{spacing});
	$self->{hbox}->set_border_width(0);
	$self->{port}->set_shadow_type('out');
	if ($self->{config}{panel}{autohide} eq 'true') {
		$self->{leave_connect_id} = $self->{panel}->signal_connect('leave_notify_event', sub { $self->autohide; });
		$self->{enter_connect_id} = $self->{panel}->signal_connect('enter_notify_event', sub { $self->autoshow; });
	}
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
			my $toplevel = (split(/::/, $appletname))[0];
			if ($@ =~ /can't locate $toplevel/i) {
				$message = "Error: couldn't find applet file $appletname.pm in\n\n\t".join("\n\t", @INC);
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
	my $self = shift;

	$self->{panel}->show_all;

	return 1;
}

sub move {
	my $self = shift;
	my $panel_height = $self->{panel}->allocation->height;
	if ($self->position eq 'top') {
		$self->{panel}->move(0, 0);
	} elsif ($self->position eq 'bottom') {
		my $screen_height= $self->screen_height;
		$self->{panel}->move(0, ($screen_height - $panel_height));
	} else {
		$self->error("Invalid panel position '".$self->position."'.", sub { $self->shutdown });
	}

	my ($top, $bottom) = ($self->position eq 'top' ? ($panel_height, 0) : (0, $panel_height));
	$self->{panel}->window->property_change(
		Gtk2::Gdk::Atom->intern('_NET_WM_STRUT', undef),
		Gtk2::Gdk::Atom->intern('CARDINAL', undef),
		32,
		'replace',
		0,
		0,
		$top,
		$bottom,
	);

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
	$dialog->set_border_width(12);
	$dialog->set_icon($self->icon);
	$dialog->vbox->set_spacing(12);

	my $entry = Gtk2::Entry->new;
	if ($visible == 1) {
		$entry->set_visibility(0);
	}

	my $table = Gtk2::Table->new(2, 2, 0);
	$table->set_col_spacings(12);
	$table->set_row_spacings(12);

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
			if ($_[1] eq 'cancel') {
				$cancel_callback->() if $cancel_callback;
			} else {
				$ok_callback->() if $ok_callback;
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
	return $self->alert($message, (defined($ok_callback) ? $ok_callback : sub { $self->shutdown} ), undef, 'error');
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

sub autohide {
	my $self = shift;
	if ($self->position eq 'top') {
		$self->{panel}->move(0, 0 - $self->{panel}->allocation->height + 2);
	} elsif ($self->position eq 'bottom') {
		$self->{panel}->move(0, $self->screen_height - 2);
	} else {
		$self->error("Invalid panel position '".$self->position."'.", sub { $self->shutdown });
	}
	return 1;
}

sub autoshow {
	$_[0]->move;
}

# kludge alert!
#
# the situation is this:
#
#
#0,0
#   +----------------------------------+
#   |                                  |
#   | Screen                           |
#   |                                  |
#   |   +-------------------------+    |
#   |   |                         |    |
#   |   | Window                  |    |
#   |   |                         |    |
#   |   |  +--------+             |    |
#   |   |  | Widget |             |    |
#   |   |  +--------+             |    |
#   |   |              + - pointer|    |
#   |   |                         |    |
#   |   +-------------------------+    |
#   |                                  |
#   |                                  |
#   +----------------------------------+
#
# - $win_pos_x,$win_pos_y describes the position of the window relative to the screen
#
# - $win_mouse_pos_x,$win_mouse_pos_y describes the position of the pointer relative to the window
#
# - $rel_mouse_pos_x,$rel_mouse_posy describes the position of the pointer relative to the widget
#
# To work out the co-ords of the widget, we simply add screen->window and window->pointer values,
# and subtract the widget->pointer values. Simple, eh? :p

sub get_widget_position {
	my ($self, $widget) = @_;

	my $window = $widget->get_toplevel;

	my ($win_pos_x, $win_pos_y) = $window->get_position;

	my ($win_mouse_pos_x, $win_mouse_pos_y) = $window->get_pointer;

	my ($rel_mouse_pos_x, $rel_mouse_pos_y) = $widget->get_pointer;

	return (
		$win_pos_x + $win_mouse_pos_x - $rel_mouse_pos_x,
		$win_pos_y + $win_mouse_pos_y - $rel_mouse_pos_y,
	);

}

sub get_mouse_pointer_position {
	my $self = shift;
	my (undef, $x, $y, undef) = $self->{panel}->get_root_window->get_pointer;
	return ($x, $y);
}

sub exec_wait {
	my ($self, $command, $callback) = @_;
	open(COMMAND, "$command|");
	my $tag;
	$tag = Gtk2::Helper->add_watch(fileno(COMMAND), 'in', sub {
		if (eof(COMMAND)) {
			close(COMMAND);
			Gtk2::Helper->remove_watch($tag);
			&$callback();
		}
	});
	return 1;
}

1;
