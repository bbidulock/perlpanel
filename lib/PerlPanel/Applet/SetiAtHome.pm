# $Id: SetiAtHome.pm,v 1.5 2004/09/10 13:01:14 jodrell Exp $
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
package PerlPanel::Applet::SetiAtHome;
use Gnome2::VFS;
use File::Basename qw(dirname);
use XML::Simple;
use vars qw($TIMEOUT);
use strict;

Gnome2::VFS->init;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('SetiAtHome');
	$self->{widget} = Gtk2::Button->new;

	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->configuration_dialog });

	$self->{icon} = PerlPanel::get_applet_pbf('SetiAtHome', PerlPanel::icon_size);
	$self->{label} = Gtk2::Label->new;

	$self->widget->add(Gtk2::HBox->new);
	$self->widget->child->pack_start(Gtk2::Image->new_from_pixbuf($self->{icon}), 0, 0, 0);
	$self->widget->child->pack_start($self->{label}, 1, 1, 0);

	unless (defined($TIMEOUT)) {
		our $TIMEOUT = Glib::Timeout->add(1000 * $self->{config}->{interval}, sub { $self->refresh; return 1 });
		Glib::Timeout->add(1000, sub { $self->refresh; return undef });
	}
	return 1;

}

sub configuration_dialog {
	my $self = shift;
	$self->{app} = PerlPanel::load_glade('setiathome');
	$self->{app}->get_widget('config_dialog')->set_icon(PerlPanel::get_applet_pbf('SetiAtHome'));
	$self->{app}->get_widget('config_dialog')->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			$self->{config}->{email}	= $self->{app}->get_widget('email_entry')->get_text;
			$self->{config}->{dir}		= $self->{app}->get_widget('directory_entry')->get_text;
			if ($self->{app}->get_widget('remote_checkbutton')->get_active) {
				$self->{config}->{remote} = 'true';
				$self->{config}->{user} = $self->{app}->get_widget('user_entry')->get_text;
				$self->{config}->{host} = $self->{app}->get_widget('host_entry')->get_text;
			} else {
				$self->{config}->{remote} = 'false';
			}
			$self->{app}->get_widget('config_dialog')->destroy;
			PerlPanel::save_config();
		} else {
			$self->{app}->get_widget('config_dialog')->destroy;
		}
	});
	$self->{app}->get_widget('email_entry')->set_text($self->{config}->{email});
	$self->{app}->get_widget('directory_entry')->set_text($self->{config}->{dir});
	$self->{app}->get_widget('browse_button')->signal_connect('clicked', sub {
		my $dialog;
		if ('' ne (my $msg = Gtk2->check_version (2, 4, 0)) or $Gtk2::VERSION < 1.040) {
			$dialog = Gtk2::FileSelection->new(_('Choose File'));
		} else {
			$dialog = Gtk2::FileChooserDialog->new(
				_('Choose File'),
				undef,
				'select-folder',
				'gtk-cancel'	=> 'cancel',
				'gtk-ok' => 'ok'
			);
		}
		$dialog->set_modal(1);
		$dialog->set_icon(PerlPanel::get_applet_pbf('SetiAtHome'));
		$dialog->set_filename($self->{app}->get_widget('directory_entry')->get_text.'/');
		$dialog->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				my $file = $dialog->get_filename;
				if (-d $file) {
					$self->{app}->get_widget('directory_entry')->set_text($file);
				} elsif (-d dirname($file)) {
					$self->{app}->get_widget('directory_entry')->set_text(dirname($file));
				}
			}
			$dialog->destroy;
		});
		$dialog->show_all;
	});
	$self->{app}->get_widget('user_entry')->set_text($self->{config}{user});
	$self->{app}->get_widget('host_entry')->set_text($self->{config}{host});
	$self->{app}->get_widget('remote_checkbutton')->signal_connect('toggled', sub {
		my $state = $self->{app}->get_widget('remote_checkbutton')->get_active;
		$self->{app}->get_widget('user_entry')->set_sensitive($state);
		$self->{app}->get_widget('host_entry')->set_sensitive($state);
	});
	$self->{app}->get_widget('remote_checkbutton')->set_active($self->{config}{remote} eq 'true' ? 1 : undef);
	$self->{app}->get_widget('user_entry')->set_sensitive($self->{config}{remote} eq 'true' ? 1 : undef);
	$self->{app}->get_widget('host_entry')->set_sensitive($self->{config}{remote} eq 'true' ? 1 : undef);
}

sub refresh {
	my $self = shift;
	my $file;
	if ($self->{config}->{remote} eq 'true' && $self->{config}->{user} ne '' && $self->{config}->{host} ne '') {
		$file = sprintf(
			'/tmp/%s-setiathome-applet-%s.%d',
			lc($PerlPanel::NAME),
			(getpwuid($<))[0],
			time(),
		);
		my $cmd = sprintf(
			'ssh %s@%s "cat %s/state.sah" > %s',
			$self->{config}->{user},
			$self->{config}->{host},
			$self->{config}->{dir},
			$file
		);
		PerlPanel::exec_wait($cmd);
		while ((stat($file))[7] == 0) {
			Gtk2->main_iteration while (Gtk2->events_pending);
		}
	} else {
		$file = sprintf('%s/state.sah', $self->{config}->{dir});
	}
	my $results	= -1;
	my $progress	= -1;
	if (open(FILE, $file)) {
		while (<FILE>) {
			if (/^prog=([0-9\.]+)$/) {
				$progress = $1;
			}
		}
		close(FILE);
	}
	if ($self->{config}->{remote} eq 'true' && $self->{config}->{user} ne '' && $self->{config}->{host} ne '') {
		unlink($file);
	}
	if ($self->{config}->{email} ne '') {
		my $url = sprintf('http://setiathome2.ssl.berkeley.edu/fcgi-bin/fcgi?cmd=user_xml&email=%s', $self->{config}->{email});
		my ($result, $handle) = Gnome2::VFS->open($url, 'read');
		my $bytes_read = 0;
		my $buffer;
		if ($result eq 'ok') {
			my $info;
			($result, $info) = $handle->get_file_info('default');
			if ($result eq 'ok') {
				my $bytes = $info->{size};
				do {
					my ($tmp_buffer, $tmp_bytes_read);
					($result, $tmp_bytes_read, $tmp_buffer) = $handle->read(1024);
					$buffer .= $tmp_buffer;
					$bytes_read += $tmp_bytes_read;
				} while ($result eq 'ok');
			}
		}
		my $data = XMLin($buffer);
		$results = $data->{userinfo}->{numresults};
	}
	my $tip;
	$progress = int($progress * 100);

	if ($progress > -1) {
		$self->{label}->set_text("$progress%");
	}

	if ($progress > -1 && $results > -1) {
		$tip = _('Completed {units} workunits, {percent}% of current', units => $results, percent => $progress);
	} elsif ($progress > -1 && $results < 0) {
		$tip = _('Completed {percent}%', percent => $progress);
	} else {
		$tip = _('ERROR');
	}
	PerlPanel::tips->set_tip($self->widget, $tip);
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
	return 'start';
}

sub get_default_config {
	return {
		dir		=> $ENV{HOME}.'/.setiathome',
		interval	=> 60,
		remote		=> 'false',
	};
}

1;
