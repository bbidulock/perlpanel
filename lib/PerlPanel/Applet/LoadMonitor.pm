# $Id: LoadMonitor.pm,v 1.10 2004/06/28 21:27:07 jodrell Exp $
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
	$self->{widget} = Gtk2::EventBox->new;

	if ($self->{config}->{show_icon} eq 'true') {
		$self->{icon} = PerlPanel::get_applet_pbf('LoadMonitor', PerlPanel::icon_size);
		$self->{label} = Gtk2::Label->new;
	
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->pack_start(Gtk2::Image->new_from_pixbuf($self->{icon}), 0, 0, 0);
		$self->widget->child->pack_start($self->{label}, 1, 1, 0);
	} else {
		$self->{label}= Gtk2::Label->new();
		$self->{widget}->add($self->{label});
	}

	PerlPanel::tips->set_tip($self->{widget}, _('CPU Usage'));
	$self->update;
	Glib::Timeout->add(1000, sub { $self->update });
	return 1;

}

sub update {
	my $self = shift;
	open(LOADAVG, '/proc/loadavg') or PerlPanel::error(_("Couldn't open '/proc/loadavg': {error}", error => $!), sub { exit }) and return undef;
	chomp(my $data = <LOADAVG>);
	close(LOADAVG);
	my $load = (split(/\s+/, $data, 5))[0];
	$self->{label}->set_text(sprintf(' %d%% ', ($load / 1) * 100));
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
		show_icon	=> 'true',
	};
}

1;
