# $Id: Launcher.pm,v 1.1 2004/08/24 15:22:04 jodrell Exp $
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
package PerlPanel::Applet::Launcher;
use Data::Dumper;
use vars qw($MULTI $LAUNCHER_DIR $LAUNCHER_EDITOR $UNSET_FILE);
use strict;

our $MULTI = 1;
our $LAUNCHER_DIR = sprintf('%s/.%s/launchers', $ENV{HOME}, lc($PerlPanel::NAME));
chomp (our $LAUNCHER_EDITOR = `which perlpanel-item-edit 2> /dev/null`);
our $UNSET_FILE = '/path/to/nonexistent/file';

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Launcher', $self->{id});
	$self->{widget} = Gtk2::Button->new;
	$self->{widget}->set_relief('none');
	$self->widget->add(Gtk2::Image->new);
	$self->init;
	return 1;
}

sub init {
	my $self = shift;

	if ($self->{config}->{file} eq $UNSET_FILE) {

		mkdir($LAUNCHER_DIR);

		$self->{config}->{file} = sprintf('%s/%s.desktop', $LAUNCHER_DIR, PerlPanel::new_applet_id());
		PerlPanel::save_config();

		if (-x $LAUNCHER_EDITOR) {
			open(FILE, ">$self->{config}->{file}") && close(FILE);
			my $mtime = time();
			PerlPanel::exec_wait("$LAUNCHER_EDITOR $self->{config}->{file}", sub {
				my $newmtime = (stat($self->{config}->{file}))[9];
	
				if ($newmtime > $mtime) {
					# the editor modified the file, so reload:
					$self->init;
				} else {
					# nothing changed - delete the file:
					unlink($self->{config}->{file});
				}
			});
		} else {
			PerlPanel::warning(_('No desktop item editor could be found.'));
		}

	} else {
		if (!open(FILE, $self->{config}->{file})) {
			PerlPanel::warning(_("Error opening file '{file}': {error}", file => $self->{config}->{file}, error => $!));

		} else {
			my $data;
			while (<FILE>) {
				$data .= $_;
			}
			close(FILE);
			my ($name, $comment, $icon, $program) = PerlPanel::parse_desktopfile($data);
			PerlPanel::tips->set_tip($self->widget, ($comment ne '' ? sprintf("%s\n%s", $name, $comment) : $name));
			$self->widget->signal_connect('clicked', sub { system("$program &") });
			my $pbf = Gtk2::Gdk::Pixbuf->new_from_file($icon);
			if ($pbf->get_height > PerlPanel::icon_size()) {
				$pbf = $pbf->scale_simple(($pbf->get_width * (PerlPanel::icon_size() / $pbf->get_height)), PerlPanel::icon_size(), 'bilinear');
			}
			$self->widget->child->set_from_pixbuf($pbf);
		}
	}
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
	return { 'file' => $UNSET_FILE };
}

1;
