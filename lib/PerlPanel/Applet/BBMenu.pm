# $Id: BBMenu.pm,v 1.13 2003/06/18 13:16:16 jodrell Exp $
package PerlPanel::Applet::NewMenu;
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
	$self->add_control_items;
	$self->create_menu;
	$self->{icon} = Gtk2::Image->new_from_stock('gtk-jump-to', $PerlPanel::OBJECT_REF->icon_size_name);
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
	return undef;
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
				} elsif ($cmd eq 'end') {
					pop(@{$self->{paths}});
				} elsif ($cmd eq 'nop') {
					my $name = sprintf('Separator%d', $self->{separatorcount}++);
					my $path = join('/', @{$self->{paths}}, $name);
					push (@{$self->{items}}, [ $path, undef, undef, undef, '<Separator>' ]);
				} elsif ($cmd eq 'exec') {
					my $path = join('/', @{$self->{paths}}, $name);
					push (@{$self->{items}}, [ $path, undef, sub { print "hello\n" }, undef, '<StockItem>', 'gtk-execute' ]);
				}
			}
		}
		undef $self->{paths}, $self->{separatorcount};
		return 1;
	}
}

sub add_control_items {
	my $self = shift;
	push(@{$self->{items}}, (
		[
			'/CtrlSeparator',
			undef,
			undef,
			undef,
			'<Separator>'
		],
		[
			'/About...',
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
			'/Configure...',
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
			'/Reload',
			undef,
			sub {
				$PerlPanel::OBJECT_REF->reload;
			},
			undef,
			'<StockItem>',
			'gtk-refresh',
		],
		[
			'/Quit',
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
	if ($PerlPanel::OBJECT_REF->{config}{panel}{position} eq 'top') {
		return (0, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		$self->{menu_widget}->realize;
		$self->{menu_widget}->show_all;
		return (0, $PerlPanel::OBJECT_REF->{config}{screen}{height} - $self->{menu_widget}->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	}
}

1;
