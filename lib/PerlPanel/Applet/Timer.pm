# $Id: Timer.pm,v 1.6 2005/04/14 14:20:33 jodrell Exp $
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
package PerlPanel::Applet::Timer;
use vars qw($OGGPLAYER);
use strict;

chomp(our $OGGPLAYER = `which ogg123 2>/dev/null`);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->{label} = Gtk2::Label->new;
	$self->widget->add(Gtk2::HBox->new);
	$self->widget->set_relief('none');
	$self->widget->child->pack_start(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('Timer', PerlPanel::icon_size)), 0, 0, 0);
	$self->widget->child->pack_start($self->{label}, 1, 1, 0);
	PerlPanel::tips->set_tip($self->widget, _('Timer'));
	$self->widget->show_all;
	$self->{label}->hide;

	$self->{glade} = PerlPanel::load_glade('timer');
	$self->{glade}->get_widget('icon')->set_from_pixbuf(PerlPanel::get_applet_pbf('Timer', 48));
	$self->{glade}->get_widget('config_dialog')->set_icon($self->{glade}->get_widget('icon')->get_pixbuf);

	$self->{glade}->get_widget('config_dialog')->signal_connect('delete_event', sub {
		$self->{glade}->get_widget('config_dialog')->hide_all;
		$self->widget->set_sensitive(1);
		return 1;
	});

	$self->{glade}->get_widget('stop_button')->signal_connect('clicked', sub {
		$self->{countdown} = 0;
		$self->{glade}->get_widget('config_dialog')->hide_all;
		$self->widget->set_sensitive(1);
	});

	$self->{glade}->get_widget('reset_button')->signal_connect('clicked', sub {
		$self->{countdown} = 0;
		$self->{glade}->get_widget('alarm')->set_active(undef);
		$self->{glade}->get_widget('minutes')->set_value(0);
		$self->{glade}->get_widget('seconds')->set_value(0);
	});

	$self->{glade}->get_widget('start_button')->signal_connect('clicked', sub {
		$self->{countdown} = $self->get_countdown;
		$self->{glade}->get_widget('config_dialog')->hide_all;
		$self->widget->set_sensitive(1);
	});

	$self->widget->signal_connect('clicked', sub {
		$self->{glade}->get_widget('config_dialog')->show_all;
		$self->widget->set_sensitive(undef);
	});

	PerlPanel::add_timeout(1000, sub {
		if ($self->{countdown} < 1) {
			$self->{label}->hide;
			if ($self->{alert} == 1) {
				$self->alert;
				$self->{alert} = 0;
			}

		} else {
			$self->{label}->show;
			my $mins = int(($self->{countdown}) / 60);
			my $secs = $self->{countdown} - ($mins * 60);
			$self->{glade}->get_widget('minutes')->set_value($mins);
			$self->{glade}->get_widget('seconds')->set_value($secs);
			$self->{label}->set_text(sprintf('%02d:%02d', $mins, $secs));
			$self->{countdown}--;
			if ($self->{countdown} == 0) {
				$self->{alert} = 1;
			}
		}
		return 1;
	});

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

sub get_countdown {
	my $self = shift;
	return ($self->{glade}->get_widget('minutes')->get_value * 60) +
		$self->{glade}->get_widget('seconds')->get_value;
}

sub alert {
	my $self = shift;
	PerlPanel::notify(_('Time\'s Up!'));
	if ($self->{glade}->get_widget('alarm')->get_active) {
		$self->alarm;
	}
	return 1;
}

sub alarm {
	my $self = shift;
	if (!-x $OGGPLAYER) {
		PerlPanel::warning(_('Cannot find sound player command'));

	} else {
		my $alarm = sprintf('%s/share/%s/applets/timer/alarm.ogg', $PerlPanel::PREFIX, lc($PerlPanel::NAME));
		my $cmd = join(' ', $OGGPLAYER, '--quiet', $alarm, $alarm, $alarm).' &';
		system($cmd);

	}
	return 1;
}

1;
