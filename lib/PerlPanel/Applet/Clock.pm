# $Id: Clock.pm,v 1.27 2004/10/26 16:17:20 jodrell Exp $
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
use vars qw($MULTI %REMINDERS);
use strict;

our $MULTI = 1;

our %REMINDERS = (
	-1	=> _('No reminder'),
	5	=> _('{mins} minutes before', mins => 5),
	15	=> _('{mins} minutes before', mins => 15),
	30	=> _('{mins} minutes before', mins => 30),
	60	=> _('1 hour before'),
	120	=> _('2 hours before'),
);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self,		$self->{package});
	return			$self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Clock', $self->{id});
	$self->{label} = Gtk2::Label->new;
	$self->{widget} = Gtk2::ToggleButton->new;
	$self->widget->set_relief('none');
	$self->widget->add($self->{label});
	$self->make_calendar;
	$self->widget->signal_connect('clicked', sub {
		if ($self->widget->get_active) {
			$self->show_calendar;
			$self->show_events($self->{calendar}->get_date);
		} else {
			$self->hide_calendar;
		}
	});
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

	$self->show_events($year, $month, $day);

	$self->{events} = Gtk2::SimpleList->new_from_treeview(
		$self->{glade}->get_widget('event_list'),
		'date'	=> 'text',
		'text'	=> 'text',
	);

	$self->{glade}->get_widget('add_button')->signal_connect('clicked', sub { $self->add_event_dialog });

	$self->{window}->child->show_all;
	$self->{window}->realize;

	$self->{model} = Gtk2::ListStore->new(qw(Glib::String Glib::String));
	foreach my $mins (sort { $a <=> $b } keys %REMINDERS) {
		$self->{model}->set($self->{model}->append, 0, $mins, 1, $REMINDERS{$mins});
	}

	$self->{combo} = Gtk2::ComboBox->new;

	$self->{glade}->get_widget('reminder_combo_placeholder')->add($self->{combo});

	$self->{combo}->set_model($self->{model});

	my $renderer = Gtk2::CellRendererText->new;
	$self->{combo}->pack_start($renderer, undef);
	$self->{combo}->set_attributes($renderer, 'text' => 1);

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
	my $date = sprintf("%04d-%02d-%02d", $year, $month, $day);
	@{$self->{events}->{data}} = ();
	my %events;
	foreach my $event (@{$self->{config}->{events}}) {
		if ($event->{date} eq $date) {
			push(@{$events{$event->{time}}}, $event);
		}
	}
	foreach my $time (sort keys %events) {
		foreach my $event (@{$events{$time}}) {
			push(@{$self->{events}->{data}}, [ $time, $event->{notes} ]);
		}
	}
	return 1;
}

sub add_event_dialog {
	my $self = shift;
	my ($year, $month, $day) = $self->{calendar}->get_date;
	my ($mins, $hours) = (localtime())[1,2];
	$self->{add_event_date} = sprintf('%04d-%02d-%02d', $year, $month, $day);
	$self->{glade}->get_widget('add_dialog_date_label')->set_markup(sprintf(_('<span weight="bold" size="large">Add Event for %04d-%02d-%02d:</span>'), $year, $month+1, $day));
	$self->{glade}->get_widget('hour_spin')->set_value($hours);
	$self->{glade}->get_widget('min_spin')->set_value($mins);
	$self->{glade}->get_widget('notes_entry')->get_buffer->set_text('');
	$self->{combo}->set_active(0);
	$self->{glade}->get_widget('add_event_dialog')->set_position('center');
	$self->{glade}->get_widget('add_event_dialog')->set_modal(1);
	$self->{glade}->get_widget('add_event_dialog')->show_all;
	$self->setup_add_event_dialog_callbacks;

	return 1;
}

sub setup_add_event_dialog_callbacks {
	my $self = shift;

	if (!defined($self->{callback_ids}->{delete_event})) {
		$self->{callback_ids}->{delete_event} = $self->{glade}->get_widget('add_event_dialog')->signal_connect(
			'delete_event',
			sub {
				$self->{glade}->get_widget('add_event_dialog')->hide_all;
				return 1;
			}
		);
	}

	if (!defined($self->{callback_ids}->{response})) {
		$self->{callback_ids}->{response} = $self->{glade}->get_widget('add_event_dialog')->signal_connect(
			'response',
			sub {
				if ($_[1] eq 'ok') {
					my $hours	= $self->{glade}->get_widget('hour_spin')->get_value;
					my $mins	= $self->{glade}->get_widget('min_spin')->get_value;
					my $notes	= $self->{glade}->get_widget('notes_entry')->get_buffer->get_text(
						$self->{glade}->get_widget('notes_entry')->get_buffer->get_start_iter,
						$self->{glade}->get_widget('notes_entry')->get_buffer->get_end_iter,
						1,
					);
					my $reminder	= $self->{combo}->get_model->get($self->{combo}->get_active_iter, 0);

					if (ref($self->{config}->{events}) ne 'ARRAY') {
						$self->{config}->{events} = [ $self->{config}->{events} ];
					}
					push(@{$self->{config}->{events}}, {
						date		=> $self->{add_event_date},
						time		=> sprintf('%02d:%02d', $hours, $mins),
						reminder	=> $reminder,
						notes		=> $notes,
					});
					$self->show_events($self->{calendar}->get_date);
					PerlPanel::save_config;
				}
				$self->{glade}->get_widget('add_event_dialog')->hide_all;
				return 1;
			}
		);
	}

	return 1;
}

1;
