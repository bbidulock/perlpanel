# $Id: PerlPanel.pm,v 1.144 2005/02/21 15:58:50 jodrell Exp $
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
use Gnome2::Wnck;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use POSIX qw(setlocale);
use Locale::gettext;
use base 'Exporter';
use File::Basename qw(basename dirname);
use XML::Simple;
use vars qw(	$NAME		$VERSION	$DESCRIPTION	$VERSION	@LEAD_AUTHORS
		@CO_AUTHORS	$URL		$LICENSE	$PREFIX		$LIBDIR
		%DEFAULTS	%SIZE_MAP	$TOOLTIP_REF	$OBJECT_REF	$APPLET_ICON_DIR
		$APPLET_ICON_SIZE		@APPLET_DIRS	$PIDFILE	$RUN_COMMAND_FILE
		$RUN_HISTORY_FILE		$RUN_HISTORY_LENGTH		@APPLET_CATEGORIES
		$DEFAULT_THEME	$APPLET_ERROR_MARKUP		$DESKTOP_NAMESPACE
		$DEFAULT_RCFILE	@GLADE_PATHS	$HIDE_OFFSET);
use strict;

$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

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
		size			=> 24,
		has_border		=> 'true',
		menu_size		=> 'medium',
		menu_icon_size		=> 'medium',
		expand			=> 'true',
		use_struts		=> 'true',
		icon_theme		=> $DEFAULT_THEME,
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

our $APPLET_ICON_SIZE	= 48;
our $RUN_COMMAND_FILE	= sprintf('%s/.%s/run-command', $ENV{HOME}, lc($NAME));
our $PIDFILE		= sprintf('%s/.%s/%s.pid', $ENV{HOME}, lc($NAME), lc($NAME));
our $RUN_HISTORY_FILE	= sprintf('%s/.perlpanel/run-history', $ENV{HOME});
our $RUN_HISTORY_LENGTH	= 15;
our $HIDE_OFFSET	= 2;
our @APPLET_CATEGORIES	= qw(Actions System Utilities Launchers Menus Amusements);
our $DEFAULT_THEME	= 'gnome';

our $APPLET_ERROR_MARKUP = <<"END";
<span weight="bold">%s</span>
END

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{rcfile}		= (defined($ARGV[0]) ? $ARGV[0] : sprintf('%s/.%src', $ENV{HOME}, lc($NAME)));
	$OBJECT_REF		= $self;
	bless($self, $self->{package});

	Gtk2->init;

	our $APPLET_ICON_DIR	= sprintf('%s/share/pixmaps/%s/applets', $PREFIX, lc($NAME));
	our $DEFAULT_RCFILE	= sprintf('%s/etc/%src', $PREFIX, lc($NAME));
	our @APPLET_DIRS	= (
		sprintf('%s/.%s/applets',	$ENV{HOME}, lc($NAME)),	# user-installed applets
		sprintf('%s/%s/Applet',		$LIBDIR, $NAME),	# admin-installed or sandbox applets ($LIBDIR is
	);								# determined at runtime)

	$self->{locale} = (defined($ENV{LC_MESSAGES}) ? $ENV{LC_MESSAGES} : $ENV{LANG});

	# stuff for ill8n - this has to be done before any strings are used:
	setlocale(LC_ALL, $self->locale);
	bindtextdomain(lc($NAME), sprintf('%s/share/locale', $PREFIX));
	textdomain(lc($NAME));

	our $DESCRIPTION	= _('The Lean, Mean, Panel Machine!');
	our $LICENSE		= _('This program is Free Software. You may use it under the terms of the GNU General Public License.');

	our @GLADE_PATHS = (
		sprintf('%s/.local/share/%s/glade/%%s.glade',	$ENV{HOME}, lc($NAME)),
		sprintf('%s/share/%s/glade/%%s.glade',		$PREFIX, lc($NAME)),
	);

	return $self;
}

