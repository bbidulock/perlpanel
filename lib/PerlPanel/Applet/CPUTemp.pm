# $Id: CPUTemp.pm,v 1.5 2004/11/04 16:12:01 jodrell Exp $
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
# This applet is based on code written by Harm Reck <reck.harm@web.de>.
#
package PerlPanel::Applet::CPUTemp;
use Gtk2::Helper;
use Gtk2::SimpleList;
use vars qw(%SYMBOLS $DELL_FILE);
use strict;

our %SYMBOLS = (
	fahrenheit => '&#176;F',
	celsius => '&#176;C',
	kelvin => 'K',	
);

# this /proc file is where dell systems keep the CPU temperature:
our $DELL_FILE = '/proc/i8k';


sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('CPUTemp');

	$self->{label} = Gtk2::Label->new;
	$self->label->set_use_markup(1);

	$self->{box} = Gtk2::HBox->new;
	$self->{box}->pack_start(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('CPUTemp', PerlPanel::icon_size)), 0, 0, 0);
	$self->{box}->pack_start($self->label, 0, 0, 0);

	$self->{widget} = Gtk2::Button->new;
	$self->widget->signal_connect('clicked', sub { $self->dialog });
	$self->widget->set_relief('none');
	$self->widget->add($self->{box});

	$self->widget->show_all;

	$self->update;
	PerlPanel::add_timeout($self->{config}->{interval}, sub { $self->update ; return 1 });

	return 1;
}

sub update {
	my $self = shift;
	if (-r $DELL_FILE) {
		return $self->update_dell;
	} else {
		return $self->update_mbmon;
	}
}

sub update_mbmon {
	my $self = shift;
	$self->{command} = 'mbmon -c 1'.($self->{config}->{units} eq 'fahrenheit' ? ' -f' : '');
	if (!open(COMMAND, "$self->{command}|")) {
		$self->label->set_markup('ERR');
		PerlPanel::tips->set_tip($self->widget, _("Error opening '{command}': {error}", command => $self->{command}, error => $!));
		return undef;
	} else {
		my ($tag, $buffer);
		$tag = Gtk2::Helper->add_watch(fileno(COMMAND), 'in', sub {
			if (eof(COMMAND)) {
				close(COMMAND);
				Gtk2::Helper->remove_watch($tag);
				my $line = (split(/[\r\n]/, $buffer))[1];
				my $temp = (split(/\s+/, $line))[2];
				$temp =~ s/[^0-9\.]//g;
				if ($self->{config}->{units} eq 'kelvin') {
					$temp += 273.15;
				}
				PerlPanel::tips->set_tip($self->widget, _('CPU Temperature'));
				$self->label->set_markup(sprintf('%d%s', $temp, $SYMBOLS{$self->{config}->{units}}));
			} else {
				$buffer .= <COMMAND>;
			}
		});
		return 1;
	}
}

sub update_dell {
	my $self = shift;

	open(DELLINFO, $DELL_FILE);
	my $temp = (split(/\s+/, <DELLINFO>))[3];
	close(DELLINFO);

	if ($self->{config}->{units} eq 'fahrenheit') {
		$temp = $self->celsius_to_fahrenheit($temp);

	} elsif ($self->{config}->{units} eq 'kelvin') {
		$temp = $self->celsius_to_kelvin($temp);

	}

	PerlPanel::tips->set_tip($self->widget, _('CPU Temperature'));
	$self->label->set_markup(sprintf('%d%s', $temp, $SYMBOLS{$self->{config}->{units}}));
	return 1;
}

sub dialog {
	my $self = shift;
	$self->widget->set_sensitive(0);

	my $list = Gtk2::SimpleList->new('units' => 'text');
	@{$list->{data}} = sort keys %SYMBOLS;

	my $glade = PerlPanel::load_glade('cputemp');
	$glade->get_widget('units')->set_model($list->get_model);

	my $i = 0;
	foreach my $unit (@{$list->{data}}) {
		if (@{$unit}[0] eq $self->{config}->{units}) {
			$glade->get_widget('units')->set_active($i);
		}
		$i++;
	}

	$glade->get_widget('config_dialog')->set_icon(PerlPanel::icon);
	my $callback = sub {
		my ($dialog, $response) = @_;
		if ($response eq 'ok') {
			$self->{config}->{units} = @{@{$list->{data}}[$glade->get_widget('units')->get_active]}[0];
			PerlPanel::save_config;
			$self->update;
		}
		$self->widget->set_sensitive(1);
		$dialog->destroy;
	};
	$glade->get_widget('config_dialog')->signal_connect('response', $callback);
	$glade->get_widget('config_dialog')->signal_connect('delete_event', $callback);
	return 1;
}

sub label {
	return $_[0]->{label};
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
		interval => 10*1000,
		units => 'celsius',
	};
}

sub celsius_to_fahrenheit {
	my ($self, $celsius) = @_;
	return ($celsius * 1.8) + 32;
}

sub celsius_to_kelvin {
	my ($self, $celsius) = @_;
	return $celsius + 273.15;
}

1;
