# $Id: BBMenu.pm,v 1.9 2003/06/10 13:30:05 jodrell Exp $
package PerlPanel::Applet::BBMenu;
use vars qw(@BBMenus);
use strict;

our @BBMenus = (
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
	$self->create_itemfactory($self->{menutree}, '');
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

sub parse_menufile {
	my $self = shift;
	foreach my $menufile (@BBMenus) {
		$menufile = sprintf($menufile, $ENV{HOME});
		if (-e $menufile) {
			$self->{menufile} = $menufile;
			last;
		}
	}
	if (!defined($self->{menufile})) {
		$PerlPanel::OBJECT_REF->error("Couldn't find a menu file anywhere in\n\t".join("\n\t", @BBMenus));
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
		my $parentref;
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
					$self->{menutree} = [];
					$parentref = $self->{menutree};
				} elsif ($cmd eq 'submenu') {
					my $branch = [];
					my $branchnode = [$name, $branch];
					push(@{$parentref}, $branchnode);
					$self->{parents}{$branch} = $parentref;
					$parentref = $branch;
				} elsif ($cmd eq 'end') {
					if (defined($self->{parents}{$parentref})) {
						# in a submenu
						$parentref = $self->{parents}{$parentref};
					} else {
						# end of the menu
						undef $parentref;
					}
				} elsif ($cmd eq 'exec') {
					push(@{$parentref}, { name => $name, val => $val });
				} elsif ($cmd eq 'nop') {
					push(@{$parentref}, 'separator');
				}
			}
		}
		return 1;
	}
}

sub create_itemfactory {
	my ($self, $branch, $path) = @_;
	return undef if (scalar(@{$branch}) < 1);
	foreach my $twig (@{$branch}) {
		if (ref($twig) eq 'HASH') {
			my $item = [
				"$path/$twig->{name}",
				undef,
				sub { system("$twig->{val} &") },
				undef,
				'<StockItem>',
				'gtk-execute',
			];
			push(@{$self->{itemfactory}}, $item);
		} elsif (ref($twig) eq 'ARRAY') {
			next if (scalar(@{@{$twig}[1]}) < 1);
			my $item = [
				"$path/".@{$twig}[0],
				undef,
				undef,
				undef,
				'<Branch>',
			];
			push(@{$self->{itemfactory}}, $item);
			$self->create_itemfactory(@{$twig}[1], "$path/".@{$twig}[0]);
		} elsif ($twig eq 'separator') {
			my $item = [
			 "$path/",
			 undef,
			 undef,
			 undef,
			 '<Separator>',
			];
			push(@{$self->{itemfactory}}, $item);
		}
	}
	$self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
	$self->{factory}->create_items(@{$self->{itemfactory}});
	return 1;
}

sub popup {
	my $self = shift;
	if (!defined($self->{menu_widget})) {
		$self->{menu_widget} = $self->{factory}->get_widget('<main>');
	}
	$self->{menu_widget}->popup(undef, undef, sub { return $self->popup_position(@_); }, 0, $self->{widget}, undef);
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x0, $y0) = splice(@_, 1, 2);
	if ($PerlPanel::OBJECT_REF->{config}{panel}{position} eq 'top') {
		return ($x0, $y0);
	} else {
		my $toplevel_items = 0;
		foreach my $itemref (@{$self->{itemfactory}}) {
			my @item = @{$itemref};
			if ($item[0] =~ /^\/([^\/]+)$/) {
				$toplevel_items++;
			}
		}
		return ($x0, $y0 - (20 * $toplevel_items));
	}
}

sub get_default_config {
	return undef;
}

1;
