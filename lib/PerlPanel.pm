# $Id: PerlPanel.pm,v 1.73 2004/04/14 13:13:47 jodrell Exp $
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
use Gtk2::GladeXML;
use Gtk2::SimpleList;
use Data::Dumper;
use POSIX qw(setlocale);
use Locale::gettext;
use base 'Exporter';
use vars qw(	$NAME		$VERSION	$DESCRIPTION	$VERSION	@LEAD_AUTHORS
		@CO_AUTHORS	$URL		$LICENSE	$PREFIX		$LIBDIR
		%DEFAULTS	%SIZE_MAP	$TOOLTIP_REF	$OBJECT_REF	$APPLET_ICON_DIR
		$APPLET_ICON_SIZE		@APPLET_DIRS);
use strict;


our @EXPORT_OK = qw(_); # this exports the _() function, for il8n.

our $NAME		= 'PerlPanel';
our $VERSION		= '@VERSION@'; # this is replaced at build time.
our @LEAD_AUTHORS	= (
	'Gavin Brown <gavin.brown@uk.com>',
);
our @CO_AUTHORS		= (
	'Eric Andreychek <eric@openthought.net> (Applet development)',
	'Scott Arrington <muppet@asofyet.org> (Bug fixes)',
	'Torsten Schoenfeld <kaffeetisch@web.de> (libwnck libraries)',
	'Marc Brockschmidt <marc@dch-faq.de> (Debian packages)',
);
our $URL		= 'http://jodrell.net/projects/perlpanel';

our %DEFAULTS = (
	version	=> $VERSION,
	panel => {
		position	=> 'bottom',
		spacing		=> 0,
		size		=> 'medium',
		theme		=> 'default',
		has_border	=> 'false',
	},
	appletconf => {
		null => {},
	},
	applets => [
		'ActionMenu',
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

our $APPLET_ICON_SIZE = 48;

Gtk2->init;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{rcfile}		= (defined($ARGV[0]) ? $ARGV[0] : sprintf('%s/.%src', $ENV{HOME}, lc($NAME)));
	$OBJECT_REF		= $self;
	bless($self, $self->{package});
	our $APPLET_ICON_DIR	= sprintf('%s/share/pixmaps/%s/applets', $PREFIX, lc($NAME));

	our @APPLET_DIRS	= (
		sprintf('%s/.%s/applets',	$ENV{HOME}, lc($NAME)),	# user-installed applets
		sprintf('%s/%s/Applet',		$LIBDIR, $NAME),	# admin-installed or sandbox applets ($LIBDIR is
	);								# determined at runtime)

	# stuff for ill8n - this has to be done before any strings are used:
	setlocale(LC_ALL, $ENV{LANG});
	bindtextdomain(lc($NAME), sprintf('%s/share/locale', $PREFIX));
	textdomain(lc($NAME));

	our $DESCRIPTION	= _('A lean, mean panel program written in Perl.');
	our $LICENSE		= _('This program is Free Software. You may use it under the terms of the GNU General Public License.');

	return $self;
}

sub init {
	my $self = shift;
	$self->check_deps;
	$self->load_config;
	$self->get_screen || $self->parse_xdpyinfo;
	$self->build_ui;
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

	Gtk2->main;

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
	$self->{config} = (-e $self->{rcfile} ? XMLin($self->{rcfile}) : \%DEFAULTS);
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

sub build_ui {
	my $self = shift;

	$self->{tips} = Gtk2::Tooltips->new;
	our $TOOLTIP_REF = $self->{tips};

	$self->{icon} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/pixmaps/%s-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)));

	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_border_width(0);

	$self->{panel} = Gtk2::Window->new;

	if ($self->{config}{panel}{has_border} eq 'true') {
		my $toolbar = Gtk2::Toolbar->new;
		$self->{hbox}->set_size_request(PerlPanel::screen_width(), -1);
		$toolbar->add($self->{hbox});
		$self->panel->add($toolbar);
	} else {
		$self->panel->add($self->{hbox});
	}

	return 1;
}

