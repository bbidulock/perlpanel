# $Id: PerlPanel.pm,v 1.103 2004/08/26 14:58:34 jodrell Exp $
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
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel;

use Gtk2;
use Gtk2::Helper;
use Gtk2::GladeXML;
use Gtk2::SimpleList;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use POSIX qw(setlocale);
use Locale::gettext;
use base 'Exporter';
use File::Basename qw(basename fileparse);
use vars qw(	$NAME		$VERSION	$DESCRIPTION	$VERSION	@LEAD_AUTHORS
		@CO_AUTHORS	$URL		$LICENSE	$PREFIX		$LIBDIR
		%DEFAULTS	%SIZE_MAP	$TOOLTIP_REF	$OBJECT_REF	$APPLET_ICON_DIR
		$APPLET_ICON_SIZE		@APPLET_DIRS	$PIDFILE	$RUN_COMMAND_FILE
		$RUN_HISTORY_FILE		$RUN_HISTORY_LENGTH		@APPLET_CATEGORIES
		$DEFAULT_THEME	$APPLET_ERROR_MARKUP		$DESKTOP_NAMESPACE
		$DEFAULT_RCFILE);
use strict;

our @EXPORT_OK = qw(_); # this exports the _() function, for il8n.

our $NAME		= 'PerlPanel';
our $VERSION		= '@VERSION@'; # this is replaced at build time.
our @LEAD_AUTHORS	= (
	'Gavin Brown',
);
our @CO_AUTHORS		= (
	'Eric Andreychek',
	'Scott Arrington',
	'Torsten Schoenfeld',
	'Marc Brockschmidt',
	'Mark Ng',
	'Nathan Powell',
);
our $URL		= 'http://jodrell.net/projects/perlpanel';

our %DEFAULTS = (
	version	=> $VERSION,
	panel => {
		position		=> 'bottom',
		spacing			=> 0,
		size			=> 'medium',
		has_border		=> 'false',
		menu_size_as_panel	=> 'true',
		menu_size		=> 'medium',
	},
	appletconf => {
		null => {},
	},
	multi => {
		null => {},
	},
	applets => [
		'ActionMenu',
		'Tasklist',
		'Clock',
		'Pager',
	],
);

our %SIZE_MAP = (
	tiny	=> ['16', 'menu'],
	small	=> ['18', 'small-toolbar'],
	medium	=> ['24', 'large-toolbar'],
	large	=> ['48', 'dialog'],
);

our $APPLET_ICON_SIZE = 48;

our $RUN_COMMAND_FILE	= sprintf('%s/.%s/run-command', $ENV{HOME}, lc($NAME));
our $PIDFILE		= sprintf('%s/.%s/%s.pid', $ENV{HOME}, lc($NAME), lc($NAME));
our $RUN_HISTORY_FILE	= sprintf('%s/.perlpanel/run-history', $ENV{HOME});
our $RUN_HISTORY_LENGTH	= 15;

our @APPLET_CATEGORIES = qw(Actions System Utilities Launchers Menus);

our $DEFAULT_THEME = 'gnome';

our $APPLET_ERROR_MARKUP = <<"END";
<span weight="bold">%s</span>
END

our $DESKTOP_NAMESPACE	= 'Desktop Entry';

Gtk2->init;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{rcfile}		= (defined($ARGV[0]) ? $ARGV[0] : sprintf('%s/.%src', $ENV{HOME}, lc($NAME)));
	$OBJECT_REF		= $self;
	bless($self, $self->{package});
	our $APPLET_ICON_DIR	= sprintf('%s/share/pixmaps/%s/applets', $PREFIX, lc($NAME));
	our $DEFAULT_RCFILE	= sprintf('%s/etc/%src', $PREFIX, lc($NAME));
	our @APPLET_DIRS	= (
		sprintf('%s/.%s/applets',	$ENV{HOME}, lc($NAME)),	# user-installed applets
		sprintf('%s/%s/Applet',		$LIBDIR, $NAME),	# admin-installed or sandbox applets ($LIBDIR is
	);								# determined at runtime)

	# stuff for ill8n - this has to be done before any strings are used:
	setlocale(LC_ALL, $ENV{LANG});
	bindtextdomain(lc($NAME), sprintf('%s/share/locale', $PREFIX));
	textdomain(lc($NAME));

	our $DESCRIPTION	= _('The Lean, Mean, Panel Machine!');
	our $LICENSE		= _('This program is Free Software. You may use it under the terms of the GNU General Public License.');

	return $self;
}

