# $Id: DriveManager.pm,v 1.2 2004/10/28 21:52:45 jodrell Exp $
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
package PerlPanel::Applet::DriveManager;
use vars qw($MULTI $NULL_DEVICE %TYPES $DEFAULT_TYPE $MOUNT);
use base 'PerlPanel::MenuBase';
use strict;

our $MULTI		= 1;
our $NULL_DEVICE	= '/dev/null';
our $DEFAULT_TYPE	= 'drive';
our %TYPES = (
	cdrom		=> _('CD ROM'),
	drive		=> _('Hard Disk'),
	flash		=> _('Flash or Smart Media Card'),
	ipod		=> _('iPod'),
	removable	=> _('Removable Drive (Floppy, Zip or Jaz)'),
	usb		=> _('USB Device (Camera, external HD)'),
);
chomp(our $MOUNT	= `which mount`);

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('DriveManager', $self->{id});

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->clicked });

	$self->{config}->{type} = $DEFAULT_TYPE if ($TYPES{$self->{config}->{type}} eq '');

	if (!-x $MOUNT) {
		PerlPanel::error(_("DriveManager cannot find the 'mount' program, please check your PATH"));

	} else {
		$self->init;
		$self->widget->show_all;

	}

	Glib::Timeout->add(1000, sub { $self->update });
	$self->update;

	return 1;
}

sub init {
	my $self = shift;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file_at_size(
		PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-%s', lc($PerlPanel::NAME), $self->{config}->{type})),
		PerlPanel::icon_size,
		PerlPanel::icon_size
	)));

	return 1;
}

sub widget {
	return $_[0]->{widget};
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
	return {
		device	=> $NULL_DEVICE,
		point	=> $NULL_DEVICE,
		type	=> $DEFAULT_TYPE,
	}
}

sub mounted {
	my $self = shift;
	if (!open(MOUNT, "$MOUNT|")) {
		PerlPanel::error(_("DriveManager could not execute '{mount}': {error}", mount => $MOUNT, error => $!));

	} else {
		my $mounted = 0;
		while (<MOUNT>) {
			Gtk2->main_iteration while (Gtk2->events_pending);
			my ($device, undef) = split(/\s+/, $_, 2);
			$mounted++ if ($device eq $self->{config}->{device});
		}
		close(MOUNT);
		return ($mounted > 0 ? 1 : undef);

	}
}

sub update {
	my $self = shift;

	if (!$self->configured) {
		PerlPanel::tips->set_tip($self->widget, _('Click to configure.'));

	} elsif ($self->mounted) {
		PerlPanel::tips->set_tip($self->widget, _('{device} is mounted', device => $self->{config}->{device}));

	} else {
		PerlPanel::tips->set_tip($self->widget, _('{device} is not mounted', device => $self->{config}->{device}));

	}

	return 1;
}

sub configured {
	my $self = shift;
	return ($self->{config}->{device} ne $NULL_DEVICE);
}

sub clicked {
	my $self = shift;
	if ($self->configured) {
		$self->create_menu;
		$self->popup;

	} else {
		$self->config_dialog;

	}
	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;

	if ($self->mounted) {

	} else {

	}

	$self->menu->append(Gtk2::SeparatorMenuItem->new);

	$self->menu->append($self->menu_item(
		_('Properties'),
		'gtk-properties',
		sub { $self->config_dialog },
	));
	$self->menu->append($self->menu_item(
		_('Remove from panel'),
		'gtk-remove',
		sub {
			PerlPanel::remove_applet('DriveManager', $self->{id});
		},
	));

	return 1;
}

sub config_dialog {
	my $self = shift;

	my $combo = Gtk2::ComboBox->new;

	my $glade = PerlPanel::load_glade('drivemanager');

	$glade->get_widget('device_entry')->set_text($self->{config}->{device});
	$glade->get_widget('mountpoint_entry')->set_text($self->{config}->{point});

	$glade->get_widget('device_browse_button')->signal_connect('clicked', sub {
	});
	$glade->get_widget('mountpoint_browse_button')->signal_connect('clicked', sub {
	});

	$glade->get_widget('type_combo_placeholder')->pack_start($combo, 1, 1, 0);

	$glade->get_widget('config_dialog')->signal_connect('response', sub {
		$glade->get_widget('config_dialog')->destroy;
	});
	$glade->get_widget('config_dialog')->set_position('center');
	$glade->get_widget('config_dialog')->show_all;

	return 1;
}

1;
