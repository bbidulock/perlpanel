# $Id: BBMenu.pm,v 1.36 2004/01/08 00:36:28 jodrell Exp $
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
use File::Basename qw(basename);
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

our @ICON_DIRECTORIES = (
	sprintf('%s/.perlpanel/icon-files', $ENV{HOME}),
	'%s/share/icons/gnome/48x48/apps',
	'%s/share/pixmaps',
);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->parse_menufile;
	$self->add_control_items if ($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{show_control_items} eq 'true');
	$self->create_menu;
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
	$self->widget->set_relief($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{relief} eq 'true' ? 'half' : 'none');
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Menu');
	$self->widget->signal_connect('clicked', sub { $self->popup });
	$self->widget->grab_focus;
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
		icon => sprintf('%s/share/pixmaps/%s-menu-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)),
		show_control_items => 'true',
		label	=> 'Menu',
		relief	=> 'true',
	};
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
	if (!defined($self->{menufile})) {
		$PerlPanel::OBJECT_REF->error("Couldn't find a menu file anywhere in\n\t".join("\n\t", @menufiles));
		return undef;
	} else {
		open(MENU, $self->{menufile}) or $PerlPanel::OBJECT_REF->error("Error opening $self->{menufile}: $!") and return undef;
		$self->{menudata} = [];
		while (<MENU>) {
			s/^\s*//g;
			s/\s*$//g;
			next if (/^#/ || /^$/);
			push(@{$self->{menudata}}, $_);
		}
		close(MENU);
		$self->{items} = [ [ '/', undef, undef, undef, '<Branch>' ] ];
		$self->{paths} = [];
		$self->{separatorcount} = 0;
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
				if ($cmd eq 'begin') {
					push(@{$self->{paths}}, '');
				} elsif ($cmd eq 'submenu') {
					push(@{$self->{paths}}, $name);
					my $path = join('/', @{$self->{paths}});
					push(@{$self->{items}}, [ $path, undef, undef, undef, '<Branch>', ]);
				} elsif ($cmd eq 'end') {
					pop(@{$self->{paths}});
				} elsif ($cmd eq 'nop') {
					my $name = sprintf('Separator%d', $self->{separatorcount}++);
					my $path = join('/', @{$self->{paths}}, $name);
					push(@{$self->{items}}, [ $path, undef, undef, undef, '<Separator>' ]);
				} elsif ($cmd eq 'exec') {
					my $path = join('/', @{$self->{paths}}, $name);
					push(@{$self->{entries}}, [ $path, $val ]);
					push(@{$self->{items}}, [ $path, undef, sub { system(sprintf('%s &', $val)) }, undef, '<StockItem>', 'gtk-execute' ]);
				}
			}
		}
		undef $self->{paths}, $self->{separatorcount};
		return 1;
	}
}

sub add_control_items {
	my $self = shift;
	push(@{$self->{items}},
		[
			'/CtrlSeparator0',
			undef,
			undef,
			undef,
			'<Separator>',
		],
	);
	chomp(my $xscreensaver = `which xscreensaver-command 2> /dev/null`);
	if (-x $xscreensaver) {
		push(@{$self->{items}},
			[
				'/Lock Screen',
				undef,
				sub { system("$xscreensaver -lock &") },
				undef,
				'<StockItem>',
				'gtk-dialog-error',
			]
		);
	}
	push(@{$self->{items}}, (
		[
			'/Run Program...',
			undef,
			sub {
				require('Commander.pm');
				my $commander = PerlPanel::Applet::Commander->new;
				$commander->configure;
				$commander->run;
			},
			undef,
			'<StockItem>',
			'gtk-execute',
		],
		[
			'/CtrlSeparator1',
			undef,
			undef,
			undef,
			'<Separator>',
		],
		[
			"/Configure $PerlPanel::NAME...",
			undef,
			sub {
				require('Configurator.pm');
				my $configurator = PerlPanel::Applet::Configurator->new;
				$configurator->configure;
				$configurator->init;
			},
			undef,
			'<StockItem>',
			'gtk-preferences',
		],
		[
			"/Reload $PerlPanel::NAME",
			undef,
			sub {
				$PerlPanel::OBJECT_REF->reload;
			},
			undef,
			'<StockItem>',
			'gtk-refresh',
		],
		[
			'/CtrlSeparator2',
			undef,
			undef,
			undef,
			'<Separator>',
		],
		[
			"/About $PerlPanel::NAME...",
			undef,
			sub {
				require('About.pm');
				my $about = PerlPanel::Applet::About->new;
				$about->configure;
				$about->about;
			},
			undef,
			'<StockItem>',
			'gtk-dialog-info',
		],

	));
	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
	$self->{factory}->create_items(@{$self->{items}});
	$self->apply_icons;
	$self->{menu_widget} = $self->{factory}->get_widget('<main>');
	$self->{menu_widget}->show_all;
	return 1;
}

