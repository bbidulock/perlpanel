# $Id: Trash.pm,v 1.1 2005/01/10 11:26:37 jodrell Exp $
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
# Copyright: (C) 2005 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel::Applet::Trash;
use File::Basename qw(basename);
use vars qw($TRASH_DIR);
use strict;

our $TRASH_DIR = sprintf('%s/.Trash', $ENV{HOME});

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Trash');
	$self->{widget} = Gtk2::EventBox->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('Trash', PerlPanel::icon_size)));
	PerlPanel::tips->set_tip($self->widget, _('Drag files here to send to the Trash Can'));

	my $target_list	= Gtk2::TargetList->new;
	$target_list->add(Gtk2::Gdk::Atom->new('text/uri-list'), 0, 0);
	$self->widget->drag_dest_set(['drop', 'motion', 'highlight'], ['copy', 'private', 'default', 'move', 'link', 'ask']);
	$self->widget->signal_connect(drag_data_received => sub { $self->drop_handler(@_) });
	$self->widget->drag_dest_set_target_list($target_list);

	$self->widget->show_all;

	mkdir($TRASH_DIR);
	chmod(0700, $TRASH_DIR);

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
	return {};
}

sub drop_handler {
	my ($self, @data) = @_;
	my @uris = split(/[\r\n]+/, $data[4]->data);
	if (scalar(@uris) > 0) {
		my $remote = 0;
		map { $remote++ if ($_ !~ /^file:\/\//) } @uris;
		if ($remote > 0) {
			PerlPanel::warning(_('Cannot trash remote files!'));

		} else {
			foreach my $uri (@uris) {
				$uri =~ s/^file:\/+/\//i;
				if (!rename($uri, $self->trashname($uri))) {
					PerlPanel::warning($!);
				}
			}

		}
	}
	return 1;
}

sub trashname {
	my ($self, $uri, $count) = @_;
	my $name = sprintf('%s/%s%s', $TRASH_DIR, basename($uri), ($count > 0 ? sprintf(' (%d)', $count) : ''));
	if (-e $name) {
		return $self->trashname($uri, $count+1);

	} else {
		return $name;

	}
}

1;
