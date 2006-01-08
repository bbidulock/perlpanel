# $Id $
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
# Copyright: (C) 2006 Marc Brockschmidt <marc@marcbrockschmidt.de>

package PerlPanel::Applet::NetLoadMonitor;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('NetLoadMonitor');
	$self->{widget} = Gtk2::Frame->new;
	$self->{widget}->set_border_width(0);
	$self->{widget}->set_shadow_type("etched_in");
	$self->{widget}->set_size_request(-1, PerlPanel::icon_size());

	$self->{height}      = PerlPanel::icon_size();
	$self->{width}       = $self->{config}->{width};
	$self->{displayed_interface} = $self->{config}->{displayed_interface};
	$self->{data}        = {};
	$self->{traffic_data}= {};
	$self->{last_updated_row} = 0;
	
	$self->{image}     = Gtk2::Image->new();
	$self->{image}->set_padding(0,0);

	$self->{widget}->add($self->{image});

	$self->update();

	PerlPanel::tips->set_tip($self->{widget}, _('Net Interface Usage'));

	$self->update;
	$self->{'widget'}->show_all;

	PerlPanel::add_timeout($self->{config}->{update_interval} * 1000, sub { $self->update() });
	return 1;

}

sub update {
	update_data(@_);
	update_xpm(@_);
}

sub update_data {
	my $self = shift;
	my $new = {};
	open (NET, "<", "/proc/net/dev") or die ("Can't open /proc/net/dev: $!");
	$_ = <NET>, <NET>; #Skip first two lines with table headers
	while (<NET>) {
		s/^\s*([^:]+)://;
		my $interface = $1;
		s/^\s*//;
		my ($bytes_recvd, $bytes_sent) = (split /\s+/, $_)[0,8];
		$new->{$interface} = [$bytes_recvd, $bytes_sent];
	}
	close NET;
	
	for my $interface (keys %{$self->{data}}) {
		#find the difference between the old and new values (which is the traffic):
		if ($new->{$interface}) {
			my $diff_bytes_recvd = $new->{$interface}->[0] - $self->{data}->{$interface}->[0];
			my $diff_bytes_sent  = $new->{$interface}->[1] - $self->{data}->{$interface}->[1];

			#Now save the data:
			$self->{data}->{$interface}->[0] = $new->{$interface}->[0];
			$self->{data}->{$interface}->[1] = $new->{$interface}->[1];
		
			$self->{traffic_data}->{$interface}->[$self->{last_updated_row}]->[0] = $diff_bytes_recvd;
			$self->{traffic_data}->{$interface}->[$self->{last_updated_row}]->[1] = $diff_bytes_sent;

		#interface not available anymore, remove it:
		} else {
			delete $self->{data}->{$interface};
		}
	}

	$self->{last_updated_row}++;
	$self->{last_updated_row} -= $self->{width} if $self->{last_updated_row} >= $self->{width};

	#Yay, a new interface has popped into existence:
	for my $interface (keys %$new) {
		if (! $self->{data}->{$interface} ) {
			$self->{data}->{$interface} = $new->{$interface};
			
			$self->{traffic_data}->{$interface} = [];
			push @{$self->{traffic_data}->{$interface}}, [0, 0] for (1 .. $self->{width});
			$self->{traffic_data}->{$interface}->[$self->{last_updated_row}]->[0] = 0;
			$self->{traffic_data}->{$interface}->[$self->{last_updated_row}]->[1] = 0;
		}
	}
}

sub update_xpm {
	my $self = shift;

	my @xpm;

	#No data available for displayed interface (anymore)
	if (! $self->{traffic_data}->{$self->{displayed_interface}}) {
		#Create black graph:
		@xpm = ($self->{width} . " " . $self->{height} . " 1 1",
			   "  c Black",);
		push @xpm, " " x $self->{width} for (0 .. $self->{height} - 1);

	} else {
		#Find the maximal traffic in the stored data:
		my $max_value = 0;
		for (@{$self->{traffic_data}->{$self->{displayed_interface}}}) { 
			my $tmp = $_->[0] + $_->[1];
			$max_value = $tmp if $tmp > $max_value;
		};
		my $factor = int($max_value/$self->{height});
		   $factor = 60 if $factor < 60;
		
		my @row_order;
		#Go over all rows, prepare the row ordering and the xpm data:
		my @xpm_vert;
		for my $i (0 .. $self->{width}) {
			#@row_order is sorted from left to right, so we want the
			#last updated row to be the last in the array:
			my $row_nr = $self->{last_updated_row} - ($self->{width} - $i);
			   $row_nr += $self->{width} if $row_nr < 0;
			push @row_order, $row_nr;
			
			#Update the actual xpm data (we need to do this every time,
			#as $factor changes from time to time:
			my $act_percentage_recvd = int(($self->{traffic_data}->{$self->{displayed_interface}}->[$row_nr]->[0] / $factor) + 0.5);
			my $act_percentage_sent = int(($self->{traffic_data}->{$self->{displayed_interface}}->[$row_nr]->[1] / $factor) + 0.5);		
			$xpm_vert[$row_nr] = [(" ") x ($self->{height} - $act_percentage_recvd - $act_percentage_sent),
			                      ("m") x ($act_percentage_sent),
			                      ("#") x ($act_percentage_recvd)];
		}

		#Create the full graph:
		@xpm = ($self->{width} . " " . $self->{height} . " 4 1",
		        "# c Turquoise",
		        "m c Lightblue",
		        "  c Black",
		        "- c Lightgreen");
		for my $line_nr (0 .. $self->{height} - 1) {
			my $line = "";
			for my $row_nr (@row_order) {
				$line .= $xpm_vert[$row_nr]->[$line_nr];
			}
			push @xpm, $line;
		}
	}
	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_xpm_data(@xpm);
	$self->{image}->set_from_pixbuf($pixbuf);

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
		update_interval =>  8,
		displayed_interface => "eth0",
		width           => 32,
	};
}

1;
