# $Id: BBMenu.pm,v 1.46 2004/01/26 00:50:58 jodrell Exp $
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
package PerlPanel::Applet::BBMenu;
use base 'PerlPanel::MenuBase';
use vars qw(@menufiles @ICON_DIRECTORIES);
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
	$self->{menu}	= Gtk2::Menu->new;

	$self->widget->set_relief($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{relief} eq 'true' ? 'half' : 'none');

	$self->{iconfile} = $PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{icon};
	if (-e $self->{iconfile}) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($self->{iconfile});
		my $x0 = $self->{pixbuf}->get_width;
		my $y0 = $self->{pixbuf}->get_height;
		if ($x0 != $PerlPanel::OBJECT_REF->icon_size || $y0 != $PerlPanel::OBJECT_REF->icon_size) {
			my ($x1, $y1);
			if ($x0 > $y0) {
				# image is landscape:
				$x1 = $PerlPanel::OBJECT_REF->icon_size;
				$y1 = int(($y0 / $x0) * $PerlPanel::OBJECT_REF->icon_size);
			} elsif ($x0 == $y0) {
				# image is square:
				$x1 = $PerlPanel::OBJECT_REF->icon_size;
				$y1 = $PerlPanel::OBJECT_REF->icon_size;
			} else {
				# image is portrait:
				$x1 = int(($x0 / $y0) * $PerlPanel::OBJECT_REF->icon_size);
				$y1 = $PerlPanel::OBJECT_REF->icon_size;
			}
			$self->{pixbuf} = $self->{pixbuf}->scale_simple($x1, $y1, 'bilinear');
		}
	} else {
		$self->{pixbuf} = $self->widget->render_icon('gtk-jump-to', $PerlPanel::OBJECT_REF->icon_size_name);
	}

	$self->{icon} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	if ($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{label}), 1, 1, 0);
	}

	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Menu');

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	return 1;

}

sub create_menu {
	my $self = shift;
	$self->parse_menufile;
	$self->add_control_items if ($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{show_control_items} eq 'true' && !$PerlPanel::OBJECT_REF->has_action_menu);
	return 1;
}

sub parse_menufile {
	my $self = shift;
	foreach my $menufile (@menufiles) {
		$menufile = sprintf($menufile, $ENV{HOME});
		if (-e $menufile) {
			$self->{menufile} = $menufile;
			last;
		}
	}
	if (defined($self->{menufile})) {
		open(MENU, $self->{menufile}) or $PerlPanel::OBJECT_REF->error("Error opening $self->{menufile}: $!") and return undef;
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

		if ($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{apps_in_submenu} eq 'true' && !$PerlPanel::OBJECT_REF->has_action_menu) {

			my $item = $self->menu_item(
				$PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{submenu_label},
				$self->get_icon($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{submenu_label}, 1),
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
				$PerlPanel::OBJECT_REF->error("Parse error on line $line_no of $self->{menufile}");
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
					$current_menu = $parent_item->get_parent if (defined($parent_item));

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
		icon => $PerlPanel::OBJECT_REF->get_applet_pbf_filename('bbmenu'),
		show_control_items => 'true',
		label	=> 'Menu',
		relief	=> 'false',
		apps_in_submenu => 'false',
		submenu_label	=> 'Applications',
	};
}

1;
