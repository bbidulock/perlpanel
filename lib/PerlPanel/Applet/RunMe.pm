# $Id: RunMe.pm,v 1.4 2004/09/17 11:28:53 jodrell Exp $
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
# Copyright: (C) 2004 Mark Ng <markn+0@cs.mu.OZ.AU>
#
package PerlPanel::Applet::RunMe;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Combo->new; 
	$self->widget->disable_activate();

	my @history = PerlPanel::get_run_history;

	$self->{store} = $self->create_store;

	my $completion = Gtk2::EntryCompletion->new;
	$completion->set_model($self->{store});
	$completion->set_text_column(0);
	$completion->set_minimum_key_length(2);
	$self->{widget}->entry->set_completion($completion);

	$self->{widget}->set_popdown_strings('', @history);
	$self->{widget}->set_use_arrows(1);
	$self->{widget}->set_value_in_list(0, 1);

	$self->{widget}->entry->signal_connect('activate', sub {
		my $command = $self->{widget}->entry->get_text();
		system("$command &");

		unshift(@{$self->{history}}, $command);
		$self->{widget}->set_popdown_strings(@history);

		$self->{widget}->entry->set_text('');

		PerlPanel::append_run_history($command);
	});
	$self->widget->show_all;
	return 1;
}

sub get_default_config {
	return {};
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

sub create_store {
	my $self = shift;
	my $store = Gtk2::ListStore->new(Glib::String::);

	my %executables;
	foreach my $dir (split(/:/, $ENV{PATH})) {
		if (!opendir(DH, $dir)) {
			next;
		} else {
			my @files = grep { -x "$dir/$_" } grep { ! /^\.{1,2}$/ } readdir(DH);
			closedir(DH);
			map { $executables{$_}++ } @files;
		}
	}

	foreach my $program (sort keys %executables) {
		$store->set($store->append, 0, $program);
	}

	return $store;
}

1;
