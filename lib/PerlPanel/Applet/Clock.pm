# $Id: Clock.pm,v 1.35 2005/04/14 14:14:02 jodrell Exp $
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
use POSIX;
use vars qw($MULTI %REMINDERS $REMINDER_DIALOG_FMT);
use Date::Parse;
use strict;

#
# Please note that month values are zero-indexed throughout this applet,
# since all Perl's various date manipulation functions use zero-indexed
# months, and so does GtkCalendar.
#

our %REMINDERS = (
	-1	=> _('No reminder'),
	5	=> _('{mins} minutes before', mins => 5),
	15	=> _('{mins} minutes before', mins => 15),
	30	=> _('{mins} minutes before', mins => 30),
	60	=> _('1 hour before'),
	120	=> _('2 hours before'),
);

our $REMINDER_DIALOG_FMT = "<span weight=\"bold\" size=\"x-large\">%s</span>\n\n%s";

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self,		$self->{package});
	return			$self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Clock');
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

	$self->{glade}->get_widget('reminder_dialog')->signal_connect('response', sub {
		$self->{glade}->get_widget('reminder_dialog')->hide;
		return 1;
	});
	$self->{glade}->get_widget('reminder_dialog')->signal_connect('delete_event', sub {
		$self->{glade}->get_widget('reminder_dialog')->hide;
		return 1;
	});
	$self->{glade}->get_widget('reminder_dialog')->set_icon(PerlPanel::icon);

	PerlPanel::add_timeout(1000, sub { $self->update });
	$self->widget->show_all;
	return 1;
}

sub update {
	my $self = shift;
	$self->{label}->set_text(' '.my_strftime($self->{config}{format}, time()).' ');
	PerlPanel::tips->set_tip($self->widget, my_strftime($self->{config}{date_format}, time()));
	$self->show_reminders;
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

	$self->{events}->signal_connect('button_press_event', sub {
		if ($_[1]->type eq '2button-press' && $_[1]->button == 1) {
			$self->edit_event;
		}
	});

	$self->{events}->get_selection->signal_connect('changed', sub {
		if ($_[0]->count_selected_rows == 0) {
			$self->{glade}->get_widget('delete_buttonbox')->hide;
		} else {
			$self->{glade}->get_widget('delete_buttonbox')->show;
		}
	});


	$self->{glade}->get_widget('add_button')->signal_connect('clicked', sub { $self->add_event_dialog });
	$self->{glade}->get_widget('delete_button')->signal_connect('clicked', sub { $self->delete_event_dialog });

	$self->{window}->child->show;
	$self->{window}->realize;

	$self->{model} = Gtk2::ListStore->new(qw(Glib::String Glib::String));
	foreach my $mins (sort { $a <=> $b } keys %REMINDERS) {
		$self->{model}->set($self->{model}->append, 0, $mins, 1, $REMINDERS{$mins});
	}

	$self->{combo} = Gtk2::ComboBox->new;
	$self->{combo}->visible(1);

	$self->{glade}->get_widget('reminder_combo_placeholder')->add($self->{combo});

	$self->{combo}->set_model($self->{model});

	my $renderer = Gtk2::CellRendererText->new;
	$self->{combo}->pack_start($renderer, undef);
	$self->{combo}->set_attributes($renderer, 'text' => 1);

	$self->{edit_combo} = Gtk2::ComboBox->new;
	$self->{edit_combo}->visible(1);

	$self->{glade}->get_widget('edit_event_reminder_combo_placeholder')->add($self->{edit_combo});

	$self->{edit_combo}->set_model($self->{model});

	my $renderer = Gtk2::CellRendererText->new;
	$self->{edit_combo}->pack_start($renderer, undef);
	$self->{edit_combo}->set_attributes($renderer, 'text' => 1);

	$self->{glade}->get_widget('edit_event_dialog')->signal_connect('delete_event', sub {
		$self->{glade}->get_widget('edit_event_dialog')->hide;
		return 1;
	});

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
	$self->{window}->show;
	return 1;
}

sub hide_calendar {
	my $self = shift;
	$self->{window}->hide;
}

