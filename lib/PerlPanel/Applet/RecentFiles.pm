# $Id: RecentFiles.pm,v 1.1 2004/06/03 12:03:41 jodrell Exp $
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
package PerlPanel::Applet::RecentFiles;
use Gnome2::VFS;
use XML::Simple;
use File::Basename qw(basename);
use base 'PerlPanel::MenuBase';
use URI::Escape;
use strict;

sub configure {
	my $self = shift;

	$self->{file} = sprintf('%s/.recently-used', $ENV{HOME});
	$self->{widget}	= Gtk2::Button->new;
	$self->{config} = PerlPanel::get_config('RecentFiles');

	$self->widget->set_relief('none');

	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('RecentFiles', PerlPanel::icon_size));

	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});

	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}

	PerlPanel::tips->set_tip($self->{widget}, _('Recent Files'));

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	return 1;

}

sub clicked {
	my $self = shift;
	$self->create_menu;
	$self->popup;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;

	if (-e $self->{file}) {
		my $data = XMLin($self->{file});
		my @files = @{$data->{RecentItem}};
		my $i = 0;

		foreach my $file (@files, 0, 20) {
			if ($file->{URI} =~ /^file:/) {
				my $filename = Gnome2::VFS->get_local_path_from_uri($file->{URI});
				next unless (-e $filename);
			}

			$i++;
			if (!defined($self->{types}->{$file->{'Mime-Type'}})) {
				$self->{types}->{$file->{'Mime-Type'}} = Gnome2::VFS::Mime::Type->new($file->{'Mime-Type'});
			}

			if (defined($self->{types}->{$file->{'Mime-Type'}})) {
				my $icon = $self->{types}->{$file->{'Mime-Type'}}->get_icon;

				if ($icon eq '') {
					$icon = PerlPanel::lookup_icon('gnome-fs-regular');

				} elsif (! -e $icon) {
					$icon = PerlPanel::lookup_icon($icon);

					if (! -e $icon) {
						$icon = PerlPanel::lookup_icon('gnome-fs-regular');

					}
				}

				$self->menu->append($self->menu_item(
					uri_unescape(basename($file->{URI})),
					$icon,
					sub {
						$self->{types}->{$file->{'Mime-Type'}}->get_default_application->launch($file->{URI});
					},
				));
			}
			last if ($i == 20);
		}
	}
}

sub show_control_items {
	return undef;
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
	return undef;
}

1;
