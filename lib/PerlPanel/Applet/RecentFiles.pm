# $Id: RecentFiles.pm,v 1.3 2004/06/07 09:19:36 jodrell Exp $
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

	Gnome2::VFS->init;

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

	$self->widget->signal_connect('clicked', sub { $self->clicked });

	$self->create_menu;

	Glib::Timeout->add(1000, sub {
		$self->create_menu if ($self->file_age > $self->{mtime});
		return 1;
	});

	return 1;

}

sub clicked {
	my $self = shift;
	$self->popup;
}

sub create_menu {
	my $self = shift;

	$self->{menu} = Gtk2::Menu->new;

	if (-e $self->{file}) {
		$self->{mtime} = $self->file_age;

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
				my $icon;

				if (-d Gnome2::VFS->get_local_path_from_uri($file->{URI})) {
					$icon = PerlPanel::lookup_icon('gnome-fs-directory');

				} else {
					$icon = $self->{types}->{$file->{'Mime-Type'}}->get_icon;
				}

				if (! -e $icon) {
					if ($file->{'Mime-Type'} =~ /^text/) {
						$icon = PerlPanel::lookup_icon('gnome-mime-text');

					} elsif ($file->{'Mime-Type'} =~ /^image/) {
						$icon = PerlPanel::lookup_icon('gnome-mime-image');

					} elsif ($file->{'Mime-Type'} =~ /^video/) {
						$icon = PerlPanel::lookup_icon('gnome-mime-video');

					} else {
						$icon = PerlPanel::lookup_icon('gnome-fs-regular');

					}

					if ($icon eq '') {
						$icon = PerlPanel::lookup_icon($icon);

						if (! -e $icon) {
							my $type = $file->{'Mime-Type'};
							$type =~ s!/!-!;
							$type = sprintf('gnome-mime-%s', $type);
							$icon = PerlPanel::lookup_icon($type);
						}
					}
				}

				$self->menu->append($self->menu_item(
					uri_unescape(basename($file->{URI})),
					$icon,
					sub {
						my $launcher = $self->{types}->{$file->{'Mime-Type'}}->get_default_application;
						if (!defined($launcher)) {
							PerlPanel::warning(_("Couldn't find a launcher for files of type '{type}'", type => $file->{'Mime-Type'}));

						} else {
							$launcher->launch($file->{URI});

						}
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