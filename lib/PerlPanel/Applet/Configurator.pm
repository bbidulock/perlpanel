# $Id: Configurator.pm,v 1.64 2004/11/04 16:52:18 jodrell Exp $
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
package PerlPanel::Applet::Configurator;
use vars qw(%SETTINGS_MAP);
use Gtk2::SimpleList;
use strict;

#
# settings map - this maps widgets in the glade file to
# values in the config.
#
# the keys are the ID of the widget in the glade file.
#
# the values are references to arrays of the form:
#
#	[
#		$reference_to_config,
#		$config_keyname,
#		$type,
#		@values,
#	],
#
# where $type can be on of: enum, boolean, string, or integer.
#
# for enums, @values must contain the same entries as appear
# in the option menu.

our %SETTINGS_MAP = (

	#
	# Tab #1 - global panel settings:
	#
	'panel_position' => [
		$PerlPanel::OBJECT_REF->{config}{panel},
		'position',
		'enum',
		'top',
		'bottom',
	],
	'panel_size_spin' => [
		$PerlPanel::OBJECT_REF->{config}{panel},
		'size',
		'integer',
	],
	'panel_autohide' => [
		$PerlPanel::OBJECT_REF->{config}{panel},
		'autohide',
		'boolean',
	],

	#
	# Tab #2 - BBMenu settings
	#
	'bbmenu_control_items' => [
		PerlPanel::get_config('BBMenu'),
		'show_control_items',
		'boolean',
	],
	'bbmenu_submenu' => [
		PerlPanel::get_config('BBMenu'),
		'apps_in_submenu',
		'boolean',
	],

	#
	# Tab #2 - GNOME menu settings
	#
	'gnome_menu_control_items' => [
		PerlPanel::get_config('GnomeMenu'),
		'show_control_items',
		'boolean',
	],
	'gnome_menu_submenu' => [
		PerlPanel::get_config('GnomeMenu'),
		'apps_in_submenu',
		'boolean',
	],

	#
	# Tab #2 - OpenBox menu settings
	#
	'obmenu_control_items' => [
		PerlPanel::get_config('OpenBoxMenu'),
		'show_control_items',
		'boolean',
	],
	'obmenu_submenu' => [
		PerlPanel::get_config('OpenBoxMenu'),
		'apps_in_submenu',
		'boolean',
	],

	#
	# Tab 2 - Global menu settings
	#

	'quit_button_checkbutton' => [
		$PerlPanel::OBJECT_REF->{config}{panel},
		'show_quit_button',
		'boolean',
	],

);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('configurator', PerlPanel::icon_size)));
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->init });
	PerlPanel::tips->set_tip($self->widget, 'Configure');
	$self->widget->show_all;
	return 1;
}

sub init {
	my $self = shift;
	$self->build_ui;
	return 1;
}

sub build_ui {
	my $self = shift;
	$self->{app} = PerlPanel::load_glade('configurator');

	$self->app->get_widget('panel_tab_image')->set_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file_at_size(PerlPanel::lookup_icon(sprintf('%s-panel', lc($PerlPanel::NAME))), 24, 24));
	$self->app->get_widget('menu_tab_image')->set_from_pixbuf(PerlPanel::get_applet_pbf('bbmenu', 24));
	$self->app->get_widget('applet_tab_image')->set_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file_at_size(PerlPanel::lookup_icon(sprintf('%s-applets', lc($PerlPanel::NAME))), 24, 24));

	$self->setup_config_mapping;

	$self->setup_custom_settings;

	$self->app->get_widget('prefs_window')->set_icon(PerlPanel::icon);

	$self->app->get_widget('prefs_window')->signal_connect('response', sub {
		$self->app->get_widget('prefs_window')->hide_all;
		if ($_[1] eq 'ok') {
			$self->apply_custom_settings;
			$self->apply_settings;
			PerlPanel::save_config;
			PerlPanel::reload;
		}
	});

	$self->app->get_widget('prefs_window')->show_all;

	return 1;
}

