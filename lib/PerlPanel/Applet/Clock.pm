# $Id: Clock.pm,v 1.25 2004/10/11 11:55:00 jodrell Exp $
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
package PerlPanel::Applet::Clock;
use Gtk2::SimpleList;
use POSIX qw(strftime);
use vars qw($MULTI);
use strict;

our $MULTI = 1;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self,		$self->{package});
	return			$self;
}

sub configure {
	my $self = shift;
	$self->{label} = Gtk2::Label->new;
	$self->{widget} = Gtk2::ToggleButton->new;
	$self->widget->set_relief('none');
	$self->widget->add($self->{label});
	$self->make_calendar;
	$self->widget->signal_connect('clicked', sub {
		if ($self->widget->get_active) {
			$self->show_calendar;
		} else {
			$self->hide_calendar;
		}
	});
	$self->{config} = PerlPanel::get_config('Clock', $self->{id});
	$self->update;
	Glib::Timeout->add(1000, sub { $self->update });
	$self->widget->show_all;
	return 1;
}

sub update {
	my $self = shift;
	$self->{label}->set_text(' '.strftime($self->{config}{format}, localtime(time())).' ');
	PerlPanel::tips->set_tip($self->widget, strftime($self->{config}{date_format}, localtime(time())));
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

sub get_default_config {
	return {
		format		=> '%H:%M',
		date_format	=> '%c',
	}
}

sub make_calendar {
	my $self = shift;
	$self->{glade} = PerlPanel::load_glade('calendar');
	$self->{window} = $self->{glade}->get_widget('calendar_window');
	$self->{window}->set_icon(PerlPanel::icon);
	$self->{window}->set_title(_('Calendar'));
	$self->{window}->set_skip_pager_hint(1);
	$self->{window}->set_skip_taskbar_hint(1);
	$self->{window}->set_decorated(undef);
	$self->{window}->set_type_hint('dialog');

	$self->{calendar} = $self->{glade}->get_widget('calendar');
	$self->{calendar}->signal_connect('day-selected', sub {
		my ($year, $month, $day) = $self->{calendar}->get_date;
		$self->{glade}->get_widget('date_label')->set_markup(sprintf(_('<span weight="bold">Events for %04d-%02d-%02d:</span>'), $year, $month+1, $day));
		$self->show_events($year, $month, $day);
	});

	my ($day, $month, $year) = (localtime())[3,4,5];
	$year+= 1900;
	$self->{calendar}->select_month($month, $year);
	$self->{calendar}->select_day($day);

	$self->{events} = Gtk2::SimpleList->new_from_treeview(
		$self->{glade}->get_widget('event_list'),
		'date'	=> 'text',
		'text'	=> 'text',
	);

	$self->{glade}->get_widget('add_button')->signal_connect('clicked', sub { $self->add_event_dialog });

	$self->{window}->child->show_all;
	$self->{window}->realize;

	return 1;
}

sub show_calendar {
	my $self = shift;
	my ($x, $y);
	my $x0 = (PerlPanel::get_widget_position($self->widget))[0];
	if ($x0 + $self->{window}->allocation->width > PerlPanel::screen_width) {
		$x = PerlPanel::screen_width() - $self->{window}->allocation->width;
	} else {
		$x = $x0;
	}
	if (PerlPanel::position eq 'top') {
		$y = PerlPanel::panel->allocation->height;
	} else {
		$y = PerlPanel::screen_height() - $self->{window}->allocation->height - PerlPanel::panel->allocation->height;
	}
	$self->{window}->move($x, $y);
	$self->{window}->show_all;
	return 1;
}

sub hide_calendar {
	my $self = shift;
	$self->{window}->hide;
}

sub show_events {
	my ($self, $year, $month, $day) = @_;
	my $date = sprintf("%04d-%02d-%02d\n", $year, $month, $day);
	return 1;
}

sub add_event_dialog {
	my $self = shift;
	my ($year, $month, $day) = $self->{calendar}->get_date;
	my ($mins, $hours) = (localtime())[1,2];
	$self->{glade}->get_widget('add_dialog_date_label')->set_markup(sprintf(_('<span weight="bold" size="large">Add Event for %04d-%02d-%02d:</span>'), $year, $month+1, $day));
	$self->{glade}->get_widget('hour_spin')->set_value($hours);
	$self->{glade}->get_widget('min_spin')->set_value($mins);
	$self->{glade}->get_widget('reminder_combo')->set_active(0);
	$self->{glade}->get_widget('add_event_dialog')->set_position('center');
	$self->{glade}->get_widget('add_event_dialog')->show_all;
	return 1;
}

1;