sub init {
	my $self = shift;
	$self->setup_launch_feedback;
	$self->load_config;
	$self->get_screen;
	$self->load_icon_theme;
	$self->build_panel;
	$self->configure;
	$self->load_applets;
	$self->setup_dnd;
	$self->{hbox}->show;
	$self->{vbox}->show;
	$self->{border}->show;
	$self->{panel}->show;

	if ($self->{config}->{panel}->{autohide} eq 'true') {
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

sub locale { return $OBJECT_REF->{locale} }

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
	if ($self->{config}->{version} ne $VERSION) {
		print STDERR "*** your config file is from a different version, strange things may happen!\n";
	}

	# check for an old value for icon_size, and correct:
	if (@{$SIZE_MAP{$OBJECT_REF->{config}->{panel}->{size}}}[0] > 0) {
		$OBJECT_REF->{config}->{panel}->{size} = @{$SIZE_MAP{$OBJECT_REF->{config}->{panel}->{size}}}[0];
		$self->save_config;
	}
	if (defined($self->{config}->{panel}->{menu_size_as_panel})) {
		delete($self->{config}->{panel}->{menu_size_as_panel});
		$self->save_config;
	}
	if (defined($self->{config}->{panel}->{menu_size})) {
		delete($self->{config}->{panel}->{menu_size});
		$self->save_config;
	}

	if (!defined($self->{config}->{panel}->{use_struts})) {
		$self->{config}->{panel}->{use_struts} = 'true';
		$self->save_config;
	}

	return 1;
}

sub save_config {
	my $self = shift || $OBJECT_REF;
	$self->{config}->{version} = $VERSION;
	# clean up dead config:
	foreach my $string (keys(%{$self->{config}->{multi}})) {
		my ($applet, $id) = split(/::/, $string, 2);
		if ($id ne '' && !defined($self->{widgets}->{$id})) {
			delete($self->{config}->{multi}->{$string});
		}
	}
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

	$self->{icon_theme}->prepend_search_path(sprintf('%s/share/icons', $PREFIX));
	$self->{icon_theme}->prepend_search_path(sprintf('%s/.%s/icon-files', $ENV{HOME}, lc($NAME)));
	$self->{icon_theme}->prepend_search_path(sprintf('%s/.local/share/icons', $ENV{HOME}));

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

	$self->{border} = Gtk2::DrawingArea->new;
	$self->{border}->set_size_request(-1, 1);
	$self->{border}->signal_connect('expose_event', sub { $self->draw_border });

	$self->{panel}->add($self->{vbox});

	$self->arrange_border;

	return 1;
}

sub arrange_border {
	my $self = shift;

	if ($self->position eq 'top') {
		$self->{vbox}->pack_start($self->{hbox},	1, 1, 0);
		$self->{vbox}->pack_start($self->{border},	0, 0, 0);

	} else {
		$self->{vbox}->pack_start($self->{border},	0, 0, 0);
		$self->{vbox}->pack_start($self->{hbox},	1, 1, 0);

	}
	return 1;
}

sub draw_border {
	my $self = shift;
	# paint an hline with a vertical offset that shows a hilight or a shadow depending on the panel's
	# position on screen
	$self->{border}->style->paint_hline(
		$self->{border}->window,
		'normal',
		Gtk2::Gdk::Rectangle->new(0, 0, $self->{border}->allocation->width, 1),
		$self->{border},
		'foo',
		0, $self->{border}->allocation->width, ($self->{config}->{panel}->{position} eq 'top' ? 0 : -1),
	);
	return 1;
}

sub configure {
	my $self = shift;

	$self->{screen}->signal_connect('monitors-changed', sub { $self->move });
	$self->{screen}->signal_connect('size-changed', sub { $self->move });

	if ($self->{config}->{panel}->{expand} ne 'false') {
		$self->resize;
	} else {
		$self->shrink;
		$self->panel->set_resizable(0);
		$self->panel->signal_connect('size-request', sub { $self->move });
	}

	$self->panel->set_border_width(0);
	$self->{hbox}->set_spacing($self->{config}->{panel}->{spacing});
	$self->{hbox}->set_border_width(0);

	# check is_visible for reloads:
	my $gdk_window = $self->panel->window;
	if (!defined($gdk_window) || !$gdk_window->is_visible) {
		$self->panel->set_type_hint('dock');
	}

	if ($self->{config}->{panel}->{autohide} eq 'true') {
		$self->panel->set_keep_above(1);
		$self->panel->set_keep_below(0);
	} else {
		$self->panel->set_keep_above(0);
		if ($self->{config}->{panel}->{expand} ne 'false') {
			$self->panel->set_keep_below(1);
		} else {
			$self->panel->set_keep_below(0);
		}
	}

	$self->panel->set_decorated(0);
	$self->panel->stick;
	$self->panel->set_skip_pager_hint(1);
	$self->panel->set_skip_taskbar_hint(1);

	$self->panel->set_deletable(0);
	$self->panel->set_accept_focus(1);
	$self->panel->set_focus_on_map(0);
	$self->panel->set_has_frame(0);
	$self->panel->set_auto_startup_notification(1);
	$self->panel->set_resizable(0);

	if ($self->{config}->{panel}->{autohide} eq 'true') {
		$self->{leave_connect_id} = $self->panel->signal_connect('leave_notify_event', sub { $self->autohide; });
		$self->{enter_connect_id} = $self->panel->signal_connect('enter_notify_event', sub { $self->autoshow; });
	}

	push(@INC, @APPLET_DIRS);

	return 1;
}

sub load_applets {
	my $self = shift;

	# this is some munging for when the config gets confused when being serialized to/from XML:
	if (ref($self->{config}->{applets}) ne 'ARRAY') {
		$self->{config}->{applets} = [ $self->{config}->{applets} ];
	}

	@{$self->{config}->{applets}} = grep { defined } @{$self->{config}->{applets}};

	for (my $i = 0 ; $i < scalar(@{$self->{config}->{applets}}) ; $i++) {
		$self->load_applet(@{$self->{config}->{applets}}[$i], $i);
	}

	return 1;
}

sub load_applet {
	my ($self, $raw, $position) = @_;

	my ($appletname, $id) = split(/::/, $raw, 2);

	my ($applet, $expr, $multi);

	eval(sprintf('require "%s.pm"', ucfirst($appletname)));
	if ($@) {
		print STDERR $@;
		$self->applet_error($appletname, $@);
		return undef;
	}

	eval(sprintf('$multi = $%s::Applet::%s::MULTI', $self->{package}, ucfirst($appletname)));
	if ($@) {
		print STDERR $@;
		$self->applet_error($appletname, $@);
		return undef;
	}

	if (defined($multi) && $id eq '') {
		$id = $self->new_applet_id;
		@{$self->{config}->{applets}}[$position] = sprintf('%s::%s', $appletname, $id);
		save_config();
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
		print STDERR $@;
		$self->applet_error($appletname, $@);
		return undef;
	}

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
		$self->add_applet($applet->widget, $applet->expand, $applet->fill, $position);
		$applet->widget->show;
		if ($id ne '') {
			$self->{widgets}->{$id} = $applet->widget;
		}
	}

	return 1;
}

