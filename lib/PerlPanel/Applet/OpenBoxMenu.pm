# $Id: OpenBoxMenu.pm,v 1.2 2004/06/28 12:41:25 jodrell Exp $
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
package PerlPanel::Applet::OpenBoxMenu;
use base 'PerlPanel::MenuBase';
use vars qw(@MENU_FILES, $ROOT_MENU_ID);
use XML::Parser;
use strict;

our @MENU_FILES = (
	sprintf('%s/.openbox/menu.xml', $ENV{HOME}),
	'/etc/xdg/openbox/menu.xml',
);

our $ROOT_MENU_ID = 'root-menu';

sub configure {
	my $self = shift;

	$self->{widget} = Gtk2::Button->new;

	$self->{config} = PerlPanel::get_config('OpenBoxMenu');

	$self->{icon} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('OpenBoxMenu', PerlPanel::icon_size));

	if ($self->{config}->{label} eq '') {
		$self->widget->add($self->{icon});
	} else {
		$self->widget->add(Gtk2::HBox->new);
		$self->widget->child->set_border_width(0);
		$self->widget->child->set_spacing(0);
		$self->widget->child->pack_start($self->{icon}, 0, 0, 0);
		$self->widget->child->pack_start(Gtk2::Label->new($self->{config}->{label}), 1, 1, 0);
	}

	$self->widget->set_relief('none');
	PerlPanel::tips->set_tip($self->widget, _('Menu'));

	if ($self->{config}->{warning_seen} ne 'true') {
		PerlPanel::warning(
			_('The OpenBox menu is new and unstable - it is not guaranteed to work correctly. If you find a bug, submit a patch!'),
			sub {
				$self->{config}->{warning_seen} = 'true';
				PerlPanel::save_config;
			}
		);
	}

	$self->create_menu;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	#Glib::Timeout->add(1000, sub {
	#	my $age = $self->file_age;
	#	my $time = $self->{mtime};
	#	$self->create_menu if ($age > $time);
	#	return 1;
	#});

	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{menu}	= Gtk2::Menu->new;
	$self->{mtime} = $self->file_age;
	$self->parse_menufile;
	$self->build_root_menu;
	if ($self->{config}->{show_control_items} eq 'true' && !PerlPanel::has_action_menu) {
		$self->add_control_items;
	}
	return 1;
}

sub parse_menufile {
	my $self = shift;
	foreach my $menufile (@MENU_FILES) {
		if (-e $menufile) {
			$self->{file} = $menufile;
			last;
		}
	}
	$self->{parser} = XML::Parser->new(Handlers => {
		Start	=> sub {
			my ($parser, $tag, %attrs) = @_;

			if ($tag eq 'openbox_menu') {
				$self->{in_menu} = 1;

			} elsif ($tag eq 'menu') {
				if ($self->{in_menu} != 1) {
					print STDERR "*** can't start a menu here.\n";

				} elsif ($self->{current_menu} ne '') {
					if ($self->{current_menu} eq $ROOT_MENU_ID) {
						$self->{parent_menu} = $self->{current_menu};
						$self->{current_menu} = $attrs{id};
						push(@{$self->{tree}->{$ROOT_MENU_ID}}, { type => 'menu', id => $attrs{id} });

					} else {
						print STDERR "*** can't start a new menu without closing a previous one.\n";

					}

				} else {
					$self->{labels}->{$attrs{id}} = $attrs{label};
					$self->{current_menu} = $attrs{id};
				}

			} elsif ($tag eq 'item') {
				$self->{current_item} = {
					label => $attrs{label},
				};
				if ($self->{current_menu} eq '') {
					print STDERR "*** found an orphaned item '$attrs{label}'\n";
				} else {
					push(@{$self->{tree}->{$self->{current_menu}}}, $self->{current_item});
				}

			} elsif ($tag eq 'execute') {
				if (defined($self->{current_item})) {
					$self->{current_item}->{type} = 'execute';
				}

			} elsif ($tag eq 'separator') {
				push(@{$self->{tree}->{$self->{current_menu}}}, {
					type	=> 'separator',
				});

			}
		},
		End	=> sub {
			my ($parser, $tag) = @_;
			if ($tag eq 'openbox_menu') {
				$self->{in_menu} = 0;

			} elsif ($tag eq 'menu') {
				if ($self->{parent_menu} ne '') {
					$self->{current_menu} = $self->{parent_menu};
					$self->{parent_menu} = '';
				} else {
					$self->{current_menu} = '';
				}

			} elsif ($tag eq 'item') {
				undef($self->{current_item});

			}
		},
		Char	=> sub {
			my ($parser, $data) = @_;
			if ($self->{current_item}->{type} eq 'execute') {
				$self->{current_item}->{exec} = $self->trim($self->{current_item}->{exec}.$data);
			}
		}
	});
	$self->{parser}->parsefile($self->{file});
	return 1;
}