sub show_events {
	my ($self, $year, $month, $day) = @_;
	my @events = $self->get_events_for($year, $month, $day);

	@{$self->{events}->{data}} = ();
	foreach my $event (@events) {
		push(@{$self->{events}->{data}}, [ $event->{time}, $event->{notes} ]);
	}

	return 1;
}

sub get_events_for {
	my ($self, $year, $month, $day) = @_;

	my $date = sprintf("%04d-%02d-%02d", $year, $month, $day);
	my @events;

	# munge the reference:
	if (ref($self->{config}->{events}) ne 'ARRAY') {
		$self->{config}->{events} = [ $self->{config}->{events} ];
	}

	return sort { $a->{time} cmp $b->{time} } grep { $_->{date} eq $date }  @{$self->{config}->{events}};
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

	if (!defined($self->{callback_ids}->{add_dialog_delete_event})) {
		$self->{callback_ids}->{add_dialog_delete_event} = $self->{glade}->get_widget('add_event_dialog')->signal_connect(
			'delete_event',
			sub {
				$self->{glade}->get_widget('add_event_dialog')->hide;
				return 1;
			}
		);
	}

	if (!defined($self->{callback_ids}->{add_dialog_response})) {
		$self->{callback_ids}->{add_dialog_response} = $self->{glade}->get_widget('add_event_dialog')->signal_connect(
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
				$self->{glade}->get_widget('add_event_dialog')->hide;
				return 1;
			}
		);
	}

	return 1;
}

sub delete_event_dialog {
	my $self = shift;
	my ($year, $month, $day) = $self->{calendar}->get_date;

	my $selected_event_index = ($self->{events}->get_selected_indices)[0];
	my ($event_time, $event_text) = @{$self->{events}->{data}->[$selected_event_index]};
	my ($event_hour, $event_minute) = split /:/, $event_time;
	
	$self->{deleted_event} = {date => sprintf ('%04d-%02d-%02d', $year, $month, $day),   # Date
	                          time => sprintf ('%02d:%02d', $event_hour, $event_minute), # Time
	                          notes => $event_text};                                     # Note

	$self->{glade}->get_widget('delete_dialog_title')->set_markup(sprintf(_('<span weight="bold" size="large">Delete Event for %02d:%02d %04d-%02d-%02d:</span>'), $event_hour, $event_minute, $year, $month+1, $day));
	$self->{glade}->get_widget('delete_dialog_text')->set_label($event_text);
	
	$self->{glade}->get_widget('delete_event_dialog')->set_position('center');
	$self->{glade}->get_widget('delete_event_dialog')->set_modal(1);
	$self->{glade}->get_widget('delete_event_dialog')->show;
	$self->setup_delete_event_dialog_callbacks;

	return 1;
}

sub setup_delete_event_dialog_callbacks {
	my $self = shift;

	if (!defined($self->{callback_ids}->{delete_dialog_delete_event})) {
		$self->{callback_ids}->{delete_dialog_delete_event} = $self->{glade}->get_widget('delete_event_dialog')->signal_connect(
			'delete_event',
			sub {
				$self->{glade}->get_widget('delete_event_dialog')->hide;
				return 1;
			}
		);
	}

	if (!defined($self->{callback_ids}->{delete_dialog_response})) {
		$self->{callback_ids}->{delete_dialog_response} = $self->{glade}->get_widget('delete_event_dialog')->signal_connect(
			'response',
			sub {
				if ($_[1] eq 'ok') {
					my $deleted_index = 0;
					for (@{$self->{config}->{events}}) {
						if ($_->{date} eq $self->{deleted_event}->{date} &&
						  $_->{time} eq $self->{deleted_event}->{time} &&
						  $_->{notes} eq $self->{deleted_event}->{notes}) {
							splice(@{$self->{config}->{events}}, $deleted_index, 1);
							delete($self->{deleted_event});
						}
						$deleted_index += 1;
					}
					
					$self->show_events($self->{calendar}->get_date);
					PerlPanel::save_config;
				}
				$self->{glade}->get_widget('delete_event_dialog')->hide;
				return 1;
			}
		);
	}

	return 1;
}


