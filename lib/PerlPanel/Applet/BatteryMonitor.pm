# $Id: BatteryMonitor.pm,v 1.2 2003/08/12 16:03:14 jodrell Exp $
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

package PerlPanel::Applet::BatteryMonitor;

###########################################################################
# Battery Applet for Perl Panel
#
# Author: Eric Andreychek <eric@openthought.net>
#           Based on LoadMonitor by Gavin Brown
#           Sys::Apm by Raoul Zwart
#
# Description: Monitor the battery for your laptop using the APM support in the
#              kernel.  Internally, this uses /proc/apm.
#
#
# Todo: This should definitely support icons, instead of text based symbols.
#
###########################################################################

use strict;

$PerlPanel::Applet::BatteryMonitor::VERSION = 0.01;

sub new {
    my $self            = {};
    $self->{package}    = shift;
    bless($self, $self->{package});
    return $self;
}

sub configure {
    my $self = shift;
    $self->{widget} = Gtk2::Button->new;
    $self->{widget}->set_relief('none');
    $self->{label}= Gtk2::Label->new();
    $self->{widget}->add($self->{label});
    $self->{widget}->signal_connect('clicked', sub { $self->prefs });
    $PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Battery Monitor');
    $self->update;
    Glib::Timeout->add($PerlPanel::OBJECT_REF->{config}{appletconf}{BatteryMonitor}{interval}, sub { $self->update });
    return 1;

}

sub update {
    my $self = shift;
        my $apm = Sys::Apm->new or $PerlPanel::OBJECT_REF->error("No APM support in kernel", sub { exit }) and return undef;
        my $ac_status = $apm->ac_status;
        my $status_symbol;
        if ( $ac_status == 1 ) {
            $status_symbol = " | ";
            $PerlPanel::TOOLTIP_REF->set_tip($self->{widget},
                                    'The system is running on AC power');
        }
        elsif ( $ac_status == 0 ) {
            $status_symbol = " * ";
            $PerlPanel::TOOLTIP_REF->set_tip($self->{widget},
                                    'The system is running on battery power');
        }
        elsif ( $ac_status == 2 ) {
            $status_symbol = " - ";
            $PerlPanel::TOOLTIP_REF->set_tip($self->{widget},
                                    'The system is running on backup power');
        }
        else {
            $status_symbol = " ? ";
            $PerlPanel::TOOLTIP_REF->set_tip($self->{widget},
                                    'Unknown status');
        }

    $self->{label}->set_text( $apm->charge . $status_symbol );
    return 1;
}

sub prefs {
    my $self = shift;
    $self->{widget}->set_sensitive(0);
    $self->{window} = Gtk2::Dialog->new;
    $self->{window}->set_title("$PerlPanel::NAME: BatteryMonitor Configuration");
    $self->{window}->signal_connect('delete_event', sub { $self->{widget}->set_sensitive(1) });
    $self->{window}->set_border_width(8);
    $self->{window}->vbox->set_spacing(8);
    $self->{window}->set_icon($PerlPanel::OBJECT_REF->icon);
    $self->{table} = Gtk2::Table->new(3, 2, 0);
    $self->{table}->set_col_spacings(8);
    $self->{table}->set_row_spacings(8);

    my $adj = Gtk2::Adjustment->new($PerlPanel::OBJECT_REF->{config}{appletconf}{BatteryMonitor}{interval}, 100, 60000, 1, 1000, undef);
    $self->{controls}{interval} = Gtk2::SpinButton->new($adj, 1, 0);

    $self->{labels}{interval} = Gtk2::Label->new('Update interval (ms):');
    $self->{labels}{interval}->set_alignment(1, 0.5);
    $self->{table}->attach_defaults($self->{labels}{interval}, 0, 1, 2, 3);
    $self->{table}->attach_defaults($self->{controls}{interval}, 1, 2, 2, 3);

    $self->{window}->add_buttons(
        'gtk-cancel', 1,
        'gtk-ok', 0,
    );

    $self->{window}->signal_connect('response', sub {
        if ($_[1] == 0) {
            # 'ok' was clicked
            $PerlPanel::OBJECT_REF->{config}{appletconf}{BatteryMonitor}{interval}    = $self->{controls}{interval}->get_value_as_int;
            $self->{widget}->set_sensitive(1);
            $self->{window}->destroy;
            $PerlPanel::OBJECT_REF->save_config;
            $PerlPanel::OBJECT_REF->reload;
        } elsif ($_[1] == 1) {
            $self->{widget}->set_sensitive(1);
            $self->{window}->destroy;
        }
    });

    $self->{window}->vbox->pack_start($self->{table}, 1, 1, 0);

    $self->{window}->show_all;

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

