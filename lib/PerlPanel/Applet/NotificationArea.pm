# $Id: NotificationArea.pm,v 1.3 2004/09/10 16:24:11 jodrell Exp $
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
	PerlPanel::warning(_('NotificationArea applet cannot manage this screen.'));
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

	$self->{widget} = Gtk2::HBox->new;
	$self->widget->set_size_request(-1, PerlPanel::icon_size());

	$self->{hbox} = Gtk2::HBox->new;
	$self->{hbox}->set_border_width(0);
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

	$self->widget->pack_start($self->{button}, 0, 0, 0);
	$self->widget->pack_start($self->{hbox}, 1, 1, 0);

	if ($CAN_MANAGE == 1) {
		$TRAY_MANAGER->signal_connect('tray_icon_added', sub {
			# put the socket inside a viewport so the panel doesn't get stretched if the
			# icon is too large:
			my $port = Gtk2::Viewport->new;
			$port->set_border_width(0);
			$port->set_size_request(-1, (PerlPanel::icon_size() - 2));
			$port->set_shadow_type('none');
			if (defined($_[1]->parent)) {
				$_[1]->reparent($port);
			} else {
				$port->add($_[1]);
			}
			$self->{hbox}->add($port);
			$port->show_all;
			$self->widget->set_size_request(-1, PerlPanel::icon_size());

			$self->{hbox}->show;
			$self->{button}->child->set('right', 'none') if (defined($self->{button}->child));
			$self->{state} = 'shown';
			PerlPanel::tips->set_tip($self->{button}, _('Hide icons'));
		});

		$TRAY_MANAGER->signal_connect('tray_icon_removed', sub {
			$self->{hbox}->remove($_[1]->parent) if defined($_[1]->parent);
			$self->widget->set_size_request(-1, PerlPanel::icon_size());
		});

		return 1;
	}
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
