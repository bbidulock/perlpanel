# $Id: LoadMonitor.pm,v 1.13 2005/05/10 14:27:56 jodrell Exp $
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
package PerlPanel::Applet::LoadMonitor;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('LoadMonitor');
	$self->{widget} = Gtk2::Frame->new;
	$self->{widget}->set_border_width(0);
	$self->{widget}->set_shadow_type("etched_in");
	$self->{widget}->set_size_request(-1, PerlPanel::icon_size());

	$self->{height}      = PerlPanel::icon_size();
	$self->{width}       = $self->{config}->{width};
	$self->{load_data}   = [(0) x $self->{width}];
	$self->{updated_row} = 0;
	
	$self->{image}     = Gtk2::Image->new();
	$self->{image}->set_padding(0,0);

	$self->{widget}->add($self->{image});

	$self->update();

	PerlPanel::tips->set_tip($self->{widget}, _('CPU Usage'));

	$self->update;
	$self->{'widget'}->show_all;

	PerlPanel::add_timeout(3000, sub { $self->update() });
	return 1;

}

sub update {
	my $self = shift;

	#Increment the counter pointing us to the active row:
	$self->{updated_row} += 1;
	$self->{updated_row} -= $self->{width} if ($self->{updated_row} >= $self->{width});

	#Get the new data:
	open (LOAD, "<", "/proc/loadavg") or die "Can't open /proc/loadavg: $!";
	my ($load_1) = split /\s+/, <LOAD>;
	close LOAD;

	$self->{load_data}->[$self->{updated_row}] = $load_1 * 100;

	#Find the maximal load in the stored data:
	my $max_value = 0;
	for (@{$self->{load_data}}) { $max_value = $_ if $_ > $max_value };
	my $factor = int($max_value/100 + 1);

	#Calculate where the threshold lines should be. This obviously horribly
	#breaks for $factor > height (all information is hidden behind the line)
	#Anyway, people with such a high load have other problems.
	my @threshold_lines;
	for (1..$factor) {
		push @threshold_lines, $_ * (int($self->{'height'} / $factor + 0.5));
	}
	#The last line isn't needed, as the border of the image is the same:
	pop @threshold_lines;
	
	my @row_order;
	#Go over all rows, prepare the row ordering and the xpm data:
	my @xpm_vert;
	for my $i (0 .. $self->{width} - 1) {
		#@row_order is sorted from left to right, so we want the
		#last updated row to be the last in the array:
		my $row_nr = $self->{'updated_row'} - ($self->{'width'} - 1 - $i);
		   $row_nr += $self->{'width'} if $row_nr < 0;
		push @row_order, $row_nr;
		
		#Update the actual xpm data (we need to do this every time,
		#as $factor changes from time to time:
		my $act_percentage = int(($self->{'load_data'}->[$row_nr] / 100 * $self->{'height'} / $factor) + 0.5);
		$xpm_vert[$row_nr] = [(" ") x ($self->{'height'} - $act_percentage), ("#") x ($act_percentage)];

		#Insert nice lines:
		$xpm_vert[$row_nr]->[$_] = "-" for (@threshold_lines);
	}

	#Create the full graph:
	my @xpm = ($self->{'width'} . " " . $self->{'height'} . " 3 1",
	           "# c Turquoise",
	           "  c Black",
	           "- c Lightgreen");
	for my $line_nr (0 .. $self->{'height'} - 1) {
		my $line = "";
		for my $row_nr (@row_order) {
			$line .= $xpm_vert[$row_nr]->[$line_nr];
		}
		push @xpm, $line;
	}
	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_xpm_data(@xpm);
	$self->{'image'}->set_from_pixbuf($pixbuf);

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
		update_interval =>  5,
		width           => 32,
	};
}

1;
