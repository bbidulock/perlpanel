# $Id: RunMe.pm,v 1.1 2004/05/28 10:46:57 jodrell Exp $
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
use vars qw($histfile);
use strict;

our $histfile = sprintf('%s/.%s/run-history', $ENV{HOME}, lc($PerlPanel::NAME));

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

  	open(HFILE, $histfile);
	my @history = reverse(<HFILE>);
	close(HFILE);
	map { chomp($history[$_]) } 0..scalar(@history);
	$self->{history} = \@history;

	$self->{widget}->set_popdown_strings(@history);
	$self->{widget}->set_use_arrows(1);
	$self->{widget}->set_value_in_list(0, 1);
	$self->{widget}->entry->set_text('');

	$self->{widget}->entry->signal_connect('activate', sub {
		my $command = $self->{widget}->entry->get_text();
		system("$command &");

		unshift(@{$self->{history}}, $command);
		$self->{widget}->set_popdown_strings(@{$self->{history}});

		$self->{widget}->entry->set_text('');

		# save history as we go along.
		if (open (HFILE, ">>$histfile")) {
			print HFILE "$command\n";
			close(HFILE);
		}
	});
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

1;