sub show_reminders {
	my $self = shift;

	my $now = time();

	foreach my $event (grep { $_->{reminder} > 0 && defined($_->{date}) } @{$self->{config}->{events}}) {
		my $timestamp = $self->get_timestamp_for($event);
		if ($event->{reminder} > 0 && ($timestamp - ($event->{reminder} * 60)) < $now && $event->{reminded} ne 'true' && $event->{notes} ne '') {
			$event->{reminded} = 'true';
			PerlPanel::save_config();
			$self->reminder($event);
		}
	}

	return 1;
}

sub reminder {
	my ($self, $event) = @_;
	$self->{glade}->get_widget('reminder_dialog_label')->set_markup(sprintf(
		$REMINDER_DIALOG_FMT,
		_('Event Reminder'),
		_(
			'You asked to be reminded about the following event, which takes place on {date}:',
			date => my_strftime(_('%Y-%m-%d at %H:%M'), $self->get_timestamp_for($event))
		),
	));
	$self->{glade}->get_widget('reminder_dialog_notes_label')->set_text($event->{notes});
	$self->{glade}->get_widget('reminder_dialog')->show;
	return 1;
}

sub get_timestamp_for {
	my ($self, $event) = @_;
	my ($year, $month, $day) = split(/-/, $event->{date}, 3);
	my ($hour, $min) = split(/:/, $event->{time}, 2);
	return strtotime(sprintf('%04d-%02d-%02d %02d:%02d:00', $year, $month+1, $day, $hour, $min));
}

sub my_strftime {
	my ($fmt, $timestamp) = @_;
	return POSIX::strftime($fmt, localtime($timestamp));
}

sub strtotime {
	my $str = shift;
	return str2time($str);
}

sub edit_event {
	my $self = shift;
	my ($idx) = $self->{events}->get_selected_indices;
	my @events = $self->get_events_for($self->{calendar}->get_date);

	my $event = $events[$idx];

	if (defined($self->{edit_handler_id})) {
		$self->{glade}->get_widget('edit_event_dialog')->signal_handler_disconnect($self->{edit_handler_id});
	}
	$self->{edit_handler_id} = $self->{glade}->get_widget('edit_event_dialog')->signal_connect('response', sub {

		if ($_[1] eq 'ok') {
			$event->{time} = sprintf(
				'%02d:%02d',
				$self->{glade}->get_widget('edit_event_hour')->get_value_as_int,
				$self->{glade}->get_widget('edit_event_minute')->get_value_as_int,
			);
			$event->{notes} = $self->{glade}->get_widget('edit_event_notes')->get_buffer->get_text(
				$self->{glade}->get_widget('edit_event_notes')->get_buffer->get_start_iter,
				$self->{glade}->get_widget('edit_event_notes')->get_buffer->get_end_iter,
				undef,
			);
			$event->{reminder} = $self->{edit_combo}->get_model->get($self->{edit_combo}->get_active_iter, 0);
			$event->{reminded} = 'false';
			PerlPanel::save_config;
			$self->show_events($self->{calendar}->get_date);
		}

		$self->{glade}->get_widget('edit_event_dialog')->hide;
		$self->{glade}->get_widget('edit_event_dialog')->signal_handler_disconnect($self->{edit_handler_id});
		undef($self->{edit_handler_id});
	});

	my ($hour, $min) = split(/:/, $event->{time}, 2);
	$self->{glade}->get_widget('edit_event_hour')->set_value($hour);
	$self->{glade}->get_widget('edit_event_minute')->set_value($min);
	$self->{glade}->get_widget('edit_event_notes')->get_buffer->set_text($event->{notes});
	my $i = 0;
	foreach my $reminder (sort { $a <=> $b } keys %REMINDERS) {
		if ($reminder == $event->{reminder}) {
			$self->{edit_combo}->set_active($i);
			last;
		} else {
			$i++;
		}
	}

	$self->{glade}->get_widget('edit_event_dialog')->set_position('center');
	$self->{glade}->get_widget('edit_event_dialog')->show;

	return 1;
}

1;
