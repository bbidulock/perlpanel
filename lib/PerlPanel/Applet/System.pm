package PerlPanel::Applet::System;
use base 'PerlPanel::MenuBase';
use Net::DBus;
use Net::DBus::GLib;
use strict;
use warnings;

sub configure {
	my $self = shift;
	my $icon;

	my $wg = $self->{widget} = Gtk2::Button->new;
	my $cf = $self->{config} = PerlPanel::get_config('System');
	$cf = {} unless $cf;
	$wg->set_relief(($cf->{relief} and $cf->{relief} eq 'true') ? 'half' : 'none');
	my $pb = $self->{pixbuf} = PerlPanel::get_applet_pbf('System', PerlPanel::icon_size);
	if ($cf->{arrow} and $cf->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($pfb), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(
				sprintf('%s/share/%s/menu-arrow-%s.png', $PerlPanel::PREFIX,
					lc($PerlPanel::NAME), lc(PerlPanel::position)));
		my $x = $pb->get_width - $arrow->get_width;
		my $y = PerlPanel::position eq 'bottom' ? 0 : $pb->get_height - $arrow->get_height;
		$fixed->put(Gtk2::Image->new_from_pixbuf($arrow), $x, $y);
		$icon = $self->{icon} = Gtk2::Alignement->new(0.5, 0.5, 0, 0);
		$icon->add($fixed);
	} else {
		$icon = $self->{icon} = Gtk2::Image->new_from_pixbuf($pb);
	}
	if (not $cf->{label}) {
		$wg->add($icon);
	} else {
		my $hb = Gtk2::HBox->new;
		my $lb = Gtk2::Label->new($cf->{label});
		$wg->add($hb);
		$hb->set_border_width(0);
		$hb->set_spacing(0);
		$hb->pack_start($icon, 0, 0, 0);
		$hb->pack_start($lb, 1, 1, 0);
	}
	PerlPanel::tips->set_tip($wg, _('System'));
	$wg->signal_connect(clicked=>sub{$self->clicked});
	$wg->show_all;
	return 1;
}

sub widget {
	return shift->{widget};
}

sub clicked {
	my $self = shift;
	$self->create_menu;
	$self->popup;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;
	$self->add_actions;
	$self->add_users;
	return 1;
}

sub add_actions {
	my $self = shift;
	my %avail = {
		POWEROFF	=> undef,
		REBOOT		=> undef,
		SUSPEND		=> undef,
		HIBERNATE	=> undef,
		HYBRIDSLEEP	=> undef,
	};
	my %actions = {
		POWEROFF	=> [ _(q(Power Off)),		_(q(Shutdown the computer)),				[ q(system-shutdown),		q(gnome-session-halt),		q(gtk-stop),			], ],
		REBOOT		=> [ _(q(Reboot)),		_(q(Reboot the computer)),				[ q(system-reboot),		q(gnome-session-reboot),	q(gtk-refresh),			], ],
		SUSPEND		=> [ _(q(Suspend)),		_(q(Suspend the computer)),				[ q(system-suspend),		q(gnome-session-suspend),	q(gtk-save),			], ],
		HIBERNATE	=> [ _(q(Hibernate)),		_(q(Hibernate the computer)),				[ q(system-suspend-hibernate),	q(gnome-session-hibernate),	q(gtk-save-as),			], ],
		HYBRIDSLEEP	=> [ _(q(Hybrid Sleep)),	_(q(Hybrid sleep the computer)),			[ q(system-sleep),		q(gnome-session-sleep),		q(gtk-revert-to-saved),		], ],
	};
	my $bus = Net::DBus::Glib->system();
	my $srv = $bus->get_service('org.freedesktop.login1');
	my $obj = $srv->get_object('/org/freedesktop/login1');

	$avail{POWEROFF}	= $obj->CanPowerOff();
	$avail{REBOOT}		= $obj->CanReboot();
	$avail{SUSPEND}		= $obj->CanSuspend();
	$avail{HIBERNATE}	= $obj->CanHibernate();
	$avail{HYBRIDSLEEP}	= $obj->CanHybridSleep();

	my $acts = $self->menu_item(_(q(Actions)), PerlPanel::lookup_icon(q(system-run)));
	my $smenu = Gtk2::Menu->new();
	$acts->set_submenu($smenu);
	my $gotone = 0;

	foreach my $act (qw(POWEROFF REBOOT SUSPEND HIBERNATE HYBRIDSLEEP)) {
		my $action = $actions{$act};
		if ($action->[0]) {
			my $mi = $self->menu_item($action->[1], PerlPanel::lookup_icon($action->[3][0]),
				sub{
				});
			$smenu->append($mi);
			$mi->show();
			if ($avail{$act} and ($avail{$act} eq 'yes' or $avail{$act} eq 'challenge')) {
				$mi->set_sensitive(1);
				$gotone = 1;
			} else
				$mi->set_sensitive(0);
		}
	}
	if ($gotone)
		$self->menu->append($acts);
	return 1;
}