sub applet_error {
	my ($self, $appletname, $error) = @_;
	my $message = _("Error loading {applet} applet.\n", applet => $appletname);
	my $toplevel = (split(/::/, $appletname))[0];
	if ($error =~ /can\'t locate $toplevel/i) {
		$message = _("Error: couldn't find applet file {file}.pm.", file => $appletname);
	}

	my $glade = PerlPanel::load_glade('applet-error');
	$glade->get_widget('error_label')->set_markup(sprintf($APPLET_ERROR_MARKUP, $message));
	$glade->get_widget('error_text')->get_buffer->set_text($error);
	$glade->get_widget('error_dialog')->signal_connect('response', sub {
		$_[0]->destroy;
		require('Configurator.pm');
		my $configurator = PerlPanel::Applet::Configurator->new;
		$configurator->configure;
		$configurator->init;
		$configurator->app->get_widget('notebook')->set_current_page(2);
	});
	$glade->get_widget('error_dialog')->set_position('center');
	$glade->get_widget('error_dialog')->set_icon($self->icon);
	$glade->get_widget('error_dialog')->show_all;
	return 1;
}

sub add_applet {
	my ($self, $widget, $expand, $fill, $position) = @_;
	$self->{hbox}->pack_start($widget, $expand, $fill, 0);
	if (defined($position)) {
		$self->{hbox}->reorder_child($widget, $position);
	}
	return 1;
}

