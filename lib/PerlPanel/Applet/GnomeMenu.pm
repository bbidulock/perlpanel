# $Id: GnomeMenu.pm,v 1.1 2004/04/30 16:28:04 jodrell Exp $
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
package PerlPanel::Applet::GnomeMenu;
use base 'PerlPanel::MenuBase';
use Gnome2::VFS;
use Gnome2;
use vars qw ($DESKTOP_NAMESPACE);
use strict;

our $DESKTOP_NAMESPACE = 'Desktop Entry';

sub configure {
	my $self = shift;
	Gnome2::VFS->init;

	$self->{theme} = Gnome2::IconTheme->new;
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('gnomemenu', PerlPanel::icon_size)));
	$self->widget->set_relief('none');
	PerlPanel::tips->set_tip($self->widget, _('Menu'));

	$self->{language} = $ENV{LANG} || 'en_US';
	$self->{language} =~ s/\..*$//g;

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;

	$self->create_submenu_for('applications:', $self->menu);

	return 1;
}

sub create_submenu_for {
	my ($self, $uri, $menu) = @_;
	my ($result, @files) = Gnome2::VFS::Directory->list_load($uri, 'default');
	if ($result ne 'ok') {
		return undef;
	} else {
		foreach my $file (@files) {
			my $path = sprintf('%s/%s', $uri, $file->{name});
			if ($file->{type} eq 'directory') {
				my $item = $self->menu_item(
					$file->{name},
					'gtk-open',
					undef,
				);
				my $sub_menu = Gtk2::Menu->new;
				$item->set_submenu($sub_menu);
				$menu->append($item);

				$self->create_submenu_for($path, $sub_menu);
			} else {
				my ($result, $handle) = Gnome2::VFS->open($path, 'read');
				if ($result eq 'ok') {
					my $data;
					my $buffer;
					do {
						($result, undef, $buffer) = $handle->read(1024);
						$data .= $buffer;
					} while ($result eq 'ok');
					$handle->close;
					my ($label, $tip, $icon, $program) = $self->parse_desktopfile($data);
					if ($label ne '' && $program ne '') {
						my $item = $self->menu_item(
							$label,
							(-e $icon ? $icon : 'gtk-new'),
							sub { system("$program &") },
						);
						PerlPanel::tips->set_tip($item, $tip);
						$menu->append($item);
					}
				}
			}
		}
		return 1;
	}
}

sub parse_desktopfile {
	my ($self, $data) = @_;
	my ($name, $comment, $icon, $program);
	my $namespace;
	my $params = {};
	foreach my $line (split(/\n/, $data)) {
		my ($name, $value) = split(/=/, $line, 2);
		if ($name =~ /^\[($DESKTOP_NAMESPACE)\]/i) {
			$namespace = $1;
		} elsif ($namespace ne '') {
			$params->{$namespace}->{$name} = $value;
		}
	}
	$name    = ($params->{$DESKTOP_NAMESPACE}{"Name[$self->{language}]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Name[$self->{language}]"} : $params->{$DESKTOP_NAMESPACE}{Comment});
	$comment = ($params->{$DESKTOP_NAMESPACE}{"Comment[$self->{language}]"} ne '' ? $params->{$DESKTOP_NAMESPACE}{"Comment[$self->{language}]"} : $params->{$DESKTOP_NAMESPACE}{Comment});
	$program = $params->{$DESKTOP_NAMESPACE}{Exec};
	($icon, undef) = $self->{theme}->lookup_icon($params->{$DESKTOP_NAMESPACE}{Icon}, PerlPanel::icon_size_name);

	return ($name, $comment, $icon, $program);
}

sub get_default_config {
	return undef;
}

1;