sub init {
	my $self = shift;
	$self->check_deps;
	$self->load_config;
	$self->get_screen || $self->parse_xdpyinfo;
	$self->load_icon_theme;
	$self->build_panel;
	$self->configure;
	$self->load_applets;
	$self->show_all;

	if ($self->{config}{panel}{autohide} eq 'true') {
		$self->autohide;
	} else {
		$self->move;
	}

	# if/when gtk2-perl gets bonobo support, we can register
	# the panel here with:
	#
	#	/* Strip off the screen portion of the display */
	#	display = g_strdup (g_getenv ("DISPLAY"));
	#	p = strrchr (display, ':');
	#	if (p) {
	#		p = strchr (p, '.');
	#		if (p)
	#			p [0] = '\0';
	#	}
	#
	#	iid = bonobo_activation_make_registration_id ("OAFIID:GNOME_PanelShell", display);
	#	reg_res = bonobo_activation_active_server_register (iid, BONOBO_OBJREF (panel_shell));
	#
	# which I copied from gnome-panel/panel-shell.c. This will make PerlPanel act as a "real"
	# GNOME panel.

	chdir($ENV{HOME});

	require('Commander.pm');
	$self->{commander} = PerlPanel::Applet::Commander->new;
	$self->{commander}->configure('no-widget');
	Glib::Timeout->add(50, sub {
		if (-e $RUN_COMMAND_FILE) {
			unlink($RUN_COMMAND_FILE);
			$self->{commander}->run;
		}
		return 1;
	});

	if (open(PIDFILE, ">$PIDFILE")) {
		print PIDFILE $$;
		close(PIDFILE);
	}

	my $sub = sub {
		my $error = shift;
		print STDERR $error unless ($error =~ /^[A-Z]{3,4}$/);
		unlink($PIDFILE);
		exit;
	};
	foreach my $signal (qw(ABRT ALRM HUP INT KILL QUIT SEGV STOP TERM __DIE__)) {
		$SIG{$signal} = $sub;
	}

	Gtk2->main;

	unlink($PIDFILE);

	return 1;
}

sub check_deps {
	my $self = shift;
	$@ = '';
	eval 'use XML::Simple;';
	if ($@ ne '') {
		$self->error(_("Couldn't load the {module} module!", module => 'XML::Simple'), sub { exit });
		Gtk2->main;
	} else {
		$XML::Simple::PREFERRED_PARSER = 'XML::Parser';
		return 1;
	}
}

sub get_screen {
	my $self = shift;
	my $code = '$self->{screen} = Gtk2::Gdk::Screen->get_default';
	return eval($code);
}

sub parse_xdpyinfo {
	my $self = shift;
	print STDERR "*** using xdpyinfo to get screen dimenions, upgrading to gtk+ > 2.2.0 is recommended!\n";
	chomp($self->{xdpyinfo} = `which xdpyinfo`);
	open(XDPYINFO, "$self->{xdpyinfo} -display $ENV{DISPLAY} |") or $self->error(_("Can't open pipe from {prog}: {error}", prog => $self->{xdpyinfo}, error => $!), sub { exit });
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
	if (-r $self->{rcfile}) {
		$self->{config} = XMLin($self->{rcfile});
	} elsif (-r $DEFAULT_RCFILE) {
		$self->{config} = XMLin($DEFAULT_RCFILE);
	} else {
		$self->{config} = \%DEFAULTS;
	}
	if ($self->{config}{version} ne $VERSION) {
		print STDERR "*** your config file is from a different version, strange things may happen!\n";
	}
	return 1;
}

