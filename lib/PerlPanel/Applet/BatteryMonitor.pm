# $Id: BatteryMonitor.pm,v 1.8 2004/09/17 11:28:53 jodrell Exp $
# This file is part of PerlPanel.
# 
# PerlPanel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PerlPanel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PerlPanel; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# Copyright: (C) 2003-2004 Eric Andreychek <eric@openthought.net>
#
package PerlPanel::Applet::BatteryMonitor;
use strict;

$PerlPanel::Applet::BatteryMonitor::VERSION = 0.01;

sub new {
	my $self			= {};
	$self->{package}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::EventBox->new;
	$self->{label}= Gtk2::Label->new();
	$self->{widget}->add($self->{label});
	$self->{config} = PerlPanel::get_config('BatteryMonitor');
	PerlPanel::tips->set_tip($self->{widget}, 'Battery Monitor');
	$self->widget->show_all;
	$self->update;
	Glib::Timeout->add($self->{config}->{interval}, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;
		my ($apm, $charge);
		my $ac_status = -1;
		eval {
			$apm = Sys::Apm->new;
			if (defined($apm)) {
				$ac_status = $apm->ac_status;
				$charge = $apm->charge;
			}
		};
		my $status_symbol;
		if ( $ac_status == 1 ) {
			$status_symbol = " | ";
			PerlPanel::tips->set_tip($self->{widget},
				_('The system is running on AC power'));
		}
		elsif ( $ac_status == 0 ) {
			$status_symbol = " * ";
			PerlPanel::tips->set_tip($self->{widget},
				_('The system is running on battery power'));
		}
		elsif ( $ac_status == 2 ) {
			$status_symbol = " - ";
			PerlPanel::tips->set_tip($self->{widget},
				_('The system is running on backup power'));
		}
		else {
			$status_symbol = " ? ";
			PerlPanel::tips->set_tip($self->{widget},
				_('Unknown status'));
		}

	$self->{label}->set_text($charge . $status_symbol );
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
	return 'end';
}

sub get_default_config {
	return { interval => 1000 }
}

1;

package Sys::Apm;

# Sys::Apm - Perl extension for APM

# Copyright 2003 by Raoul Zwart

# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself. 

use strict;
use warnings;

our $VERSION = 0.05;

sub new {
	my $cls = shift;
	my $self = {proc=>'/proc/apm'};
	unless (-f $self->{proc}) { return }
	bless $self => $cls;
	$self->fetch;
	$self;
}

sub fetch {
	my $self = shift;
	open(APM,$self->{proc})or return;
	my $a = <APM>;
	chomp($a);
	close APM;
	unless ($a) { return }
	$self->parse($a);
}

sub parse {
	my $self = shift;
	my $str = shift;
	$self->{data}=[split / /, $str];
}

sub driver_version {
	my $self = shift;
	$self->{data}[0];
}

sub bios_version {
	my $self = shift;
	$self->{data}[1];
}

sub ac_status {
	my $self = shift;
	hex($self->{data}[3]);
}

sub battery_status {
	my $self = shift;
	hex($self->{data}[4]);
}

sub charge {
	my $self = shift;
	$self->{data}[6];
}

sub remaining {
	my $self = shift;
	$self->{data}[7];
}

sub units {
	my $self = shift;
	$self->{data}[8];
}

1;
__END__

