# $Id: DriveManager.pm,v 1.1 2004/10/28 16:23:15 jodrell Exp $
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

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('DriveManager', $self->{id});

	print Data::Dumper::Dumper($self->{id});
	print Data::Dumper::Dumper($self->{config});

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_relief('none');
	$self->{config}->{type} = $DEFAULT_TYPE if ($TYPES{$self->{config}->{type}} eq '');

	if (!-x $MOUNT) {
		PerlPanel::error(_("DriveManager cannot find the 'mount' program, please check your PATH"));

	} else {
		$self->init;
		$self->widget->show_all;

	}

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
		device	=>	$NULL_DEVICE,
		point	=>	$NULL_DEVICE,
		type	=>	$DEFAULT_TYPE,
	}
}

sub mounted {
	print "mounted\n";
	my $self = shift;
	if (!open(MOUNT, "$MOUNT|")) {
		PerlPanel::error(_("DriveManager could not execute '{mount}': {error}", mount => $MOUNT, error => $!));

	} else {
		my $mounted = 0;
		while (<MOUNT>) {
			my ($device, undef) = split(/\s+/, $_, 2);
			$mounted++ if ($device eq $self->{config}->{device});
		}
		close(MOUNT);
		return ($mounted > 0 ? 1 : undef);

	}
}

1;