sub setup_dnd {
	my $self = shift;
	my $target_list	= Gtk2::TargetList->new;
	$target_list->add(Gtk2::Gdk::Atom->new('text/uri-list'), 0, 0);
	$self->panel->drag_dest_set(['drop', 'motion', 'highlight'], ['copy', 'private', 'default', 'move', 'link', 'ask']);
	$self->panel->signal_connect(drag_data_received => sub { $self->drop_handler(@_) });
	$self->panel->drag_dest_set_target_list($target_list);
	return 1;
}

sub drop_handler {
	my $self = shift;
	my @uris = split(/[\r\n]+/, $_[4]->data);
	my $file = $uris[0];
	if ($file !~ /^file:\/\//) {
		warning(_('Sorry, applets can only be installed from local files.'));

	} else {

		if ($file =~ /\.desktop$/i) {
			launcher_drop_receive($file);

		} elsif (basename($file) !~ /^(\w+)-(.+)\.tar\.gz$/) {
			warning(_('Cannot install this applet: invalid filename.'));

		} else {
			$file =~ s!^file:/+!/!g;
			install_applet_dialog(undef, $file);

		}

	}

	return 1;

}

sub launcher_drop_receive {
	my $file = shift;
	$file =~ s!file://!!g;
	if (!-e $file) {
		warning(_('Cannot load file "{file}": not found.', file => basename($file)));

	} elsif (!-r $file) {
		warning(_('Cannot read file "{file}".', file => basename($file)));

	} else {
		require('Launcher.pm');

		return undef if ($file =~ /^$PerlPanel::Applet::Launcher::LAUNCHER_DIR/);

		my $id = new_applet_id();
		my $applet = sprintf('Launcher::%s', $id);
		my $new_file = sprintf('%s/%s.desktop', $PerlPanel::Applet::Launcher::LAUNCHER_DIR, $id);

		my $xpos = ($OBJECT_REF->panel->get_root_window->get_pointer)[1];

		my $i = 0;
		my $last = 0;
		WIDGET: foreach my $widget ($OBJECT_REF->{hbox}->get_children) {
			my $widget_pos_x = (get_widget_position($widget))[0];
			if (($widget_pos_x < $xpos) && (($widget_pos_x + $widget->allocation->width) > $xpos)) {
				mkpath($PerlPanel::Applet::Launcher::LAUNCHER_DIR);
				open(SRC, $file) or die "$file: $!\n";
				open(DST, ">$new_file") or die "$new_file: $!\n";
				while (<SRC>) {
					print DST $_;
				}
				close(DST);
				close(SRC);
				splice(@{$OBJECT_REF->{config}->{applets}}, $i+1, 0, $applet);
				$OBJECT_REF->load_applet($applet, $i+1);
				save_config();

			} else {
				$last = $widget_pos_x;
				$i++;
			}
		}

	}

	return 1;
}

sub remove_applet {
	my ($applet, $id) = @_;
	for (my $i = 0 ; $i < scalar(@{$OBJECT_REF->{config}->{applets}}) ; $i++) {
		if ((@{$OBJECT_REF->{config}->{applets}})[$i] eq sprintf('%s::%s', $applet, $id)) {
			$OBJECT_REF->{widgets}->{$id}->destroy;
			splice(@{$OBJECT_REF->{config}->{applets}}, $i, 1);
			PerlPanel::save_config();
			return 1;
		}
	}
	warning(_("Could not remove the {applet}::{id} applet!", applet => $applet, id => $id));
	return undef;
}

sub show_all {
	my $self = shift;

	$self->panel->show_all;

	return 1;
}