sub build_root_menu {
	my $self = shift;
	if (!defined($self->{tree}->{$ROOT_MENU_ID})) {
		PerlPanel::warning(_("Error parsing OpenBox menu: can't find the {id} menu", id => $ROOT_MENU_ID));
		return undef;
	} else {
		if ($self->{config}->{apps_in_submenu} eq 'true') {
			my $icon = PerlPanel::lookup_icon($self->{config}->{label});
			$icon = (-e $icon ? $icon : PerlPanel::lookup_icon('gnome-fs-directory'));
			my $item = $self->menu_item(
				$self->{config}->{label},
				$icon
			);
			$self->menu->append($item);
			my $menu = Gtk2::Menu->new;
			$item->set_submenu($menu);
			$self->build_menu($ROOT_MENU_ID, $menu);
		} else {
			$self->build_menu($ROOT_MENU_ID, $self->menu);
		}
	}
	return 1;
}

sub build_menu {
	my ($self, $id, $menu) = @_;
	my $last_type = '';
	for (my $i = 0 ; $i < scalar(@{$self->{tree}->{$id}}) ; $i++) {
		my $item = @{$self->{tree}->{$id}}[$i];
		if ($item->{type} eq 'execute') {
			my $icon = PerlPanel::lookup_icon($item->{exec});
			$icon = (-e $icon ? $icon : 'gtk-execute');
			$menu->append($self->menu_item(
				$item->{label},
				$icon,
				sub { system("$item->{exec} &") },
			));
			$last_type = $item->{type};

		} elsif ($item->{type} eq 'separator') {
			if ($last_type ne $item->{type}) {
				$menu->append(Gtk2::SeparatorMenuItem->new);
			}
			$last_type = $item->{type};

		} elsif ($item->{type} eq 'menu') {
			if (defined($self->{tree}->{$item->{id}}) && scalar(@{$self->{tree}->{$item->{id}}}) > 0) {
				my $icon = PerlPanel::lookup_icon($item->{exec});
				$icon = (-e $icon ? $icon : PerlPanel::lookup_icon('gnome-fs-directory'));

				my $menu_item = $self->menu_item(
					($self->{labels}->{$item->{id}} ne '' ? $self->{labels}->{$item->{id}} : $item->{id}),
					$icon
				);
				$menu->append($menu_item);

				my $submenu = Gtk2::Menu->new;
				$menu_item->set_submenu($submenu);
				$self->build_menu($item->{id}, $submenu);

				$last_type = $item->{type};
			}
		}
	}
	return 1;
}

sub get_default_config {
	return {
		label			=> _('Applications'),
		show_control_items	=> 'true',
		apps_in_submenu		=> 'true',
	};
}

sub trim {
	my ($self, $str) = @_;
	$str =~ s/^[\s\r\n\t]*//mg;
	$str =~ s/[\s\r\n\t]*$//mg;
	return $str;
}

1;
