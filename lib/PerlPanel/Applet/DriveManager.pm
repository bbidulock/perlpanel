# $Id: DriveManager.pm,v 1.4 2004/10/31 10:25:45 jodrell Exp $
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
use vars qw($MULTI $NULL_DEVICE %TYPES $DEFAULT_TYPE $MOUNT $UMOUNT $EJECT);
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
chomp(our $UMOUNT	= `which umount`);
chomp(our $EJECT	= `which eject`);

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('DriveManager', $self->{id});

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	$self->widget->add(Gtk2::Image->new);

	$self->{config}->{type} = $DEFAULT_TYPE if ($TYPES{$self->{config}->{type}} eq '');

	if (!-x $MOUNT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'mount'));

	} elsif (!-x $UMOUNT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'umount'));

	} elsif (!-x $EJECT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'eject'));

	} else {
		$self->init;
		$self->widget->show_all;

	}

	Glib::Timeout->add(1000, sub { $self->update });
	$self->update;

	$self->{type_model} = Gtk2::ListStore->new(qw(Gtk2::Gdk::Pixbuf Glib::String));
	foreach my $type (sort keys %TYPES) {
		$self->{type_model}->set(
			$self->{type_model}->append,
			0 => Gtk2::Gdk::Pixbuf->new_from_file_at_size(
				PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-%s', lc($PerlPanel::NAME), $type)),
				16, 16,
			),
			1 => $TYPES{$type},
		);
	}

	return 1;
}

sub init {
	my $self = shift;
	$self->widget->child->set_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file_at_size(
		PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-%s', lc($PerlPanel::NAME), $self->{config}->{type})),
		PerlPanel::icon_size,
		PerlPanel::icon_size
	));

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
		$self->menu->append($self->menu_item(
			_('Browse...'),
			'gtk-open',
			sub { $self->browse },
		));
		$self->menu->append($self->menu_item(
			_('Eject'),
			Gtk2::Gdk::Pixbuf->new_from_file_at_size(
				PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-eject', lc($PerlPanel::NAME))),
				PerlPanel::menu_icon_size, PerlPanel::menu_icon_size,
			),
			sub { $self->unmount && $self->eject },
		));
	} else {
		$self->menu->append($self->menu_item(
			_('Close Tray'),
			Gtk2::Gdk::Pixbuf->new_from_file_at_size(
				PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-eject', lc($PerlPanel::NAME))),
				PerlPanel::menu_icon_size, PerlPanel::menu_icon_size,
			),
			sub { $self->close },
		));
		$self->menu->append($self->menu_item(
			_('Eject'),
			Gtk2::Gdk::Pixbuf->new_from_file_at_size(
				PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-eject', lc($PerlPanel::NAME))),
				PerlPanel::menu_icon_size, PerlPanel::menu_icon_size,
			),
			sub { $self->eject },
		));
		$self->menu->append($self->menu_item(
			_('Mount'),
			'gtk-go-forward',
			sub { $self->mount },
		));
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
	$combo->set_model($self->{type_model});

	my $renderer = Gtk2::CellRendererPixbuf->new;
	$combo->pack_start($renderer, undef);
	$combo->set_attributes($renderer, 'pixbuf' => 0);

	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, undef);
	$combo->set_attributes($renderer, 'text' => 1);

	my $i = 0;
	foreach my $type (sort keys %TYPES) {
		if ($type eq $self->{config}->{type}) {
			$combo->set_active($i);
			last;

		} else {
			$i++;

		}
	}

	my $glade = PerlPanel::load_glade('drivemanager');

	$glade->get_widget('device_entry')->set_text($self->{config}->{device});
	$glade->get_widget('mountpoint_entry')->set_text($self->{config}->{point});

	$glade->get_widget('device_browse_button')->signal_connect('clicked', sub {
		my $dialog = Gtk2::FileChooserDialog->new(
			_('Choose Device'),
			undef,
			'open',
			'gtk-cancel'	=> 'cancel',
			'gtk-ok'	=> 'ok',
		);
		$dialog->set_modal(1);
		$dialog->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				$glade->get_widget('device_entry')->set_text($dialog->get_filename);
			}
			$dialog->destroy;
		});
		$dialog->show_all;
		# this can take ages, cos gnomevfs takes ages to read the /dev directory:
		$dialog->set_filename($glade->get_widget('device_entry')->get_text);
	});
	$glade->get_widget('mountpoint_browse_button')->signal_connect('clicked', sub {
		my $dialog = Gtk2::FileChooserDialog->new(
			_('Choose Mount Point'),
			undef,
			'select-folder',
			'gtk-cancel'	=> 'cancel',
			'gtk-ok'	=> 'ok',
		);
		$dialog->set_modal(1);
		$dialog->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				$glade->get_widget('mountpoint_entry')->set_text($dialog->get_current_folder);
			}
			$dialog->destroy;
		});
		$dialog->show_all;
		# this can take ages, cos gnomevfs takes ages to read the /dev directory:
		$dialog->set_current_folder($glade->get_widget('mountpoint_entry')->get_text);
	});

	$glade->get_widget('type_combo_placeholder')->pack_start($combo, 1, 1, 0);

	$glade->get_widget('config_dialog')->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			$self->{config}->{device}	= $glade->get_widget('device_entry')->get_text;
			$self->{config}->{point}	= $glade->get_widget('mountpoint_entry')->get_text;
			$self->{config}->{type}		= (sort(keys(%TYPES)))[$combo->get_active];
			PerlPanel::save_config;
			$self->init;
		}
		$glade->get_widget('config_dialog')->destroy;
	});
	$glade->get_widget('config_dialog')->set_position('center');
	$glade->get_widget('config_dialog')->set_icon(PerlPanel::icon);
	$glade->get_widget('config_dialog')->show_all;

	return 1;
}

sub mount {
	my $self = shift;
	$self->wait_command(sprintf('%s %s %s', $MOUNT, $self->{config}->{device}, $self->{config}->{point}));
}

sub unmount {
	my $self = shift;
	$self->wait_command(sprintf('%s %s', $UMOUNT, $self->{config}->{point}));
}

sub eject {
	my $self = shift;
	$self->wait_command(sprintf('%s %s', $EJECT, $self->{config}->{device}));
}

sub close {
	my $self = shift;
	$self->wait_command(sprintf('%s -t %s', $EJECT, $self->{config}->{device}));
}

sub wait_command {
	my ($self, $cmd) = @_;
	my $panel = $PerlPanel::OBJECT_REF;
	$panel->panel->get_root_window->set_cursor($panel->{cursors}->{busy});
	$self->widget->set_sensitive(undef);
	PerlPanel::exec_wait($cmd, sub {
		$self->widget->set_sensitive(1);
		$panel->panel->get_root_window->set_cursor($panel->{cursors}->{normal});
		if ($? > 0) {
			PerlPanel::warning(_("Error: command '{cmd}' failed", cmd => $cmd));
		}
	});
	return ($? > 0 ? undef : 1);
}

1;
