# $Id: DriveManager.pm,v 1.7 2004/11/05 10:00:32 jodrell Exp $
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
use vars qw($MULTI %TYPES %DEVICES %EJECTABLE $DEFAULT_POINT $DEFAULT_TYPE $MOUNT $UMOUNT $EJECT $NAUTILUS $FSTAB);
use base 'PerlPanel::MenuBase';
use strict;

our $MULTI		= 1;
our $DEFAULT_TYPE	= 'drive';
our %TYPES = (
	cdrom		=> _('CD/DVD ROM'),
	drive		=> _('Hard Disk'),
	flash		=> _('Flash or Smart Media Card'),
	ipod		=> _('iPod'),
	removable	=> _('Removable Drive (Floppy, Zip or Jaz)'),
	usb		=> _('USB Device (Camera, external HD)'),
	remote		=> _('Network Drive (SMB or NFS)'),
);
our %EJECTABLE		= (
	cdrom		=> 1,
	removable	=> 1,
);
our $DEFAULT_POINT	= '/mnt/non-existent-mountpoint';
our $FSTAB		= '/etc/fstab';
chomp(our $MOUNT	= `which mount`);
chomp(our $UMOUNT	= `which umount`);
chomp(our $EJECT	= `which eject`);
chomp(our $NAUTILUS	= `which nautilus`);

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('DriveManager', $self->{id});

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->clicked });
	$self->widget->add(Gtk2::Image->new);

	$self->{config}->{type} = $DEFAULT_TYPE if ($TYPES{$self->{config}->{type}} eq '');

	our %DEVICES = $self->get_devices;

	if (!-x $MOUNT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'mount'));

	} elsif (!-x $UMOUNT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'umount'));

	} elsif (!-x $EJECT) {
		PerlPanel::error(_("DriveManager cannot find the '{cmd}' program, please check your PATH", cmd => 'eject'));

	} elsif (!defined($DEVICES{$self->{config}->{point}}) && $self->{config}->{point} ne $DEFAULT_POINT) {
		PerlPanel::warning(
			_("Your system's {fstab} has changed, cannot determine device for {point}", fstab => $FSTAB, point => $self->{config}->{point}),
			sub { $self->config_dialog }
		);

	} else {
		$self->init;
		$self->widget->show_all;

	}

	$self->{timeout} = PerlPanel::add_timeout(1000, sub { $self->update });
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
		point	=> $DEFAULT_POINT,
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
			$mounted++ if (/on $self->{config}->{point}/);
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
		PerlPanel::tips->set_tip($self->widget, _('{device} is mounted', device => $self->{config}->{point}));

	} else {
		PerlPanel::tips->set_tip($self->widget, _('{device} is not mounted', device => $self->{config}->{point}));

	}

	return 1;
}

sub configured {
	my $self = shift;
	return ($self->{config}->{point} ne $DEFAULT_POINT);
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
		my $browse_item = $self->menu_item(
			_('Browse...'),
			'gtk-open',
			sub { $self->browse },
		);
		$browse_item->set_sensitive(-x $NAUTILUS);
		$self->menu->append($browse_item);

		if (defined($EJECTABLE{$self->{config}->{type}})) {
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
				_('Unmount'),
				'gtk-execute',
				sub { $self->unmount },
			));

		}

	} else {
		if (defined($EJECTABLE{$self->{config}->{type}})) {
			$self->menu->append($self->menu_item(
				_('Open Tray'),
				Gtk2::Gdk::Pixbuf->new_from_file_at_size(
					PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-eject', lc($PerlPanel::NAME))),
					PerlPanel::menu_icon_size, PerlPanel::menu_icon_size,
				),
				sub { $self->eject },
			));
			$self->menu->append($self->menu_item(
				_('Close Tray'),
				Gtk2::Gdk::Pixbuf->new_from_file_at_size(
					PerlPanel::lookup_icon(sprintf('%s-applet-drivemanager-eject', lc($PerlPanel::NAME))),
					PerlPanel::menu_icon_size, PerlPanel::menu_icon_size,
				),
				sub { $self->close },
			));
		}
		$self->menu->append($self->menu_item(
			_('Mount'),
			'gtk-execute',
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
			PerlPanel::remove_timeout($self->{timeout});
			PerlPanel::remove_applet('DriveManager', $self->{id});
		},
	));

	return 1;
}

sub config_dialog {
	my $self = shift;

	my $point_combo = Gtk2::ComboBox->new_text;
	foreach my $point (sort(keys(%DEVICES))) {
		$point_combo->append_text($point);
	}

	my $type_combo = Gtk2::ComboBox->new;
	$type_combo->set_model($self->{type_model});

	my $renderer = Gtk2::CellRendererPixbuf->new;
	$type_combo->pack_start($renderer, undef);
	$type_combo->set_attributes($renderer, 'pixbuf' => 0);

	my $renderer = Gtk2::CellRendererText->new;
	$type_combo->pack_start($renderer, undef);
	$type_combo->set_attributes($renderer, 'text' => 1);

	my $i = 0;
	foreach my $type (sort keys %TYPES) {
		if ($type eq $self->{config}->{type}) {
			$type_combo->set_active($i);
			last;

		} else {
			$i++;

		}
	}

	my $i = 0;
	foreach my $type (sort keys %DEVICES) {
		if ($type eq $self->{config}->{point}) {
			$point_combo->set_active($i);
			last;

		} else {
			$i++;

		}
	}

	my $glade = PerlPanel::load_glade('drivemanager');

	$glade->get_widget('point_combo_placeholder')->pack_start($point_combo,	1, 1, 0);
	$glade->get_widget('type_combo_placeholder')->pack_start($type_combo,	1, 1, 0);

	$glade->get_widget('config_dialog')->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			$self->{config}->{point} = (sort(keys(%DEVICES)))[$point_combo->get_active];
			$self->{config}->{type} = (sort(keys(%TYPES)))[$type_combo->get_active];
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
	return $self->wait_command(sprintf('%s "%s"', $MOUNT, $self->{config}->{point}));
}

sub unmount {
	my $self = shift;
	return $self->wait_command(sprintf('%s "%s"', $UMOUNT, $self->{config}->{point}));
}

sub eject {
	my $self = shift;
	return $self->wait_command(sprintf('%s "%s"', $EJECT, $DEVICES{$self->{config}->{point}}));
}

sub close {
	my $self = shift;
	return $self->wait_command(sprintf('%s -t "%s"', $EJECT, $DEVICES{$self->{config}->{point}}));
}

sub browse {
	my $self = shift;
	my $cmd = sprintf('%s --no-desktop "%s" &', $NAUTILUS, $self->{config}->{point});
	system($cmd);
	return 1;
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

sub get_devices {
	my $self = shift;
	my %DEVICES;
	if (!open(FSTAB, $FSTAB)) {
		PerlPanel::error(_("Cannot read '{fstab}': {error}", fstab => $FSTAB, error => $!));

	} else {
		while (<FSTAB>) {
			chomp;
			my ($device, $point, undef, $opts, undef) = split(/[\t\s]+/, $_, 5);
			if ($opts =~ /user|owner/) {
				$DEVICES{$point} = $device;
			}
		}
		close(FSTAB);
		return %DEVICES;
	}
}

1;
