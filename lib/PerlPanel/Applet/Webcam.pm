# $Id: Webcam.pm,v 1.2 2005/02/02 15:36:12 jodrell Exp $
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
package PerlPanel::Applet::Webcam;
use vars qw($MULTI %COMMANDS);
use File::Basename qw(basename);
use strict;

our $MULTI = 1;

our %COMMANDS = (
	wget	=> '%s "{url}" --quiet --output-document="{file}"',
	GET	=> '%s "{url}" > "{file}"',
	curl	=> '%s "{url}" > "{file}"',
);

sub new {
	my ($package, $id) = @_;
	my $self = {
		package	=> $package,
		id	=> $id,
	};
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{config} = PerlPanel::get_config('Webcam', $self->{id});

	$self->{loading} = 0;

	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('webcam', PerlPanel::icon_size)));
	PerlPanel::tips->set_tip($self->{widget}, _('Webcam'));
	$self->widget->set_relief('none');

	CMDS: foreach my $command (keys(%COMMANDS)) {
		chomp(my $cmd = `which $command 2> /dev/null`);
		if (-x $cmd) {
			$self->{command} = sprintf($COMMANDS{$command}, $command);
			last CMDS;
		}
	}

	if (!defined($self->{command})) {
		PerlPanel::warning(_('The Webcam applet cannot find a program that it needs. You should install wget, curl or LWP'));
		$self->widget->set_sensitive(undef);

	} else {
		$self->widget->signal_connect('button_release_event', sub {
			if ($_[1]->button == 1) {
				if ($self->{loaded} = 1) {
					$self->image_dialog;

				} else {
					$self->config_dialog;

				}

			} elsif ($_[1]->button == 3) {
				$self->popup;

			}
			return undef;
		});

		$self->{glade} = PerlPanel::load_glade('webcam');

		my $icon = PerlPanel::get_applet_pbf('Webcam', 48);
		$self->{glade}->get_widget('config_dialog_icon')->set_from_pixbuf($icon);
		$self->{glade}->get_widget('config_dialog')->set_icon($icon);
		$self->{glade}->get_widget('image_dialog')->set_icon($icon);

		$self->{glade}->get_widget('image_dialog')->signal_connect('delete_event', sub {
			shift()->hide_all;
			return 1;
		});
		$self->{glade}->get_widget('image_dialog')->signal_connect('response', sub {
			shift()->hide_all;
		});
		$self->{glade}->get_widget('config_dialog')->signal_connect('delete_event', sub {
			$self->widget->set_sensitive(1);
			shift()->hide_all;
			return 1;
		});
		$self->{glade}->get_widget('config_dialog')->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				$self->{config}->{url}		= $self->{glade}->get_widget('url_entry')->get_text;
				$self->{config}->{interval}	= $self->{glade}->get_widget('interval_spin')->get_value;
				PerlPanel::save_config;
			}
			$self->widget->set_sensitive(1);
			shift()->hide_all;
			return 1;
		});

		$self->update;

	}

	$self->widget->show_all;

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
	return {};
}

sub image_dialog {
	my $self = shift;
	$self->{glade}->get_widget('image_dialog')->show_all;
}

sub config_dialog {
	my $self = shift;
	$self->{glade}->get_widget('url_entry')->set_text($self->{config}->{url});
	$self->{glade}->get_widget('interval_spin')->set_value($self->{config}->{interval});
	$self->{glade}->get_widget('config_dialog')->show_all;
}

sub update {
	my $self = shift;

	if ($self->{config}->{url} ne '' && $self->{loading} == 0) {

		my $tmpfile = sprintf('%s/.%s/webcam-%s', $ENV{HOME}, lc($PerlPanel::NAME), basename($self->{config}->{url}));

		my $cmd = $self->{command};
		$cmd =~ s/{url}/$self->{config}->{url}/;
		$cmd =~ s/{file}/$tmpfile/;

		$self->{loading} = 1;
		$self->{loaded} = 0;
		PerlPanel::exec_wait($cmd, sub {
			if ($? == 0) {
				$self->{loading} = 0;
				$self->widget->child->set_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file_at_size($tmpfile, PerlPanel::icon_size, PerlPanel::icon_size));
				$self->{glade}->get_widget('image')->set_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file($tmpfile));
				unlink($tmpfile);
				$self->{loaded} = 1;
				PerlPanel::add_timeout(($self->{config}->{interval} * 60 * 1000), sub { $self->update });
			}
		});
	}

	return undef;
}

1;
