# $Id: Clock.pm,v 1.23 2004/09/24 14:49:13 jodrell Exp $
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
use POSIX qw(strftime);
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
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
	$self->{config} = PerlPanel::get_config('Clock');
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
	$self->{calendar} = Gtk2::Window->new;
	$self->{calendar}->set_icon(PerlPanel::icon);
	$self->{calendar}->set_title(_('Calendar'));
	$self->{calendar}->set_skip_pager_hint(1);
	$self->{calendar}->set_skip_taskbar_hint(1);
	$self->{calendar}->set_decorated(undef);
	$self->{calendar}->set_type_hint('dialog');
	$self->{calendar}->add(Gtk2::Viewport->new);
	$self->{calendar}->child->set_shadow_type('out');
	$self->{calendar}->child->add(Gtk2::VBox->new);
	$self->{calendar}->child->child->set_border_width(6);
	$self->{calendar}->child->child->add(Gtk2::Calendar->new);
	$self->{calendar}->child->show_all;
	$self->{calendar}->realize;
}

sub show_calendar {
	my $self = shift;
	my ($x, $y);
	my $x0 = (PerlPanel::get_widget_position($self->widget))[0];
	if ($x0 + $self->{calendar}->allocation->width > PerlPanel::screen_width) {
		$x = PerlPanel::screen_width() - $self->{calendar}->allocation->width;
	} else {
		$x = $x0;
	}
	if (PerlPanel::position eq 'top') {
		$y = PerlPanel::panel->allocation->height;
	} else {
		$y = PerlPanel::screen_height() - $self->{calendar}->allocation->height - PerlPanel::panel->allocation->height;
	}
	$self->{calendar}->move($x, $y);
	$self->{calendar}->show_all;
	return 1;
}

sub hide_calendar {
	my $self = shift;
	$self->{calendar}->hide;
}

1;