sub setup_config_mapping {
	my $self = shift;
	foreach my $widget_id (keys %SETTINGS_MAP) {
		my $widget = $self->app->get_widget($widget_id);
		my ($ref, $key, $type, @values) = @{$SETTINGS_MAP{$widget_id}};

		if ($type eq 'string') {
			$widget->set_text($ref->{$key});

		} elsif ($type eq 'boolean') {
			$widget->set_active($ref->{$key} eq 'true' ? 1 : undef);

		} elsif ($type eq 'enum') {
			my $i = 0;
			foreach my $value (@values) {
				if ($ref->{$key} eq $value) {
					$widget->set_history($i);
				}
				$i++;
			}

		} elsif ($type eq 'integer') {
			$widget->set_value($ref->{$key});

		} else {
			die("unknown type '$type' for key '$key'");

		}
	}
	return 1;
}

sub apply_settings {
	my $self = shift;
	foreach my $widget_id (keys %SETTINGS_MAP) {
		my $widget = $self->app->get_widget($widget_id);
		# if $widget is undef, it may have been destroyed previously:
		next unless (defined($widget));
		my ($ref, $key, $type, @values) = @{$SETTINGS_MAP{$widget_id}};
		if ($type eq 'string') {
			$ref->{$key} = $widget->get_text;

		} elsif ($type eq 'boolean') {
			$ref->{$key} = ($widget->get_active ? 'true' : 'false');

		} elsif ($type eq 'enum') {
			$ref->{$key} = $widget->child->get_text;

		} elsif ($type eq 'integer') {
			$ref->{$key} = $widget->get_value_as_int;

		} else {
			die("unknown type '$type' for key '$key'");

		}
	}
	return 1;
}

sub setup_custom_settings {
	my $self = shift;

	my @dirs = $PerlPanel::OBJECT_REF->{icon_theme}->get_search_path;
	my %themes = (
		$PerlPanel::DEFAULT_THEME => 1,
	);
	foreach my $dir (@dirs) {
		if (opendir(DIR, $dir)) {
			map { $themes{$_}++ if (-e "$dir/$_/index.theme") } readdir(DIR);
			closedir(DIR);
		}
	}

	$self->{icon_theme_list} = Gtk2::SimpleList->new('theme' => 'text');
	$self->app->get_widget('icon_theme')->set_model($self->{icon_theme_list}->get_model);
	my @themes = sort(keys(%themes));
	for (my $i = 0 ; $i < scalar(@themes) ; $i++) {
		push(@{$self->{icon_theme_list}->{data}}, $themes[$i]);
		if ($themes[$i] eq $PerlPanel::OBJECT_REF->{config}->{panel}->{icon_theme}) {
			$self->app->get_widget('icon_theme')->set_active($i);
		}
	}

	if (!PerlPanel::has_applet('BBMenu')) {
		$self->app->get_widget('bbmenu_prefs_label')->destroy;
		$self->app->get_widget('bbmenu_prefs_hbox')->destroy;
		$self->app->get_widget('bbmenu_prefs_spacer')->destroy;
	}
	if (!PerlPanel::has_applet('GnomeMenu')) {
		$self->app->get_widget('gnome_menu_prefs_label')->destroy;
		$self->app->get_widget('gnome_menu_prefs_hbox')->destroy;
		$self->app->get_widget('gnome_menu_prefs_spacer')->destroy;
	}
	if (!PerlPanel::has_applet('OpenBoxMenu')) {
		$self->app->get_widget('obmenu_prefs_label')->destroy;
		$self->app->get_widget('obmenu_prefs_hbox')->destroy;
		$self->app->get_widget('obmenu_prefs_spacer')->destroy;
	}

	$self->{applet_list} = Gtk2::SimpleList->new_from_treeview(
		$self->app->get_widget('applet_list'),
		'Icon'	=> 'pixbuf',
		'Name'	=> 'text',
		'id'	=> 'text',
	);
	$self->{applet_list}->get_column(2)->set_visible(0);

	foreach my $appletname (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		my ($applet, $id) = split(/::/, $appletname, 2);
		my $pbf;
		$pbf = PerlPanel::get_applet_pbf($applet, 32);
		if ($applet eq 'Launcher' && $id ne '') {
			my $file = sprintf('%s/%s.desktop', $PerlPanel::Applet::Launcher::LAUNCHER_DIR, $id);
			if (-r $file) {
				my $entry = PerlPanel::DesktopEntry->new($file);
				if (-r $entry->Icon) {
					$pbf = Gtk2::Gdk::Pixbuf->new_from_file_at_size($entry->Icon, 32, 32);
				}
			}
		}
		push(@{$self->{applet_list}->{data}}, [$pbf, $applet, $id]);
	}
	$self->{applet_list}->set_reorderable(1);

	$self->app->get_widget('add_applet_button')->signal_connect('clicked', sub { $self->run_add_applet_dialog });

	$self->app->get_widget('remove_applet_button')->signal_connect('clicked', sub {
		my (undef, $iter) = $self->{applet_list}->get_selection->get_selected;
		return undef unless (defined($iter));
		my $idx = ($self->{applet_list}->get_model->get_path($iter)->get_indices)[0];
		$self->{applet_list}->get_model->remove($iter);
		$self->{applet_list}->select($idx - 1) if ($idx > 0);
	});


	$self->{add_applet_list} = Gtk2::SimpleList->new_from_treeview(
		$self->app->get_widget('applet_info_list'),
		'Icon'		=> 'pixbuf',
		'Name'		=> 'text',
	);

	my $column = $self->{add_applet_list}->get_column(1);
	$column->set_spacing(12);

	my ($renderer) = $column->get_cell_renderers;

	$column->clear_attributes($renderer);
	$column->add_attribute($renderer, 'markup', 1);

	$self->load_applet_list;

	return 1;
}