sub move {
	my $self = shift;
	my $panel_width = $self->panel->allocation->width;

	if ($panel_width == 1 && $self->{config}->{panel}->{expand} eq 'false') {
		return 1;
	}

	$self->resize unless ($self->{config}->{panel}->{expand} eq 'false');

	my ($xpos, $ypos) = $self->get_desired_position;
	$self->panel->parse_geometry("+$xpos+$ypos"); # sets initial UPosition
	$self->panel->move($xpos, $ypos);

	# now we do the struts thing:
	if (defined($self->panel->window)) {
		my ($top, $bottom) = (0, 0);
		my ($top_start_x, $top_end_x, $bottom_start_x, $bottom_end_x) = (0, 0, 0, 0);

		unless ($self->{config}{panel}{autohide} eq 'true' or
			($self->{config}{panel}{expand} eq 'false' and $self->{config}{panel}{use_struts} eq 'false')) {
			my($x,$y) = $self->panel->get_position;
			if ($self->position eq 'top') {
				$top = $self->panel->allocation->height;
				$top_start_x = $x;
				$top_end_x = $x + $self->panel->allocation->width;
			} else {
				$bottom = $self->panel->allocation->height;
				$bottom_start_x = $x;
				$bottom_end_x = $x + $self->panel->allocation->width;
			}
		}
		if ($top or $bottom) {
			unless ($self->{struts} and $self->{struts}[0] == $top and $self->{struts}[1] == $bottom) {
				$self->panel->window->property_change(
					Gtk2::Gdk::Atom->intern(_NET_WM_STRUT=>undef),
					Gtk2::Gdk::Atom->intern(CARDINAL=>undef),
					32,
					'replace',
					0,
					0,
					$top,
					$bottom,
				);
			}
			unless ($self->{struts} and $self->{struts}[0] == $top and $self->{struts}[1] == $bottom
					and $self->{struts}[2] == $top_start_x and $self->{struts}[3] == $top_end_x
					and $self->{struts}[4] == $bottom_start_x and $self->{struts}[5] == $bottom_end_x) {
				$self->panel->window->property_change(
					Gtk2::Gdk::Atom->intern(_NET_WM_STRUT_PARTIAL=>undef),
					Gtk2::Gdk::Atom->intern(CARDINAL=>undef),
					32,
					'replace',
					0,0,$top,$bottom,
					0,0,
					0,0,
					$top_start_x, $top_end_x,
					$bottom_start_x, $bottom_end_x,
				);
			}
			$self->{struts} = [ $top, $bottom, $top_start_x, $top_end_x, $bottom_start_x, $bottom_end_x ];
		} elsif ($self->{struts}) {
			$self->panel->window->property_delete(
				Gtk2::Gdk::Atom->intern(_NET_WM_STRUT=>undef));
			$self->panel->window->property_delete(
				Gtk2::Gdk::Atom->intern(_NET_WM_STRUT_PARTIAL=>undef));
			delete $self->{struts};
		}
	}
	return 1;
}

sub get_desired_position {
	my $self = shift;

	my ($xpos, $ypos);
	$xpos = ($self->{config}->{panel}->{expand} eq 'true' ? 0 : int(($self->screen_width - $self->panel->allocation->width) / 2));

	if ($self->position eq 'top' && $self->{config}->{panel}->{autohide} eq 'true' && $self->{hidden} eq 'true') {
		# panel is at the top, expand is set and the panel is currently hidden:
		$ypos = 0 - $self->panel->allocation->height + $HIDE_OFFSET;

	} elsif ($self->position eq 'top') {
		# panel is at the top, expand is not set and the panel is currently shown:
		$ypos = 0;

	} elsif ($self->position eq 'bottom' && $self->{config}->{panel}->{autohide} eq 'true' && $self->{hidden} eq 'true') {
		# panel is at the bottom, expand is set and the panel is currently hidden:
		$ypos = $self->screen_height - $HIDE_OFFSET;

	} elsif ($self->position eq 'bottom') {
		# panel is at the bottom, expand is not set and the panel is currently shown:
		$ypos = $self->screen_height - $self->panel->allocation->height;

	} else {
		$self->error(_("Invalid panel position '{position}'.", position => $self->position), sub { $self->shutdown });

	}

	return ($xpos, $ypos);
}

sub resize {
	my $self = shift;
	$self->panel->set_default_size($self->screen_width, -1);
	$self->panel->set_size_request($self->screen_width, -1);
	return 1;
}

sub shrink {
	my $self = shift;
	$self->panel->set_default_size(-1, -1);
	$self->panel->set_size_request(-1, -1);
	return 1;
}

=pod

here's how this works: the launch() function sets the DESKTOP_STARTUP_ID
environment variable when it runs an external program - compliant apps will
take note of this variable and broadcast their startup state when they run.
It also provides the user with some visible feedback (eg, a "busy" cursor).
The panel keeps a Gnome2::Wnck::Screen instance, and when a new application
starts, a signal is emitted which we capture. If the startup ID is one we
recognise, then we reset the root window cursor and remove the ID from the
list of IDs we're tracking. launch() also sets a timeout to clean up after
1500ms for those apps that don't support startup notification.