sub add_session {
	my $self = shift;
	my %avail = {
		LOCKSCREEN	=> undef,
		CHECKPOINT	=> undef,
		SHUTDOWN	=> undef,
		RESTART		=> undef,
		LOGOUT		=> undef,
	};
	my %sessions = {
		LOCKSCREEN	=> [ _(q(Lock Screen)),		_(q(Lock the screen)),					[ q(system-lock-screen),	q(gnome-lock-screen),		q(gtk-dialog-authentication),	], ],
		CHECKPOINT	=> [ _(q(Checkpoint)),		_(q(Checkpoint the current session)),			[ q(gtk-save),			q(gtk-save),			q(gtk-save),			], ],
		SHUTDOWN	=> [ _(q(Shutdown)),		_(q(Checkpoint and shutdown the current session)),	[ q(gtk-delete),		q(gtk-delete),			q(gtk-delete),			], ],
		RESTART		=> [ _(q(Restart)),		_(q(Restart the current session)),			[ q(system-run),		q(gtk-refresh),			q(gtk-redo),			], ],
		LOGOUT		=> [ _(q(Logout)),		_(q(Log out of the current session)),			[ q(system-log-out),		q(gnome-session-logout),	q(gtk-quit),			], ],
	};
	$avail{LOCKSCREEN}	= 'yes';
	$avail{CHECKPOINT}	= $ENV{SESSION_MANAGER} ? 'yes' : 'na';
	$avail{SHUTDOWN}	= $ENV{SESSION_MANAGER} ? 'yes' : 'na';
	$avail{RESTART}		= $ENV{SESSION_MANAGER} ? 'yes' : 'na';
	$avail{LOGOUT}		= 'yes';
	my $sess = $self->menu_item(_(q(Session)), PerlPanel::lookup_icon(q(system-run))); # FIXME
	my $smenu = Gtk2::Menu->new();
	$sess->set_submenu($smenu);
	my $gotone = 0;
	foreach my $ses (qw(CHECKPOINT SHUTDOWN RESTART LOGOUT)) {
		my $session = $sessions{$ses};
		if ($session->[0]) {
			my $mi = $self->menu_item($session->[1], PerlPanel::lookup_icon($session->[3][0]),
				sub{
				});
			$smenu->append($mi);
			$mi->show();
			if ($avail{$ses} and ($avail{$ses} eq 'yes' or $avail{$ses} eq 'challenge')) {
				$mi->set_sensitive(1);
				$gotone = 1;
			} else
				$mi->set_sensitive(0);
		}
	}
	if ($gotone)
		$self->menu->append($sess);
	return 1;
}

sub add_users {
	my $self = shift;
	my $bus = Net::DBus::Glib->system();
	my $srv = $bus->get_service('org.freedesktop.login1');
	my $obj = $srv->get_object('/org/freedesktop/login1');

	my $usrs = $self->menu_item(_(q(Switch Users)), PerlPanel::lookup(q(system-users)));
	my $smenu = Gtk2::Menu->new();
	$usrs->set_submenu($smenu);
	my $gotone = 0;

	if ($gotone)
		$self->menu->append($usrs);
	return 1;
}

sub get_default_config {
	return {
		label	=> _('System'),
		relief	=> 'true',
		arrow	=> 'false',
	};
}

1;
