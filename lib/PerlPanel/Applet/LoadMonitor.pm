# $Id: LoadMonitor.pm,v 1.8 2004/02/24 17:07:18 jodrell Exp $
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
	$self->{widget} = Gtk2::Button->new;
	$self->{widget}->set_relief('none');
	$self->{label}= Gtk2::Label->new();
	$self->{widget}->add($self->{label});
	$self->{widget}->signal_connect('clicked', sub { $self->prefs });
	PerlPanel::tips->set_tip($self->{widget}, _('CPU Usage'));
	$self->update;
	Glib::Timeout->add($self->{config}->{interval}, sub { $self->update });
	return 1;

}

sub update {
	my $self = shift;
	open(LOADAVG, '/proc/loadavg') or PerlPanel::error(_("Couldn't open '/proc/loadavg': {error}", error => $!), sub { exit }) and return undef;
	chomp(my $data = <LOADAVG>);
	close(LOADAVG);
	my $load = (split(/\s+/, $data, 5))[0];
	$self->{label}->set_text(sprintf('%d%%', ($load / 1) * 100));
	return 1;
}

sub prefs {
	my $self = shift;
	$self->{widget}->set_sensitive(0);
	$self->{window} = Gtk2::Dialog->new;
	$self->{window}->set_title(_('Configuration'));
	$self->{window}->signal_connect('delete_event', sub { $self->{widget}->set_sensitive(1) });
	$self->{window}->set_border_width(8);
	$self->{window}->vbox->set_spacing(8);
	$self->{window}->set_icon(PerlPanel::icon);
	$self->{table} = Gtk2::Table->new(3, 2, 0);
	$self->{table}->set_col_spacings(8);
	$self->{table}->set_row_spacings(8);

	my $adj = Gtk2::Adjustment->new($self->{config}->{interval}, 100, 60000, 1, 1000, undef);
	$self->{controls}{interval} = Gtk2::SpinButton->new($adj, 1, 0);

	$self->{labels}{interval} = Gtk2::Label->new(_('Update interval (ms):'));
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
			$self->{config}->{interval}    = $self->{controls}{interval}->get_value_as_int;
			$self->{widget}->set_sensitive(1);
			$self->{window}->destroy;
			PerlPanel::save_config;
			PerlPanel::reload;
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