clear as mud, what?

=cut
sub setup_launch_feedback {
	my $self = shift;
	$self->{cursors}->{normal}	= Gtk2::Gdk::Cursor->new('left_ptr');
	$self->{cursors}->{busy}	= Gtk2::Gdk::Cursor->new('watch');
	$self->{wnckscreen} = Gnome2::Wnck::Screen->get_default;
	$self->{wnckscreen}->force_update;
	$self->{wnckscreen}->signal_connect('application-opened', sub {
		$self->launch_manager($_[1]->get_startup_id);
	});
	$self->{wnckscreen}->signal_connect('window-opened', sub {
		$self->launch_manager($_[1]->get_application->get_startup_id);
	});
	$self->{startup_ids} = {};
	return 1;
}

sub start_feedback {
	return $OBJECT_REF->panel->get_root_window->set_cursor($OBJECT_REF->{cursors}->{busy});
}
sub end_feedback {
	return $OBJECT_REF->panel->get_root_window->set_cursor($OBJECT_REF->{cursors}->{normal});
}

sub launch_manager {
	my ($self, $id) = @_;
	if ($id ne '') {
		if (!defined($self->{startup_ids}->{$id})) {
			return undef;
		} else {
			undef($self->{startup_ids}->{$id});
			$self->end_feedback;
		}
	}
	return 1;
}

sub launch {
	my ($cmd, $startup) = @_;
	# $cmd might have some %x tokens in it, provided by a .desktop file. We don't
	# support them just yet, so just remove them:
	$cmd =~ s/\%[fFuUdDnNickv]//g;

	if (defined($startup)) {
		my $id = sprintf('%s_%s', $NAME, new_applet_id());
		$cmd = sprintf('DESKTOP_STARTUP_ID=%s %s &', $id, $cmd);
		$OBJECT_REF->{startup_ids}->{$id} = $cmd;
		$OBJECT_REF->start_feedback;
		# we use Glib::Timeout here because if we used add_timeout
		# and the user reloaded the panel while we're still waiting
		# the timeout would never get called:
		Glib::Timeout->add(5000, sub {
			if (defined($OBJECT_REF->{startup_ids}->{$id})) {
				undef($OBJECT_REF->{startup_ids}->{$id});
				$OBJECT_REF->end_feedback;
			}
			return undef;
		});
	} else {
		$cmd = sprintf('%s &', $cmd);
	}
	system($cmd);
	return 1;
}

sub shutdown {
	$OBJECT_REF->save_config;
	unlink($PIDFILE);
	exit;
}

# note to applet authors: please avoid using
# this function wherever possible - if you wish to apply preference changes
# to your applet, do so inside the applet and then call PerlPanel::save_config()
# to commit them to disk. Calling PerlPanel::reload() may produce
# unpredictable behaviour in other applets.
sub reload {
	my $self = $OBJECT_REF;
	$self->panel->set_sensitive(0);
	$self->save_config;
	foreach my $applet_widget ($self->{hbox}->get_children) {
		$applet_widget->destroy;
	}
	map { remove_timeout($_) } @{$self->{timeouts}};
	$self->{vbox}->remove($self->{hbox});
	$self->{vbox}->remove($self->{border});
	$self->load_icon_theme;
	$self->arrange_border;
	$self->{struts_set} = 0;
	$self->shrink if ($self->{config}->{panel}->{expand} ne 'false');
	$self->load_applets;
	$self->configure;
	$self->panel->set_sensitive(1);
	$self->move;
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
	$dialog->set_position('center');

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
	return $OBJECT_REF->{config}->{panel}->{size};
}

sub menu_icon_size {
	my $self = $OBJECT_REF;
	my $size = (defined($OBJECT_REF->{config}->{panel}->{menu_icon_size}) ? $OBJECT_REF->{config}->{panel}->{menu_icon_size} : $DEFAULTS{panel}->{menu_icon_size});
	return @{$SIZE_MAP{$size}}[0];
}

sub menu_icon_size_name {
	my $self = $OBJECT_REF;
	my $size = (defined($OBJECT_REF->{config}->{panel}->{menu_icon_size}) ? $OBJECT_REF->{config}->{panel}->{menu_icon_size} : $DEFAULTS{panel}->{menu_icon_size});
	return @{$SIZE_MAP{$size}}[1];
}

