# $Id: BBMenu.pm,v 1.60 2004/06/30 19:12:54 jodrell Exp $
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
package PerlPanel::Applet::BBMenu;
use base 'PerlPanel::MenuBase';
use vars qw(@menufiles);
use File::Basename qw(basename);
use strict;

our @menufiles = (
	'%s/.perlpanel/menu',
	'%s/.blackbox/menu',
	'%s/.fluxbox/menu',
	'%s/.openbox/menu',
	'%s/.waimea/menu',
	'/usr/local/share/blackbox/menu',
	'/usr/share/blackbox/menu',
	'/usr/local/share/fluxbox/menu',
	'/usr/share/fluxbox/menu',
	'/usr/local/share/waimea/menu',
	'/usr/share/waimea/menu',
);

sub configure {
	my $self = shift;

	$self->{widget}	= Gtk2::Button->new;
	$self->{config} = PerlPanel::get_config('BBMenu');

	$self->widget->set_relief($self->{config}->{relief} eq 'true' ? 'half' : 'none');

	$self->{pixbuf} = PerlPanel::get_applet_pbf('BBMenu', PerlPanel::icon_size);

	if ($self->{config}->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($self->{pixbuf}), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/share/%s/menu-arrow-%s.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME), lc(PerlPanel::position)));
		my $x = ($self->{pixbuf}->get_width - $arrow->get_width);
		my $y = (PerlPanel::position eq 'bottom' ? 0 : ($self->{pixbuf}->get_height - $arrow->get_height));
		$fixed->put(Gtk2::Image->new_from_pixbuf($arrow), $x, $y);
		$self->{icon} = Gtk2::Alignment->new(0.5, 0.5, 0, 0);
		$self->{icon}->add($fixed);

	} else {
		$self->{icon} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});

	}

	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});

	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);

	}

	PerlPanel::tips->set_tip($self->{widget}, _('Menu'));

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	Glib::Timeout->add(1000, sub {
		my $age = $self->file_age;
		my $time = $self->{mtime};
		$self->create_menu if ($age > $time);
		return 1;
	});

	return 1;

}

sub create_menu {
	my $self = shift;
	$self->{menu}	= Gtk2::Menu->new;
	$self->{mtime} = $self->file_age;
	$self->parse_menufile;
	if ($self->{config}->{show_control_items} eq 'true' && !PerlPanel::has_action_menu) {
		$self->add_control_items(
			menu_data => $self->get_menu_data,
		);
	}
	return 1;
}

# does nothing:
sub get_menu_data {
	return [];
}

sub parse_menufile {
	my $self = shift;
	foreach my $menufile (@menufiles) {
		$menufile = sprintf($menufile, $ENV{HOME});
		if (-e $menufile) {
			$self->{file} = $menufile;
			last;
		}
	}
	if (defined($self->{file})) {
		open(MENU, $self->{file}) or PerlPanel::error(_('Error opening {file}: {error}', file => $self->{file}, error => $!)) and return undef;
		$self->{menudata} = [];
		while (<MENU>) {
			s/^\s*//g;
			s/\s*$//g;
			next if (/^#/ || /^$/);
			push(@{$self->{menudata}}, $_);
		}
		close(MENU);

		# $current_menu is a reference to the current menu or submenu - it starts out as the toplevel menu:
		my $current_menu;

		if ($self->{config}->{apps_in_submenu} eq 'true' && !PerlPanel::has_action_menu) {

			my $item = $self->menu_item(
				$self->{config}->{submenu_label},
				$self->get_icon($self->{config}->{submenu_label}, 1),
			);

			my $menu = Gtk2::Menu->new;
			$item->set_submenu($menu);
			$self->menu->append($item);
			$current_menu = $menu;

		} else {
			$current_menu = $self->menu;
		}

		for (my $line_no = 0 ; $line_no < scalar(@{$self->{menudata}}) ; $line_no++) {

			my $line = @{$self->{menudata}}[$line_no];

			my ($cmd, $name, $val);

			if ($line =~ /\[(.+?)\]/) {
				$cmd = lc($1);
			}
			if ($line =~ /\((.+?)\)/) {
				$name = $1;
			}
			if ($line =~ /\{(.+?)\}/) {
				$val = $1;
			}

			if (!defined($cmd)) {
				PerlPanel::error(_('Parse error on line {line} of {file}', line => $line_no, file => $self->{file}));
			} else {

				if ($cmd eq 'submenu') {

					# we're in a submenu, so create an item, and a new menu, make the menu
					# a submenu of the item, and make $current_menu a reference to it:

					my $item = $self->menu_item($name, $self->get_icon($name, 1), undef);

					$current_menu->append($item);

					$current_menu = Gtk2::Menu->new;

					$item->set_submenu($current_menu);

				} elsif ($cmd eq 'end') {

					# we're leaving a submenu, so we first find out the
					# item the submenu's attached to, and then find out
					# what menu the item belongs to. this is our new
					# $current_menu:

					my $parent_item = $current_menu->get_attach_widget;

					my $new_current_menu = $parent_item->get_parent if (defined($parent_item));

					# now we can remove the menu from the parent if it doesn't contain anything
					# useful:
					my $children = 0;
					map { $children++ if (ref($_) ne 'Gtk2::SeparatorMenuItem') } $current_menu->get_children;

					if ($children < 1) {
						if (defined($parent_item)) {
							$parent_item->remove_submenu;
							$parent_item->get_parent->remove($parent_item);
						}
					}

					$current_menu = $new_current_menu;

				} elsif ($cmd eq 'nop') {
					$current_menu->append(Gtk2::SeparatorMenuItem->new);

				} elsif ($cmd eq 'exec') {
					$current_menu->append($self->menu_item(
						$name,
						$self->get_icon($val, 0),
						sub { system("$val &") }
					));
				}
			}
		}
		return 1;
	}
}

sub get_default_config {
	return {
		show_control_items => 'true',
		label	=> _('Menu'),
		relief	=> 'false',
		apps_in_submenu => 'false',
		submenu_label	=> _('Applications'),
	};
}

sub get_icon {
	my ($self, $executable, $is_submenu_parent) = @_;

	$executable = basename($executable);
	$executable =~ s/\..+$//g;

	$executable =~ s/\s/-/g if ($is_submenu_parent == 1);

	my $file = $self->detect_icon($executable);

	if (-e $file) {
		return $file;

	} else {
		return ($is_submenu_parent == 1 ? PerlPanel::lookup_icon('gnome-fs-directory') : 'gtk-execute');

	}
}

sub detect_icon {
	my ($self, $executable) = @_;

	return undef if ($executable eq '');
	my $program = lc(basename($executable));
	($program, undef) = split(/\s/, $program, 2);

	my $file = sprintf('%s/.%s/icon-files/%s.png', $ENV{HOME}, lc($PerlPanel::NAME), $program);
	if (-e $file) {
		return $file;
	} else {
		return PerlPanel::lookup_icon($executable);
	}
}

1;