sub save_config {
	my $self = shift || $OBJECT_REF;
	$self->{config}{version} = $VERSION;
	open(RCFILE, ">$self->{rcfile}") or print STDERR "Error writing to '$self->{rcfile}': $!\n" and exit 1;
	print RCFILE XMLout($self->{config});
	close(RCFILE);
	return 1;
}

sub load_icon_theme {
	my $self = shift;
	$self->{icon_theme} = Gtk2::IconTheme->new;

	my $theme = $self->{config}->{panel}->{icon_theme} ne '' ?
		$self->{config}->{panel}->{icon_theme} : $DEFAULT_THEME;

	$self->{icon_theme}->set_custom_theme($theme);

	if ($VERSION !~ /^[\d\.]$/) {
		# we're in sandbox mode
		$self->{icon_theme}->prepend_search_path(sprintf('%s/share/icons', $PREFIX));
	}
	$self->{icon_theme}->prepend_search_path(sprintf('%s/.%s/icon-files/', $ENV{HOME}, lc($NAME)));

	return 1;
}

sub build_panel {
	my $self = shift;

	$self->{tips} = Gtk2::Tooltips->new;
	our $TOOLTIP_REF = $self->{tips};

	$self->{icon} = Gtk2::Gdk::Pixbuf->new_from_file(PerlPanel::lookup_icon('perlpanel'));

	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_border_width(0);

	$self->{panel} = Gtk2::Window->new;

	$self->{vbox} = Gtk2::VBox->new;
	$self->{vbox}->set_border_width(0);
	$self->{vbox}->set_spacing(0);
	$self->{separator} = Gtk2::HSeparator->new;
	$self->{separator}->set_size_request(-1, 1);

	$self->{panel}->add($self->{vbox});

	$self->arrange_border;
	return 1;
}

sub arrange_border {
	my $self = shift;
	if ($self->position eq 'top') {
		$self->{vbox}->pack_start($self->{hbox},	1, 1, 0);
		$self->{vbox}->pack_start($self->{separator},	0, 0, 0);
	} else {
		$self->{vbox}->pack_start($self->{separator},	0, 0, 0);
		$self->{vbox}->pack_start($self->{hbox},	1, 1, 0);
	}
	return 1;
}

sub configure {
	my $self = shift;

	$self->panel->set_default_size($self->screen_width, 0);
	$self->panel->set_border_width(0);

	# check is_visible for reloads:
	my $gdk_window = $self->panel->window;
	if (!defined($gdk_window) || !$gdk_window->is_visible) {
		$self->panel->set_type_hint('dock');
	}

	$self->panel->set_decorated(0); # needed for some window managers
	$self->panel->stick; # needed for some window managers
	$self->panel->set_keep_above(1);

	$self->{hbox}->set_spacing($self->{config}{panel}{spacing});
	$self->{hbox}->set_border_width(0);

	if ($self->{config}{panel}{autohide} eq 'true') {
		$self->{leave_connect_id} = $self->panel->signal_connect('leave_notify_event', sub { $self->autohide; });
		$self->{enter_connect_id} = $self->panel->signal_connect('enter_notify_event', sub { $self->autoshow; });
	}

	push(@INC, @APPLET_DIRS);

	return 1;
}

