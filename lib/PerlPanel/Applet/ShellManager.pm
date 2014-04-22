# $Id: ShellManager.pm,v 1.11 2006/02/02 13:51:02 mcummings Exp $
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
package PerlPanel::Applet::ShellManager;
use base 'PerlPanel::MenuBase';
use Gtk2::SimpleList;
use vars qw($KEY);
use strict;

our $KEY = sprintf('%s/.ssh/id_rsa.pub', $ENV{HOME});

sub configure {
	my $self = shift;

	$self->{widget}	= Gtk2::Button->new;
	$self->{menu}	= Gtk2::Menu->new;
	$self->{config} = PerlPanel::get_config('ShellManager');

	$self->widget->set_relief('none');

	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('ShellManager', PerlPanel::icon_size));
	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}

	PerlPanel::tips->set_tip($self->{widget}, _('Shell Manager'));

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });
	$self->widget->show_all;

	return 1;

}

sub get_default_config {
	chomp(my $terminal = `which gnome-terminal 2> /dev/null`);
	return {
		terminal => $terminal,
	};
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;
	if (ref($self->{config}->{sessions}) eq 'ARRAY') {
		my %connections;
		foreach my $session (@{$self->{config}->{sessions}}) {
			$connections{"$session->{user}\@$session->{host}"} = $session;
		}
		foreach my $session (sort keys %connections) {
			$self->menu->append($self->menu_item(
				$session,
				PerlPanel::get_applet_pbf('shellmanager', PerlPanel::menu_icon_size),
				sub {
					my $cmd = sprintf('%s -e "ssh -p %d %s %s@%s" &', $self->{config}->{terminal}, $connections{$session}->{port}, $connections{$session}->{options}, $connections{$session}->{user}, $connections{$session}->{host});
					system($cmd);
				},
			));
		}
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
		$self->menu->append($self->menu_item(
			_('Edit Connections...'),
			'gtk-properties',
			sub { $self->edit_dialog },
		));
	}
	$self->menu->append($self->menu_item(
		_('New Connection...'),
		'gtk-new',
		sub { $self->add_dialog },
	));
	return 1;
}

sub edit_dialog {
	my $self = shift;

	my $glade = PerlPanel::load_glade('shellmanager');
	my $dialog = $glade->get_widget('edit_window');

	$dialog->set_position('center');
	$dialog->set_icon(PerlPanel::icon);

	my $list = Gtk2::SimpleList->new_from_treeview(
		$glade->get_widget('connection_list'),
		_('User')	=> 'text',
		_('Host')	=> 'text',
		_('Port')	=> 'int',
		_('Options')	=> 'text'
	);
	$list->get_column(0)->set_resizable(1);
	$list->get_column(1)->set_resizable(1);
	$list->get_column(2)->set_resizable(1);

	if (ref($self->{config}->{sessions}) eq 'HASH') {
		$self->{config}->{sessions} = [
			$self->{config}->{sessions},
		];
	}
	my %connections;
	foreach my $session (@{$self->{config}->{sessions}}) {
		$connections{"$session->{user}\@$session->{host}"} = $session;
	}
	foreach my $session (sort keys %connections) {
		push(@{$list->{data}}, [ $connections{$session}->{user}, $connections{$session}->{host}, $connections{$session}->{port}, $connections{$session}->{options} ]);
	}

	$dialog->signal_connect('response', sub {
		$self->{config}->{sessions} = [];
		foreach my $row (@{$list->{data}}) {
			push(@{$self->{config}->{sessions}}, {
				user	=> @{$row}[0],
				host	=> @{$row}[1],
				port	=> @{$row}[2],
				options	=> @{$row}[3],
			});
		}
		$dialog->destroy;
		$self->create_menu;
		PerlPanel::save_config;
	});
	$glade->get_widget('delete_button')->signal_connect('clicked', sub {
		my ($idx) = $list->get_selected_indices;
		splice(@{$list->{data}}, $idx, 1);
		$list->select($idx);
	});

	if ($ENV{SSH_AGENT_PID} > 0 && -x $ENV{SSH_ASKPASS}) {
		$glade->get_widget('key_button')->signal_connect('clicked', sub {
			if (! -r $KEY) {
				PerlPanel::warning(_("Error: cannot find RSA public key. You may need to create one using:\n\n\tssh-keygen -t rsa"));

			} else {
				my ($idx) = $list->get_selected_indices;
				my ($user, $host, $port, $options) = @{(@{$list->{data}})[$idx]};
				my $cmd = sprintf('cat "%s" | ssh -p %d %s %s@%s \'cat >> .ssh/authorized_keys2\' &', $KEY, $port, $options, $user, $host);
				system($cmd);
			}
		});

	} else {
		$glade->get_widget('key_button')->set_sensitive(0);

	}

	$dialog->show_all;

	return 1;
}

sub add_dialog {
	my $self = shift;
	my $glade = PerlPanel::load_glade('shellmanager');
	my $dialog = $glade->get_widget('prefs_window');

	$dialog->set_icon(PerlPanel::icon);

	my $uid = lc((getpwuid($<))[0]);

	$glade->get_widget('user_combo')->disable_activate;
	$glade->get_widget('user_combo')->set_popdown_strings($uid, grep { $_ ne $uid } $self->get_usernames);
	$glade->get_widget('user_combo')->entry->set_text($uid);

	$glade->get_widget('host_combo')->disable_activate;
	$glade->get_widget('host_combo')->set_popdown_strings($self->get_hostnames);
	$glade->get_widget('host_combo')->entry->set_text('');
	$glade->get_widget('host_combo')->entry->signal_connect('activate', sub { $dialog->response('ok') });

	$dialog->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			my $user = $glade->get_widget('user_combo')->entry->get_text;
			my $host = $glade->get_widget('host_combo')->entry->get_text;
			my $port = $glade->get_widget('port_spinbutton')->get_value;
			my $options = $glade->get_widget('options_combo')->entry->get_text;
			if (ref($self->{config}->{sessions}) eq 'HASH') {
				$self->{config}->{sessions} = [
					$self->{config}->{sessions},
				];
			}
			push(@{$self->{config}->{sessions}}, {
				user	=> lc($user),
				host	=> lc($host),
				port	=> $port,
				options => $options,
			});
			my $cmd = sprintf('%s -e "ssh -p %d %s %s@%s" &', $self->{config}->{terminal}, $port, $options, $user, $host);
			system($cmd);
			$self->create_menu;
			PerlPanel::save_config;
		}
		$dialog->destroy;
	});
	$dialog->signal_connect('delete_event', sub {
		$dialog->destroy;
		return 1;
	});
	$dialog->show_all;
	return 1;
}

sub get_usernames {
	my $self = shift;
	my @names;
	if (ref($self->{config}->{sessions}) eq 'ARRAY') {
		foreach my $session (@{$self->{config}->{sessions}}) {
			push(@names, $session->{user});
		}
	}
	return sort(@names);
}
sub get_hostnames {
	my $self = shift;
	my @hosts;
	if (ref($self->{config}->{sessions}) eq 'ARRAY') {
		foreach my $session (@{$self->{config}->{sessions}}) {
			push(@hosts, $session->{host});
		}
	}
	return sort(@hosts);
}

1;