sub configure {
	my $self = shift;

	$self->panel->set_default_size($self->screen_width, 0);
	$self->panel->set_border_width(0);
	$self->panel->set_type_hint('dock');
	$self->panel->stick; # needed for some window managers

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

	foreach my $appletname (@{$self->{config}{applets}}) {

		my $applet;

		my $expr = sprintf('require("%s.pm") ; $applet = %s::Applet::%s->new', ucfirst($appletname), $self->{package}, ucfirst($appletname));

		undef($@);		
		eval($expr);

		if ($@) {
			print STDERR $@;

			my $message = _("Error loading {applet} applet.\n", applet => $appletname);
			my $toplevel = (split(/::/, $appletname))[0];
			if ($@ =~ /can't locate $toplevel/i) {
				$message = _("Error: couldn't find applet file {file}.pm.", file => $appletname);
			}

			$self->warning($message, sub {
				require('Configurator.pm');
				my $configurator = PerlPanel::Applet::Configurator->new;
				$configurator->configure;
				$configurator->init;
				$configurator->app->get_widget('notebook')->set_current_page(3);
			});

		} else {

			if (!defined($self->{config}{appletconf}{$appletname})) {
				my $hashref;
				eval '$hashref = $applet->get_default_config';
				$self->{config}{appletconf}{$appletname} = $hashref if (defined($hashref));
			}

			$applet->configure;
			$self->add($applet->widget, $applet->expand, $applet->fill);
			$applet->widget->show_all;
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
	my $self = shift || $OBJECT_REF;
	$self->save_config;
	exit;
}

sub reload {
	my $self = shift || $OBJECT_REF;
	$self->panel->set_sensitive(0);
	$self->save_config;
	foreach my $applet ($self->{hbox}->get_children) {
		$applet->destroy;
	}
	$self->load_applets;
	$self->configure;
	$self->move;
	$self->panel->set_sensitive(1);
	return 1;
}

sub request_string {
	my ($self, $message, $callback, $visible);
	if (scalar(@_) == 4) {
		($self, $message, $callback, $visible) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $callback, $visible) = @_;
	}

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
	if (scalar(@_) == 3) {
		($self, $message, $callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $callback) = @_;
	}
	$self->request_string($message, $callback, 1);
}

# you shouldn't need to access this directly -
# instead use one of the wrappers below:
sub alert {
	my ($self, $message, $ok_callback, $cancel_callback, $type);
	if (scalar(@_) == 5) {
		($self, $message, $ok_callback, $cancel_callback, $type) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $ok_callback, $cancel_callback, $type) = @_;
	}

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

	$dialog->show_all;

	return 1;
}

sub question {
	my ($self, $message, $ok_callback, $cancel_callback);
	if (scalar(@_) == 4) {
		($self, $message, $ok_callback, $cancel_callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $ok_callback, $cancel_callback) = @_;
	}
	return $self->alert($message, $ok_callback, $cancel_callback, 'question');
}

sub error {
	my ($self, $message, $ok_callback);
	if (scalar(@_) == 3) {
		($self, $message, $ok_callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $ok_callback) = @_;
	}
	return $self->alert($message, (defined($ok_callback) ? $ok_callback : sub { $self->shutdown} ), undef, 'error');
}

sub warning {
	my ($self, $message, $ok_callback);
	if (scalar(@_) == 3) {
		($self, $message, $ok_callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $ok_callback) = @_;
	}
	return $self->alert($message, $ok_callback, undef, 'warning');
}

