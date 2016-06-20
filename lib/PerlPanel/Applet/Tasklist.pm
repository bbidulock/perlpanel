# $Id: Tasklist.pm,v 1.10 2004/11/07 20:00:29 jodrell Exp $
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
package PerlPanel::Applet::Tasklist;
use Gnome2::Wnck;
use vars qw($MULTI);
use strict;

our $MULTI = 1;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Tasklist', $self->{id});

	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;

	$self->{tasklist} = Gnome2::Wnck::Tasklist->new($self->{screen});

	$self->{widget} = Gtk2::HBox->new;
	$self->widget->set_spacing(0);
	$self->widget->set_border_width(0);

	unless (exists $self->{config}{button_relief}) {
#		$self->{config}{button_relief} = 'normal';
#		$self->{config}{button_relief} = 'half';
		$self->{config}{button_relief} = 'none';
		PerlPanel::save_config();
	}
	$self->{tasklist}->set_button_relief($self->{config}{button_relief});

	unless (exists $self->{config}{grouping}) {
#		$self->{config}{grouping} = 'always-group';
#		$self->{config}{grouping} = 'never-group';
		$self->{config}{grouping} = 'auto-group';
		PerlPanel::save_config();
	}
	$self->{tasklist}->set_grouping($self->{config}{grouping});

	unless (exists $self->{config}{grouping_limit}) {
		$self->{config}{grouping_limit} = 800;
		PerlPanel::save_config();
	}
	$self->{tasklist}->set_grouping_limit($self->{config}{grouping_limit});
#	$self->{tasklist}->set_grouping_limit($self->{screen}->get_width);

	unless (exists $self->{config}{include_all_workspaces}) {
		$self->{config}{include_all_workspaces} = 1;
		PerlPanel::save_config();
	}
	$self->{tasklist}->set_include_all_workspaces($self->{config}{include_all_workspaces});
	unless (exists $self->{config}{switch_workspace_on_unminimize}) {
		$self->{config}{switch_workspace_on_unminimize} = 1;
		PerlPanel::save_config();
	}
	$self->{tasklist}->set_switch_workspace_on_unminimize($self->{config}{switch_workspace_on_unminimize});

	$self->resize if (PerlPanel::expanded);

	if ($PerlPanel::OBJECT_REF->{config}{panel}{expand} eq 'false') {
		my $button = Gtk2::Button->new;
		$button->set_border_width(0);
		$button->signal_connect('clicked', sub { $self->popup_menu });
		$self->widget->pack_start($button, 0, 0, 0);
	}

	$self->widget->pack_start($self->{tasklist}, 1, 1, 0);
	$self->widget->show_all;

	return 1;
}

sub resize {
	my $self = shift;
	$self->{tasklist}->set_minimum_width($self->{config}{minimum_width});
	$self->widget->set_size_request($self->{config}{minimum_width}, PerlPanel::icon_size);
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 1;
}

sub fill {
	return 1;
}

sub end {
	return 'start';
}

sub get_default_config {
	return {
		minimum_width	=> 150,
		button_relief	=> 'none',
		grouping_limit  => 800,
		grouping	=> 'auto-group',
		include_all_workspaces => 1,
		switch_workspace_on_unminimize => 1,
	};
}

sub popup_menu {
	my $self = shift;
	my $menu = Gtk2::Menu->new;

	my $properties_item = Gtk2::ImageMenuItem->new_from_stock('gtk-properties');
	$properties_item->signal_connect('activate', sub { $self->prefs_window });

	my $remove_item	= Gtk2::ImageMenuItem->new_from_stock('gtk-remove');
	$remove_item->signal_connect('activate', sub { PerlPanel::remove_applet('Tasklist', $self->{id}) });

	$menu->add($properties_item);
	$menu->add($remove_item);
	$menu->show_all;
	$menu->popup(undef, undef, sub { return $self->popup_position($menu) }, undef, 3, undef);
	return 1;

}

sub popup_position {
	my ($self, $menu) = @_;
	my ($x, undef) = PerlPanel::get_mouse_pointer_position();
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);

	} else {
		$menu->realize;
		return ($x, PerlPanel::screen_height() - $menu->allocation->height - PerlPanel::panel->allocation->height);

	}
}

sub prefs_window {
	my $self = shift;
	my $glade = PerlPanel::load_glade('tasklist');
	$glade->get_widget('icon')->set_from_pixbuf(PerlPanel::get_applet_pbf('Tasklist'));
	$glade->get_widget('width_spin')->set_range(1, PerlPanel::screen_width);
	$glade->get_widget('width_spin')->set_value($self->{config}{minimum_width});
	$glade->get_widget('width_spin')->signal_connect('value-changed', sub {
		$self->{config}{minimum_width} = $glade->get_widget('width_spin')->get_value;
		PerlPanel::save_config();
		$self->resize if (PerlPanel::expanded);
	});
	$glade->get_widget('prefs_dialog')->set_position('center');
	$glade->get_widget('prefs_dialog')->set_icon(PerlPanel::icon);
	$glade->get_widget('prefs_dialog')->signal_connect('response', sub {
		$glade->get_widget('prefs_dialog')->destroy;
	});
	$glade->get_widget('prefs_dialog')->show_all;
	return 1;
}

1;
