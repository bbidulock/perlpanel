# $Id: BatteryMonitor.pm,v 1.12 2005/01/06 16:25:52 jodrell Exp $
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
# Copyright: (C) 2003-2005 Eric Andreychek <eric@openthought.net>
#
# ACPI support originally written by Waider (www.waider.ie), modified to work
# with PerlPanel/BatteryMonitor by Eric Andreychek.
# 

package PerlPanel::Applet::BatteryMonitor;
use strict;

$PerlPanel::Applet::BatteryMonitor::VERSION = 0.05;

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
	PerlPanel::add_timeout($self->{config}->{interval}, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;
		my ($apm, $charge);
		my $ac_status = -1;
		eval {
			$apm = Sys::Apm_ACPI->new;
			if (defined($apm)) {
				$ac_status = $apm->ac_status;
				$charge = $apm->charge;
			}
			else {
				return undef;
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

package Sys::Apm_ACPI;

# Sys::Apm - Perl extension for APM

# Copyright 2003 by Raoul Zwart

# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself. 

use strict;
use warnings;

our $VERSION = 0.20;

sub new {
	my $class = shift;
	my $self = {};
	bless ( $self, $class );
	$self->fetch;
	return $self;
}

sub fetch {
	my $self = shift;

	my $a;
    	if ( open( APM, "/proc/apm" )) {
        	$a = <APM>;
        	close( APM );
    	} elsif ( -d "/proc/acpi/battery" ) {
        	$a = acpi_to_apm();
	}
	chomp($a);

	unless ($a) {
		warn "Error: APM or ACPI support not detected";
		return 0;
	}
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
	substr($self->{data}[6],-1,1) eq "%" ? $self->{data}[6] :
					       $self->{data}[6] . '%';
}

sub remaining {
	my $self = shift;
	$self->{data}[7];
}

sub units {
	my $self = shift;
	$self->{data}[8];
}

# This sub written by Waider
#   Waider 26/09/2000
#   http://www.waider.ie/hacks/workshop/perl/Monitor/APM.pm
sub acpi_to_apm {
    # Convert the info in /proc/acpi/battery/* into an APM string. Loses info, but screw that!
    my $apm;
    my ( $drvver, $biosver, $flags, $acstat, $btstat, $btflag, $btpercent, $bttime, $bttime_unit )
      = ( "1.4", "1.1", 0, 0, 0, 0, -1, -1, "?" );

    # here's the output for a battery:
    # present:                 yes
    # design capacity:         54719 mWh
    # last full capacity:      53913 mWh
    # battery technology:      rechargeable
    # design voltage:          14399 mV
    # design capacity warning: 5391 mWh
    # design capacity low:     3235 mWh
    # capacity granularity 1:  2 mWh
    # capacity granularity 2:  2 mWh
    # model number:            Primary
    # serial number:           1FA50011
    # battery type:            LIon
    # OEM info:                 COMPAQ
    # present:                 yes
    # capacity state:          ok
    # charging state:          unknown
    # present rate:            0 mW
    # remaining capacity:      52530 mWh
    # present voltage:         16875 mV
    #
    # when not on mains, charging state => discharging and present rate => rate of discharge

    # get the ac adapter state for acstat
    if ( opendir( DIR, "/proc/acpi/ac_adapter" )) {
        for my $dir ( grep !/^\.\.?$/, readdir( DIR )) {
            if ( open( ACPI, "/proc/acpi/ac_adapter/$dir/state" )) {
                my $state = <ACPI>;
                $acstat |= 0x1 if $state =~ /on-line/;
                close( ACPI );
            } else {
                warn "Error: Failed to get AC $dir state: $!\n";
		return 0;
            }
        }
    }

    opendir( DIR, "/proc/acpi/battery" );
    my @batteries = grep !/^\.\.?$/, readdir( DIR );
    closedir( DIR );

    my ( $max, $lev, $low, $crit, $rate ) = ( 0, 0, 0, 0, 0 );

    for my $battery ( @batteries ) {
        open( BATT, "/proc/acpi/battery/$battery/info" );
        my @bits = <BATT>;
        next unless $bits[0] =~ /yes/;

        close( BATT );

        open( BATT, "/proc/acpi/battery/$battery/state" );
        push @bits, <BATT>;
        close( BATT );

        for my $bits ( @bits, @bits ) { # stupidity!
            chomp( $bits );
            my ( $field, $value ) = split( /:\s*/, $bits, 2 );
            $value =~ s/\s+$//;
            if ( $field eq "last full capacity" ) { #"design capacity" ) {
                ( $max ) = $value =~ /(\d+)/;
            } elsif ( $field eq "remaining capacity" ) {
                ( $lev ) = $value =~ /(\d+)/;
            } elsif ( $field eq "design capacity warning" ) {
                ( $low ) = $value =~ /(\d+)/;
            } elsif ( $field eq "design capacity low" ) {
                ( $crit ) = $value =~ /(\d+)/;
            } elsif ( $field eq "charging state" ) {
                if ( $value eq "unknown" ) {
                    $btstat = 0xff;
                    $btflag = 0xff;
                } elsif ( $value eq "discharging" ) {
                    if ( $lev ) {
                        if ( $lev > $low ) {
                            $btflag = 0x00;
                            $btstat |= 0x1;
                        } elsif ( $lev > $crit ) {
                            $btflag = 0x01;
                            $btstat |= 0x2;
                        } else {
                            $btflag = 0x02;
                            $btstat |= 0x4;
                        }
                    }
                } elsif ( $value eq "charging" ) {
                    $btstat = 0x03;
                    $btflag |= 0x8;
                    $acstat |= 0x1; # xxx check power_resource
                } elsif ( $value eq "charged" ) {
                    $btstat = 0x00;
                    $btflag |= 0x1;
                    $acstat |= 0x1;
                }
            } elsif ( $field eq "present rate" ) {
                ( $rate ) = $value =~ /(\d+)/;
            }
        }
        last;                   # XXX
    }

    $btpercent = sprintf( "%02d", $lev / $max * 100 ) if ( $max );

    if ( $rate ) {
        $bttime_unit = "min";
        $bttime = ( $lev - $crit ) / $rate * 60;
    }

    $apm = sprintf( "%s %s 0x%02x 0x%02x 0x%02x 0x%02x %s %d %s",  $drvver, $biosver, $flags, $acstat, $btstat, $btflag, $btpercent, $bttime, $bttime_unit );

    return $apm;
}

1;
__END__