sub load_applets {
	my $self = shift;

	# this is some munging for when the config gets confused when being serialized to/from XML:
	if (ref($self->{config}{applets}) ne 'ARRAY') {
		$self->{config}{applets} = [ $self->{config}{applets} ];
	}

	for (my $i = 0 ; $i < scalar(@{$self->{config}{applets}}) ; $i++) {

		my $appletname = @{$self->{config}{applets}}[$i];

		my ($appletname, $id) = split(/::/, $appletname, 2);

		my ($applet, $expr, $multi);

		eval(sprintf('require "%s.pm"', ucfirst($appletname)));

		eval(sprintf('$multi = $%s::Applet::%s::MULTI', $self->{package}, ucfirst($appletname)));

		if (defined($multi) && $id eq '') {
			$id = $self->new_applet_id;
			 @{$self->{config}{applets}}[$i] = sprintf('%s::%s', $appletname, $id);
		}

		if ($id ne '') {
			$expr = sprintf(
				'$applet = %s::Applet::%s->new("%s")',
				$self->{package},
				ucfirst($appletname),
				$id,
			);
		} else {
			$expr = sprintf(
				'$applet = %s::Applet::%s->new',
				$self->{package},
				ucfirst($appletname),
			);
		}

		eval($expr);

		if ($@ || !defined($applet)) {
			my $message = _("Error loading {applet} applet.\n", applet => $appletname);
			my $toplevel = (split(/::/, $appletname))[0];
			if ($@ =~ /can\'t locate $toplevel/i) {
				$message = _("Error: couldn't find applet file {file}.pm.", file => $appletname);
			}

			my $glade = $self->load_glade('applet-error');
			$glade->get_widget('error_label')->set_markup(sprintf($APPLET_ERROR_MARKUP, $message));
			$glade->get_widget('error_text')->get_buffer->set_text($@);
			$glade->get_widget('error_dialog')->signal_connect('response', sub {
				$_[0]->destroy;
				require('Configurator.pm');
				my $configurator = PerlPanel::Applet::Configurator->new;
				$configurator->configure;
				$configurator->init;
				$configurator->app->get_widget('notebook')->set_current_page(3);
			});
			$glade->get_widget('error_dialog')->set_position('center');
			$glade->get_widget('error_dialog')->set_icon($self->icon);
			$glade->get_widget('error_dialog')->show_all;

		} else {

			if ($id ne '') {
				if (!defined($self->{config}->{multi}->{sprintf('%s::%s', $appletname, $id)})) {
					my $hashref;
					eval {
						$hashref = $applet->get_default_config;
					};
					$self->{config}->{multi}->{sprintf('%s::%s', $appletname, $id)} = $hashref if (defined($hashref));
				}
			} else {
				if (!defined($self->{config}->{appletconf}->{$appletname})) {
					my $hashref;
					eval {
						$hashref = $applet->get_default_config;
					};
					$self->{config}->{appletconf}->{$appletname} = $hashref if (defined($hashref));
				}
			}

			my $widget;
			eval {
				$applet->configure;
				$widget = $applet->widget;
			};
			if ($@ || !defined($widget)) {
				print STDERR "Error configuring '$appletname' applet: $@\n";

			} else {
				$self->add($applet->widget, $applet->expand, $applet->fill);
				$applet->widget->show_all;

			}
		}
	}

	return 1;
}

sub add {
	my ($self, $widget, $expand, $fill) = @_;
	$self->{hbox}->pack_start($widget, $expand, $fill, 0);
	return 1;
}

sub show_all {
	my $self = shift;

	$self->panel->show_all;

	return 1;
}

sub move {
	my $self = shift;
	my $panel_height = $self->panel->allocation->height;

	if ($self->position eq 'top') {
		$self->panel->move(0, 0);

	} elsif ($self->position eq 'bottom') {
		my $screen_height= $self->screen_height;
		$self->panel->move(0, ($screen_height - $panel_height));

	} else {
		$self->error(_("Invalid panel position '{position}'.", position => $self->position), sub { $self->shutdown });
	}

	my ($top, $bottom);
	if ($PerlPanel::OBJECT_REF->{config}{panel}{autohide} eq 'true') {
		($top, $bottom) = (0, 0);
	} else {
		($top, $bottom) = ($self->position eq 'top' ? ($panel_height, 0) : (0, $panel_height));
	}

	$self->panel->window->property_change(
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
	$OBJECT_REF->save_config;
	unlink($PIDFILE);
	exit;
}

sub reload {
	my $self = $OBJECT_REF;
	$self->panel->set_sensitive(0);
	$self->save_config;
	foreach my $applet ($self->{hbox}->get_children) {
		$applet->destroy;
	}
	$self->{vbox}->remove($self->{hbox});
	$self->{vbox}->remove($self->{separator});
	$self->load_icon_theme;
	$self->arrange_border;
	$self->load_applets;
	$self->configure;
	$self->move;
	$self->panel->set_sensitive(1);
	return 1;
}

sub request_string {
	my ($self, $message, $callback, $visible);
	$self = $OBJECT_REF;
	($message, $callback, $visible) = @_;

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
	my ($self, $message, $callback);
	$self = $OBJECT_REF;
	($message, $callback) = @_;
	$self->request_string($message, $callback, 1);
}

# you shouldn't need to access this directly -
# instead use one of the wrappers below:
sub alert {
	my ($self, $message, $ok_callback, $cancel_callback, $type);
	$self = $OBJECT_REF;
	($message, $ok_callback, $cancel_callback, $type) = @_;

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
			} elsif ($_[1] eq 'ok') {
				$ok_callback->() if $ok_callback;
			}
			$dialog->destroy;
		}
	);

	$dialog->show_all;

	return 1;
}

