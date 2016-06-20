# $Id: WiFiMonitor.pm,v 1.8 2005/01/21 18:14:15 jodrell Exp $
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
# Copyright: (C) 2004-2005 Nathan Powell <nathan@lagerbottom.com>
#
package PerlPanel::Applet::WiFiMonitor;
use vars qw($MULTI);

use strict;

$MULTI = 1;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}	        = shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('WiFiMonitor', $self->{id});
	$self->{widget} = Gtk2::EventBox->new;
	$self->widget->set_border_width(0);

	if ($self->{config}{show_icon} eq 'true' and
            $self->{config}{show_percent} eq 'true' ) {
		my $icon = PerlPanel::get_applet_pbf('WiFiMonitor', PerlPanel::icon_size);
                $self->{icon} = Gtk2::Image->new_from_pixbuf($icon);
		$self->{label} = Gtk2::Label->new;
		$self->widget->add(Gtk2::HBox->new);

		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start($self->{label}, 1, 1, 0);

	}
        elsif ( $self->{config}{show_percent} eq 'true' ) {
		$self->{label}= Gtk2::Label->new();
		$self->{widget}->add($self->{label});
	}
        else {
		my $icon = PerlPanel::get_applet_pbf('WiFiMonitor', PerlPanel::icon_size);
                $self->{icon} = Gtk2::Image->new_from_pixbuf($icon);
		$self->{label} = Gtk2::Label->new;
		$self->widget->add(Gtk2::HBox->new);

		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);

        }

	PerlPanel::tips->set_tip($self->{widget}, _('Wireless Signal Strength'));
	$self->widget->show_all;
	$self->update;
	PerlPanel::add_timeout($self->{config}->{interval}, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;

	my ( $signal, $device );
	if (!open(WIRELESS, '/proc/net/wireless')) {
		print STDERR "*** Error opening '/proc/net/wireless': $!\n";
		$self->{label}->set_text('ERR');
                $self->_set_icon("broken-0.png");
		return undef;
	} else {
                my $count = 1;
		while (my $wireless = <WIRELESS>) {
                    if ( $count == 1 or $count == 2 ) {
                        $count++;
                        next;
                    }
                    $count++;

                    if ( $self->{config}{device} ) {
                        if ( $wireless =~ /^\s*$self->{config}{device}:/ ) {
                            $device = $self->{config}{device};
                            ( $signal ) = $wireless =~ /^\s*$self->{config}{device}:\s+\d+\s+(\d+)/;
                            last;
                        }
                    }
                    else {
                        ($device, $signal) =
                                $wireless =~ /^\s*(\w+\d):\s+\d+\s+(\d+)/;
                        last;
                    }
		}
		close(WIRELESS);

        }

        if ( $device and $signal ) {
            my $percent = sprintf("%d%", log($signal) / log(92) * 100);
            $self->{label}->set_text($percent);
            PerlPanel::tips->set_tip($self->{widget}, _("Wireless Signal Strength for $device: $percent"));

            if ( $percent == 0 ) {
                $self->_set_icon("no-link-0.png");
            }
            elsif ( $percent >= 1 and $percent <= 40 ) {
                $self->_set_icon("signal-1-40.png");
            }
            elsif ( $percent >= 41 and $percent <= 60 ) {
                $self->_set_icon("signal-41-60.png");
            }
            elsif ( $percent >= 61 and $percent <= 80 ) {
                $self->_set_icon("signal-61-80.png");
            }
            elsif ( $percent >= 81 and $percent <= 100 ) {
                $self->_set_icon("signal-81-100.png");
            }
        }
        else {
            $self->{label}->set_text('ERR');
            $self->_set_icon("broken-0.png");
            return undef;
        }
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
		interval        => 1000,
		show_icon       => 'true',
		show_percent    => 'true',
                device          => '',
	};
}

sub _set_icon {
    my ( $self, $icon ) = @_;

    return unless $self->{config}{show_icon} eq 'true';

    my $image_dir = sprintf('%s/share/%s/applets/wifimonitor', $PerlPanel::PREFIX, lc($PerlPanel::NAME));
    $self->{icon}->set_from_file("$image_dir/$icon");
    $self->{widget}->queue_draw;
}

1;