sub get_applet_list {
	my $self = shift;
	my @files;

	@files = sort grep { $_ !~ /^_/ } keys %{$self->{registry}};

	$self->{files} = \@files;
	return 1;
}

sub load_applet_list {
	my $self = shift;

	$self->{registry} = PerlPanel::load_appletregistry;
	$self->get_applet_list;

	@{$self->{add_applet_list}->{data}} = ();
	foreach my $file (@{$self->{files}}) {
		my ($appletname, undef) = split(/\./, $file, 2);
		push(@{$self->{add_applet_list}->{data}}, [
			PerlPanel::get_applet_pbf($appletname),
			sprintf("<span weight=\"bold\">%s</span>\n<span size=\"small\">%s</span>", $appletname, ($self->{registry}{$appletname} ne '' ? $self->{registry}{$appletname} : _('No description available.'))),
		]);
	}

	return 1;
}

sub run_add_applet_dialog {
	my $self = shift;

	$self->app->get_widget('add_dialog')->signal_connect('delete_event', sub {
		$self->app->get_widget('add_dialog')->hide_all;
		return 1;
	});
	$self->app->get_widget('add_dialog')->signal_connect('response', sub {

		if ($_[1] eq 'ok') {
			my $seln = $self->{add_applet_list}->get_selection;
			return unless (defined($seln));
			my ($blah, $iter) = $seln->get_selected;
			return undef unless (defined($iter));
			my $idx = ($self->{add_applet_list}->get_model->get_path($iter)->get_indices)[0];
			my ($appletname, undef) = split(/\./, $self->{files}[$idx], 2);
			push(@{$self->{applet_list}->{data}}, [PerlPanel::get_applet_pbf($appletname, 24), $appletname]);
			$seln->unselect_all;
		}

		$self->app->get_widget('add_dialog')->hide_all;
	});

	$self->app->get_widget('install_button')->signal_connect('clicked', sub { PerlPanel::install_applet_dialog(sub { $self->load_applet_list }) });

	$self->app->get_widget('add_dialog')->show_all;

	return 1;
}

sub apply_custom_settings {
	my $self = shift;
	my @applets;
	foreach my $rowref (@{$self->{applet_list}->{data}}) {
		if (@{$rowref}[2] ne '') {
			push(@applets, @{$rowref}[1].'::'.@{$rowref}[2]);
		} else {
			push(@applets, @{$rowref}[1]);
		}
	}
	@{$PerlPanel::OBJECT_REF->{config}{applets}} = @applets;

	if (!$self->app->get_widget('panel_autohide')->get_active && $PerlPanel::OBJECT_REF->{config}{panel}{autohide} eq 'true') {
		PerlPanel::panel->signal_handler_disconnect($PerlPanel::OBJECT_REF->{enter_connect_id});
		PerlPanel::panel->signal_handler_disconnect($PerlPanel::OBJECT_REF->{leave_connect_id});
	}

	$PerlPanel::OBJECT_REF->{config}->{panel}->{icon_theme} = @{@{$self->{icon_theme_list}->{data}}[$self->app->get_widget('icon_theme')->get_active]}[0];

	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub app {
	return $_[0]->{app};
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
	return undef;
}

1;