sub screen_width {
	return (defined($OBJECT_REF->{screen}) ? $OBJECT_REF->{screen}->get_width : $OBJECT_REF->{screen_width});
}

sub screen_height {
	return (defined($OBJECT_REF->{screen}) ? $OBJECT_REF->{screen}->get_height : $OBJECT_REF->{screen_height});
}

sub position {
	return $OBJECT_REF->{config}->{panel}->{position};
}

sub autohide {
	my $self = shift;
	$self->{hidden} = 'true';
	my ($x, $y) = $self->get_desired_position;
	return 1;
}

sub autoshow {
	my $self = shift;
	$self->{hidden} = 'false';
	$self->move;
	return 1;
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
#   |   |  +--------+		  |    |
#   |   |  | Widget |		  |    |
#   |   |  +--------+		  |    |
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
	foreach my $appletname (@{$self->{config}->{applets}}) {
		return 1 if ($appletname =~ /^$applet/);
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

	if (!defined($self->{pbfs}->{$applet}->{$size})) {
		my $file = get_applet_pbf_filename($applet);
		if (-e $file) {
			$self->{pbfs}->{$applet}->{$size} = Gtk2::Gdk::Pixbuf->new_from_file_at_size($file, $size, $size);
		} elsif ($applet ne 'missing') {
			$self->{pbfs}->{$applet}->{$size} = get_applet_pbf('missing', $size);
		} else {
			#on-the-fly weirdo icon (white, two red lines across):
			my @xpm = ("$size $size 2 1", ". c Red", "  c White");
			for my $x (1 .. $size) { 
				for my $y (1 .. $size) { 
					$_ .= ($y == $x || $y == $size - $x) ? "." : " "
				} 
				push @xpm, $_; $_ = "";
			}
			$self->{pbfs}->{$applet}->{$size} = Gtk2::Gdk::Pixbuf->new_from_xpm_data(@xpm);
		}
	}
	return $self->{pbfs}->{$applet}->{$size};
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
	return $OBJECT_REF->{config}->{panel}->{spacing};
}

sub load_glade {
	my $gladefile = shift;

	foreach my $path (@GLADE_PATHS) {
		my $file = sprintf($path, $gladefile);
		return Gtk2::GladeXML->new($file) if (-r $file);
	}

	return undef;
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
		sprintf('%s/share/%s', $PREFIX, lc($NAME)),
		sprintf('%s/.%s', $ENV{HOME}, lc($NAME)),
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
			next unless (applet_exists($applet));
			$registry->{$applet} = _($description);
			$registry->{_categories}->{$category}->{$applet}++;
		}
		close(REGFILE);
	}
	foreach my $category (keys %{$registry->{_categories}}) {
		my @applets = sort keys %{$registry->{_categories}->{$category}};
		$registry->{_categories}->{$category} = \@applets;
	}
	return $registry;
}

sub applet_exists {
	my $applet = shift;
	foreach my $dir (@INC) {
		return 1 if -e ("$dir/$applet.pm");
	}
	return undef;
}

sub new_applet_id {
	return md5_hex(join('|', $ENV{HOSTNAME}, lc((getpwuid($<))[0]), time(), $0, int(rand(99999))));
}

