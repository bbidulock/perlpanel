# $Id: BBMenu.pm,v 1.21 2003/07/03 20:44:06 jodrell Exp $
package PerlPanel::Applet::BBMenu;
use vars qw(@menufiles);
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
	'/usr/local/share/openbox/menu',
	'/usr/share/openbox/menu',
	'/usr/local/share/waimea/menu',
	'/usr/share/waimea/menu',
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
	$self->{iconfile} = $PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{iconfile};
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
		$self->{icon} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	} else {
		$self->{icon} = Gtk2::Image->new_from_stock('gtk-jump-to', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	$self->{widget}->add($self->{icon});
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'Menu');
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub { $self->popup });
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
		iconfile => sprintf('%s/share/pixmaps/%s-menu-icon.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)),
		show_control_items => 'true',
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
	chomp(my $xscreensaver = `which xscreensaver-command`);
	push(@{$self->{items}},
		[
			'/CtrlSeparator',
			undef,
			undef,
			undef,
			'<Separator>',
		],
	);
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
		[
			'/Configure Panel...',
			undef,
			sub {
				my $configurator = PerlPanel::Applet::Configurator->new;
				$configurator->configure;
				$configurator->init;
			},
			undef,
			'<StockItem>',
			'gtk-preferences',
		],
		[
			'/Reload Panel',
			undef,
			sub {
				$PerlPanel::OBJECT_REF->reload;
			},
			undef,
			'<StockItem>',
			'gtk-refresh',
		],
		[
			'/Close Panel',
			undef,
			sub {
				$PerlPanel::OBJECT_REF->shutdown;
			},
			undef,
			'<StockItem>',
			'gtk-quit',
		],
	));
	return 1;
}

sub create_menu {
	my $self = shift;
	$self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
	$self->{factory}->create_items(@{$self->{items}});
	$self->{menu_widget} = $self->{factory}->get_widget('<main>');
	$self->{menu_widget}->show_all;
	return 1;
}

sub popup {
	my $self = shift;
	$self->{menu_widget}->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, $self->{widget}, 0);
	return 1;
}

sub popup_position {
	my $self = shift;
	if ($PerlPanel::OBJECT_REF->position eq 'top') {
		return (0, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		$self->{menu_widget}->realize;
		$self->{menu_widget}->show_all;
		return (0, $PerlPanel::OBJECT_REF->screen_height - $self->{menu_widget}->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	}
}

1;
