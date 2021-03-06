# $Id: NotificationArea.pm,v 1.7 2005/04/24 13:33:20 jodrell Exp $
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
package PerlPanel::Applet::NotificationArea;
use Gtk2::TrayManager;
use vars qw($DEFAULT_SCREEN $TRAY_MANAGER $CAN_MANAGE);
use strict;

#
# the notification area doesn't really like reloads of the panel.
# for this reason we maintain a single manager object that's created
# when the module is loaded. This means that trying to put more than one
# notification area applet in the panel will break things.
#
our $DEFAULT_SCREEN = Gtk2::Gdk::Screen->get_default;
if (Gtk2::TrayManager->check_running($DEFAULT_SCREEN)) {
	$CAN_MANAGE = 0;
} else {
	$CAN_MANAGE = 1;
	our $TRAY_MANAGER = Gtk2::TrayManager->new;
	$TRAY_MANAGER->manage_screen($DEFAULT_SCREEN);
	$TRAY_MANAGER->set_orientation('horizontal');
}

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{config} = PerlPanel::get_config('NotificationArea');

	$self->{box} = Gtk2::HBox->new;

	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_spacing(1);

	$self->{button} = Gtk2::Button->new;
	$self->{button}->add(Gtk2::Arrow->new('right', 'none'));
	$self->{button}->set_relief('none');
	$self->{button}->signal_connect('clicked', sub {
		if ($self->{state} eq 'hidden') {
			$self->{hbox}->show;
			$self->{button}->child->set('right', 'none');
			$self->{state} = 'shown';
			PerlPanel::tips->set_tip($self->{button}, _('Hide icons'));
		} else {
			$self->{hbox}->hide;
			$self->{button}->child->set('left', 'none');
			$self->{state} = 'hidden';
			PerlPanel::tips->set_tip($self->{button}, _('Show icons'));
		}
		$self->widget->set_size_request(-1, PerlPanel::icon_size());
	});
	PerlPanel::tips->set_tip($self->{button}, _('Hide icons'));

	$self->{box}->pack_start($self->{button}, 0, 0, 0);
	$self->{box}->pack_start($self->{hbox}, 1, 1, 0);

	$self->{widget} = Gtk2::Frame->new;
	$self->widget->add($self->{box});
	$self->widget->set_border_width(0);
	$self->widget->set_size_request(-1, PerlPanel::icon_size());

	if ($CAN_MANAGE == 1) {
		$TRAY_MANAGER->signal_connect('tray_icon_added', sub {
			my ($tray,$icon) = @_;
			if($self->{config}->{hide_if_empty} &&
			   $self->{config}->{hide_if_empty} !~ /^(no|false)$/i &&
			   $self->{fully_hid}) {
			   	$self->{widget}->set_shadow_type("etched_in");
				$self->{widget}->show_all();
				$self->{fully_hid} = 0;
			}
			$icon->set_size_request(-1, (PerlPanel::icon_size() - 2));
			if ($icon->parent) {
				$icon->reparent($self->{hbox});
			} else {
				$self->{hbox}->add($icon);
			}
			$icon->show_all;
			$self->widget->set_size_request(-1, PerlPanel::icon_size());

			$self->{hbox}->show;
			$self->{button}->child->set('right', 'none') if (defined($self->{button}->child));
			$self->{state} = 'shown';
			PerlPanel::tips->set_tip($self->{button}, _('Hide icons'));
		});

		$TRAY_MANAGER->signal_connect('tray_icon_removed', sub {
			my ($tray,$icon) = @_;
			$self->widget->set_size_request(-1, PerlPanel::icon_size());
			if ($self->{config}->{hide_if_empty} &&
			  $self->{config}->{hide_if_empty} !~ /^(no|false)$/i &&
			  ! scalar $self->{hbox}->get_children) {
				$self->{widget}->set_shadow_type("none");
				$self->{widget}->hide_all();
				$self->{fully_hid} = "yes, it's not here!";
			}
			
		});
	} else {
		$self->widget->set_sensitive(undef);

	}

	$self->widget->show_all;
	print join ("|", $self->{hbox}->get_children), "\n";
	if ($self->{config}->{hide_if_empty} && 
	  $self->{config}->{hide_if_empty} !~ /^(no|false)$/i &&
	  ! scalar $self->{hbox}->get_children) {
		$self->{widget}->set_shadow_type("none");
		$self->{widget}->hide_all();
		$self->{"fully_hid"} = "yes, it's not here!";
	}

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
	return undef;
}

1;