sub install_applet_dialog {
	my ($callback, $file) = @_;
	my $glade = load_glade('applet-install');
	$glade->get_widget('install_applet_dialog')->set_position('center');
	$glade->get_widget('install_applet_dialog')->set_icon(icon());

	$glade->get_widget('install_applet_dialog')->signal_connect('response', sub {
		my $file = $glade->get_widget('file_entry')->get_text;
		$glade->get_widget('install_applet_dialog')->destroy;
		if ($_[1] eq 'ok') {
			my ($code, $error) = install_applet(
				$file,
				datadir	=> sprintf('%s/.local', $ENV{HOME}),
				libdir	=> sprintf('%s/.%s/applets', $ENV{HOME}, lc($NAME)),
				regfile	=> sprintf('%s/.%s/applet.registry', $ENV{HOME}, lc($NAME)),
			);
			if ($code == 1) {
				warning(_("Error installing '{file}': {error}", file => $file, error => $error));

			} elsif (defined($callback)) {
				&{$callback}();

			}
		}
	});

	$glade->get_widget('browse_button')->signal_connect('clicked', sub {
		my $chooser = Gtk2::FileChooserDialog->new(
			_('Choose File'),
			undef,
			'open',
			'gtk-cancel' => 'cancel',
			'gtk-ok' => 'ok'
		);
		$chooser->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				$glade->get_widget('file_entry')->set_text($chooser->get_filename);
			}
			$chooser->destroy;
		});
		$chooser->run;
	});

	$glade->get_widget('ok_button')->set_sensitive(undef);
	$glade->get_widget('file_entry')->signal_connect('changed', sub {
		if (
			-r $glade->get_widget('file_entry')->get_text &&
			basename($glade->get_widget('file_entry')->get_text) =~ /^(\w+)-(.+)\.tar\.gz/
		) {
			$glade->get_widget('ok_button')->set_sensitive(1);

		} else {
			$glade->get_widget('ok_button')->set_sensitive(undef);

		}
	});
	$glade->get_widget('file_entry')->set_text($file);

	$glade->get_widget('install_applet_dialog')->show_all;
	return 1;
}

sub install_applet {
	my $file = shift;
	my %params = @_;
	my ($name, $version);
	if (basename($file) =~ /^(\w+)-(.+)\.tar\.gz/) {
		$name		= $1;
		$version	= $2;
	}
	if ($name eq '' || $version eq '') {
		return (1, _('Cannot parse filename for name and version'));
	}

	my $cmd = sprintf('tar -ztf "%s"', $file);
	my %files;
	open(TAR, "$cmd|") or die "$cmd: $!\n";
	while (<TAR>) {
		chomp;
		$files{$_}++;
	}
	close(TAR);

	# required files:
	return(1, _('Applet description is missing'))	if (!defined($files{'applet.info'}));
	return(1, _('Applet file is missing'))		if (!defined($files{"applets/$name.pm"}));

	# append the applet description:

	# put the > at the front of $params{regfile} so we append:
	mkpath(dirname($params{regfile}));
	tar_extract($file, 'applet.info', ">$params{regfile}") or exit(256);

	mkpath($params{libdir});
	my $appletfile = sprintf('%s/%s.pm', $params{libdir}, $name);
	tar_extract($file, "applets/$name.pm", $appletfile) or exit(256);

	my @share = grep { ! /\/$/ } grep { /^share\/(icons|perlpanel\/glade)\// } keys(%files);
	foreach my $share_file (@share) {
		my $dest = sprintf('%s/%s', $params{datadir}, $share_file);
		mkpath(dirname($dest));
		tar_extract($file, $share_file, $dest) or exit(256);
	}

	return 0;
}

sub tar_extract {
	my ($tarball, $source, $dest) = @_;
	printf("%s => %s\n", $source, $dest);
	if (!open(SRC, sprintf('tar zxvf "%s" "%s" -O |', $tarball, $source))) {
		print STDERR "Cannot pipe from '$tarball': $!\n";
		return undef;

	} elsif (!open(DEST, ">$dest")) {
		print STDERR "Cannot open '$dest': $!\n";
		return undef;

	} else {
		while (<SRC>) {
			print DEST $_;
		}
		close(SRC);
		close(DEST);
		return 1;
	}
}

sub mkpath {
	my $dir = shift;
	return system(sprintf('mkdir -p "%s"', $dir));
}

sub add_timeout {
	my ($msec, $callback) = @_;
	my $id;
	$id = Glib::Timeout->add($msec, $callback, \$id);
	push(@{$OBJECT_REF->{timeouts}}, $id);
	return $id;
}

sub remove_timeout {
	my $id = shift;
	for (my $i = 0 ; $i < scalar(@{$OBJECT_REF->{timeouts}}) ; $i++) {
		if ($id == @{$OBJECT_REF->{timeouts}}[$i]) {
			splice(@{$OBJECT_REF->{timeouts}}, $i, 1);
			Glib::Source->remove($id);
			return 1;
		}
	}
	return undef;
}

sub expanded {
	return ($OBJECT_REF->{config}->{panel}->{expanded} == 'true' ? 1 : undef);
}

1;