sub question {
	my ($self, $message, $ok_callback, $cancel_callback);
	$self = $OBJECT_REF;
	($message, $ok_callback, $cancel_callback) = @_;
	return alert($message, $ok_callback, $cancel_callback, 'question');
}

sub error {
	my ($self, $message, $ok_callback);
	$self = $OBJECT_REF;
	($message, $ok_callback) = @_;
	return alert($message, (defined($ok_callback) ? $ok_callback : sub { $self->shutdown} ), undef, 'error');
}

sub warning {
	my ($self, $message, $ok_callback);
	$self = $OBJECT_REF;
	($message, $ok_callback) = @_;
	return alert($message, $ok_callback, undef, 'warning');
}

sub notify {
	my ($self, $message, $ok_callback);
	$self = $OBJECT_REF;
	($message, $ok_callback) = @_;
	return alert($message, $ok_callback, undef, 'info');
}

sub tips {
	return $OBJECT_REF->{tips};
}

sub panel {
	return $OBJECT_REF->{panel};
}

sub icon {
	return $OBJECT_REF->{icon};
}

sub icon_size {
	return @{$SIZE_MAP{$OBJECT_REF->{config}{panel}{size}}}[0];
}

sub icon_size_name {
	return @{$SIZE_MAP{$OBJECT_REF->{config}{panel}{size}}}[1];
}

#
# These do the same as the two subs above, but may do something else in the future:
#
sub menu_icon_size {
	my $self = $OBJECT_REF;
	if ($self->{config}{panel}->{menu_size_as_panel} ne 'false') {
		return $self->icon_size;
	} else {
		return @{$SIZE_MAP{$self->{config}{panel}->{menu_size}}}[0];
	}
}
sub menu_icon_size_name {
	my $self = $OBJECT_REF;
	if ($self->{config}{panel}->{menu_size_as_panel} ne 'false') {
		return $self->icon_size_name;
	} else {
		return @{$SIZE_MAP{$self->{config}{panel}->{menu_size}}}[1];
	}
}

sub screen_width {
	return (defined($OBJECT_REF->{screen}) ? $OBJECT_REF->{screen}->get_width : $OBJECT_REF->{screen_width});
}

sub screen_height {
	return (defined($OBJECT_REF->{screen}) ? $OBJECT_REF->{screen}->get_height : $OBJECT_REF->{screen_height});
}

sub position {
	return $OBJECT_REF->{config}{panel}{position};
}