sub popup {
	my $self = shift;
	$self->{menu_widget}->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, $self->widget, 0);
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x, undef) = $PerlPanel::OBJECT_REF->get_widget_position($self->widget);
	$x = 0 if ($x == 1);
	if ($PerlPanel::OBJECT_REF->position eq 'top') {
		return ($x, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		$self->{menu_widget}->realize;
		$self->{menu_widget}->show_all;
		return ($x, $PerlPanel::OBJECT_REF->screen_height - $self->{menu_widget}->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	}
}

# this is a kludgy system that attempts to associate icons with
# entries in the menu. It looks in a set of hard-coded directories
# for icons that have the same name as the entry's program. You
# can control what icons are used by placing icons of your choice in
# $HOME/.perlpanel/icon-files/, which is the first location looked at.

sub apply_icons {
	my $self = shift;
	foreach my $entry (@{$self->{entries}}) {
		my ($path, $executable) = @{$entry};
		my $item = $self->{factory}->get_widget('<main>'.$path);
		my $icon_file = $self->detect_icon($executable);
		my $icon;
		if (-e $icon_file) {
			$icon = $self->generate_icon($icon_file);
			$item->set_image($icon);
		}
	}
	return 1;
}

sub detect_icon {
	my ($self, $executable) = @_;
	my $program = lc(basename($executable));
	($program, undef) = split(/\s/, $program, 2);
	foreach my $dir (@ICON_DIRECTORIES) {
		my $file = sprintf('%s/%s.png', sprintf($dir, $PerlPanel::PREFIX), $program);
		if (-e $file) {
			return $file;
		}
	}
	return undef;
}

sub generate_icon {
	my ($self, $file) = @_;
	my $pbf = Gtk2::Gdk::Pixbuf->new_from_file($file);
	my $x0 = $pbf->get_width;
	my $y0 = $pbf->get_height;
	if ($x0 != @{$PerlPanel::SIZE_MAP{tiny}}[0] || $y0 != @{$PerlPanel::SIZE_MAP{tiny}}[0]) {
		my ($x1, $y1);
		if ($x0 > $y0) {
			# image is landscape:
			$x1 = @{$PerlPanel::SIZE_MAP{tiny}}[0];
			$y1 = int(($y0 / $x0) * @{$PerlPanel::SIZE_MAP{tiny}}[0]);
		} elsif ($x0 == $y0) {
			# image is square:
			$x1 = @{$PerlPanel::SIZE_MAP{tiny}}[0];
			$y1 = @{$PerlPanel::SIZE_MAP{tiny}}[0];
		} else {
			# image is portrait:
			$x1 = int(($x0 / $y0) * @{$PerlPanel::SIZE_MAP{tiny}}[0]);
			$y1 = @{$PerlPanel::SIZE_MAP{tiny}}[0];
		}
		$pbf = $pbf->scale_simple($x1, $y1, 'bilinear');
	}
	return Gtk2::Image->new_from_pixbuf($pbf);
}

1;