sub notify {
	my ($self, $message, $ok_callback);
	if (scalar(@_) == 3) {
		($self, $message, $ok_callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($message, $ok_callback) = @_;
	}
	return $self->alert($message, $ok_callback, undef, 'info');
}

sub tips {
	my $self = shift || $OBJECT_REF;
	return $self->{tips};
}

sub panel {
	my $self = shift || $OBJECT_REF;
	return $self->{panel};
}

sub icon {
	my $self = shift || $OBJECT_REF;
	return $self->{icon};
}

sub icon_size {
	my $self = shift || $OBJECT_REF;
	return @{$SIZE_MAP{$self->{config}{panel}{size}}}[0];
}

sub icon_size_name {
	my $self = shift || $OBJECT_REF;
	return @{$SIZE_MAP{$self->{config}{panel}{size}}}[1];
}

#
# These do the same as the two subs above, but may do something else in the future:
#
sub menu_icon_size {
	my $self = shift || $OBJECT_REF;
	return $self->icon_size;
}
sub menu_icon_size_name {
	my $self = shift || $OBJECT_REF;
	return $self->icon_size_name;
}

sub screen_width {
	my $self = shift || $OBJECT_REF;
	return (defined($self->{screen}) ? $self->{screen}->get_width : $self->{screen_width});
}

sub screen_height {
	my $self = shift || $OBJECT_REF;
	return (defined($self->{screen}) ? $self->{screen}->get_height : $self->{screen_height});
}

sub position {
	my $self = shift || $OBJECT_REF;
	return $self->{config}{panel}{position};
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
	my ($self, $widget);
	if (scalar(@_) == 2) {
		($self, $widget) = @_;
	} else {
		$self = $OBJECT_REF;
		$widget = shift;
	}

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
	my $self = shift || $OBJECT_REF;
	my (undef, $x, $y, undef) = $self->panel->get_root_window->get_pointer;
	return ($x, $y);
}

sub exec_wait {
	my ($self, $command, $callback);
	if (scalar(@_) == 3) {
		($self, $command, $callback) = @_;
	} else {
		$self = $OBJECT_REF;
		($command, $callback) = @_;
	}

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
	my $self = shift || $OBJECT_REF;
	foreach my $applet (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		return 1 if ($applet eq 'BBMenu')
	}
	return undef;
}

sub has_action_menu {
	my $self = shift || $OBJECT_REF;
	foreach my $applet (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		return 1 if ($applet eq 'ActionMenu')
	}
	return undef;
}

sub has_pager {
	my $self = shift;
	foreach my $applet (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		return 1 if ($applet eq 'Pager')
	}
	return undef;
}

# this is just a stub, should we ever implement icon themes this will become
# more useful:
sub get_applet_pbf_filename {
	my ($self, $applet);
	if (scalar(@_) == 2) {
		($self, $applet) = @_;
	} else {
		$self = $OBJECT_REF;
		$applet = shift;
	}
	return sprintf('%s/%s.png', $APPLET_ICON_DIR, lc($applet));
}

sub get_applet_pbf {
	my ($self, $applet, $size);
	if (scalar(@_) == 3) {
		($self, $applet, $size) = @_;
	} else {
		$self = $OBJECT_REF;
		($applet, $size) = @_;
	}

	$size = ($size > 0 ? $size : $APPLET_ICON_SIZE);

	if (!defined($self->{pbfs}{$applet}{$size})) {
		my $file = $self->get_applet_pbf_filename($applet);
		if (-e $file) {
			$self->{pbfs}{$applet}{$size} = Gtk2::Gdk::Pixbuf->new_from_file($file);
			if ($self->{pbfs}{$applet}{$size}->get_height != $size) {
				$self->{pbfs}{$applet}{$size} = $self->{pbfs}{$applet}{$size}->scale_simple($size, $size, 'bilinear');
			}
		} else {
			$self->{pbfs}{$applet}{$size} = $self->get_applet_pbf('missing', $size);
		}
	}
	return $self->{pbfs}{$applet}{$size};
}

sub get_config {
	my ($self, $applet);
	if (scalar(@_) == 2) {
		($self, $applet) = @_;
	} else {
		$self = $OBJECT_REF;
		$applet = shift;
	}
	return $self->{config}{appletconf}{$applet};
}

sub spacing {
	my $self = shift || $OBJECT_REF;
	return $self->{config}{panel}{spacing};
}

sub load_glade {
	my ($self, $gladefile);
	if (scalar(@_) == 2) {
		($self, $gladefile) = @_;
	} else {
		$self = $OBJECT_REF;
		$gladefile = shift;
	}
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

1;