sub autohide {
	my $self = shift;
	if ($self->position eq 'top') {
		$self->panel->move(0, 0 - $self->panel->allocation->height + 2);
	} elsif ($self->position eq 'bottom') {
		$self->panel->move(0, $self->screen_height - 2);
	} else {
		$self->error(_("Invalid panel position '{position}'.", position => $self->position), sub { $self->shutdown });
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
#   |				       |
#   | Screen			       |
#   |				       |
#   |   +-------------------------+    |
#   |   |			  |    |
#   |   | Window		  |    |
#   |   |			  |    |
#   |   |  +--------+	          |    |
#   |   |  | Widget |	          |    |
#   |   |  +--------+	          |    |
#   |   |	      + - pointer |    |
#   |   |			  |    |
#   |   +-------------------------+    |
#   |				       |
#   |				       |
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
	my ($self, $widget);
	$self = $OBJECT_REF;
	$widget = shift;

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
	my (undef, $x, $y, undef) = $OBJECT_REF->panel->get_root_window->get_pointer;
	return ($x, $y);
}

sub exec_wait {
	my ($self, $command, $callback);
	$self = $OBJECT_REF;
	($command, $callback) = @_;

	open(COMMAND, "$command|");
	my $tag;
	$tag = Gtk2::Helper->add_watch(fileno(COMMAND), 'in', sub {
		if (eof(COMMAND)) {
			close(COMMAND);
			Gtk2::Helper->remove_watch($tag);
			if (defined($callback)) {
				&$callback();
			}
		}
	});
	return 1;
}

sub has_application_menu {
	return PerlPanel::has_applet('BBMenu');
	return undef;
}

sub has_action_menu {
	return PerlPanel::has_applet('ActionMenu');
}

sub has_pager {
	return PerlPanel::has_applet('Pager');
}

sub has_applet {
	my ($self, $applet);
	$self = $OBJECT_REF;
	$applet = shift;
	foreach my $appletname (@{$self->{config}{applets}}) {
		return 1 if ($appletname eq $applet);
	}
	return undef;
}

# this is just a stub, should we ever implement icon themes this will become
# more useful:
sub get_applet_pbf_filename {
	my ($self, $applet);
	$self = $OBJECT_REF;
	$applet = shift;
	return lookup_icon(sprintf('%s-applet-%s', lc($NAME), lc($applet)));
}

sub get_applet_pbf {
	my ($self, $applet, $size);
	$self = $OBJECT_REF;
	($applet, $size) = @_;

	$size = ($size > 0 ? $size : $APPLET_ICON_SIZE);

	if (!defined($self->{pbfs}{$applet}{$size})) {
		my $file = get_applet_pbf_filename($applet);
		if (-e $file) {
			$self->{pbfs}{$applet}{$size} = Gtk2::Gdk::Pixbuf->new_from_file($file);
			if ($self->{pbfs}{$applet}{$size}->get_height != $size) {
				$self->{pbfs}{$applet}{$size} = $self->{pbfs}{$applet}{$size}->scale_simple($size, $size, 'bilinear');
			}
		} else {
			$self->{pbfs}{$applet}{$size} = get_applet_pbf('missing', $size);
		}
	}
	return $self->{pbfs}{$applet}{$size};
}

sub get_config {
	my ($self, $applet, $id);
	$self = $OBJECT_REF;
	($applet, $id) = @_;
	if (defined($id)) {
		return $self->{config}->{multi}->{sprintf('%s::%s', $applet, $id)};
	} else {
		return $self->{config}->{appletconf}->{$applet};
	}
}

sub spacing {
	return $OBJECT_REF->{config}{panel}{spacing};
}

sub load_glade {
	my $gladefile = shift;
	my $file = sprintf('%s/share/%s/glade/%s.glade', $PREFIX, lc($NAME), $gladefile);

	return Gtk2::GladeXML->new($file);
}

sub _ {
	my $str = shift;
	my %params = @_;
	my $translated = gettext($str);
	if (scalar(keys(%params)) > 0) {
		foreach my $key (keys %params) {
			$translated =~ s/\{$key\}/$params{$key}/g;
		}
	}
	return $translated;
}

sub lookup_icon {

	my ($self, $icon);
	$self = $OBJECT_REF;
	$icon = shift;

	if (defined($self->{icon_theme})) {
		$self->{icon_theme}->rescan_if_needed;
	} else {
		PerlPanel::load_icon_theme($self);
	}

	if ($icon eq '') {
		return undef;

	} elsif (-f $icon) {
		return $icon;

	} else {
		# remove everything after the last dot:
		$icon = basename($icon);
		$icon =~ s/\..+$//g;

		my $info = $self->{icon_theme}->lookup_icon(lc($icon), 48, 'force-svg');

		if (!defined($info)) {
			return undef;

		} else {
			return $info->get_filename;

		}
	}
}

sub get_run_history {
	my @history;
	if (!open(HISTFILE, $RUN_HISTORY_FILE)) {
		print STDERR "*** error opening $RUN_HISTORY_FILE for reading: $!\n";
	} else {
		@history = reverse(<HISTFILE>);
		map { chomp($history[$_]) } 0..scalar(@history);
		close(HISTFILE);
	}
	@history = grep { $_ ne '' } uniq(@history);
	return splice(@history, 0, $RUN_HISTORY_LENGTH);
}

sub uniq {
	my @array = @_;
	my @new;
	my %map;
	foreach my $member (@array) {
		$map{$member}++;
	}
	foreach my $member (@array) {
		if ($map{$member} > 0) {
			push(@new, $member);
			$map{$member} = 0;
		}
	}
	return @new;
}

sub append_run_history {
	my ($self, $command);
	$self = $OBJECT_REF;
	$command = shift;
	if (!open(HISTFILE, ">>$RUN_HISTORY_FILE")) {
		print STDERR "*** error opening $RUN_HISTORY_FILE for appending: $!\n";
		return undef;
	} else {
		print HISTFILE "$command\n";
		close(HISTFILE);
		return 1;
	}
}

sub load_appletregistry {
	my $self = shift;
	my $registry = {};
	my @registry_dirs = ( 
		sprintf('%s/share/%s', $PerlPanel::PREFIX, lc($PerlPanel::NAME)),
		sprintf('%s/.%s', $ENV{HOME}, lc($PerlPanel::NAME)),
	);
	foreach my $dir (@registry_dirs) {
		my $file = "$dir/applet.registry";
		next unless -r $file;
		open(REGFILE, $file);
		while (<REGFILE>) {
			chomp;
			s/^\s*//g;
			s/\s*$//g;
			next if (/^$/ or /^#/);
			my ($applet, $description, $category) = split(/:/, $_, 3);
			$registry->{$applet} = _($description);
			push(@{$registry->{_categories}->{$category}}, $applet);
		}
		close(REGFILE);
	}
	return $registry;
}

sub new_applet_id {
	return md5_hex(join('|', $ENV{HOSTNAME}, lc((getpwuid($<))[0]), time(), $0, int(rand(99999))));
}

sub parse_desktopfile {
	my $data = shift;
	my ($name, $comment, $icon, $program);
	my $namespace;
	my $params = {};
	foreach my $line (split(/\n/, $data)) {
		my ($name, $value) = split(/=/, $line, 2);
		if ($name =~ /^\[($DESKTOP_NAMESPACE)\]/i) {
			$namespace = $1;
		} elsif ($namespace ne '') {
			$params->{$namespace}->{$name} = $value;
		} else {
			$params->{orphans}->{$name} = $value;
		}
	}

	my $language = $ENV{LANG} || 'en_US';
	$language =~ s/\..*$//g;

	$name    = ($params->{$DESKTOP_NAMESPACE}{"Name[$language]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Name[$language]"} : $params->{$DESKTOP_NAMESPACE}{Name});
	$comment = ($params->{$DESKTOP_NAMESPACE}{"Comment[$language]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Comment[$language]"} : $params->{$DESKTOP_NAMESPACE}{Comment});
	$program = $params->{$DESKTOP_NAMESPACE}{Exec};

	if (-e $params->{$DESKTOP_NAMESPACE}{Icon}) {
		$icon = $params->{$DESKTOP_NAMESPACE}{Icon};
	} else {
		$icon = lookup_icon($params->{$DESKTOP_NAMESPACE}{Icon});
		if (! -e $icon) {
			if (-e "/usr/share/pixmaps/$params->{$DESKTOP_NAMESPACE}{Icon}") {
				$icon = lookup_icon($params->{$DESKTOP_NAMESPACE}{Icon});
			}
		}
	}

	return ($name, $comment, $icon, $program);
}

1;
