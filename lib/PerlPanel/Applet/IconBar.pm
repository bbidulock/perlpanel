# $Id: IconBar.pm,v 1.20 2003/06/23 12:34:00 jodrell Exp $
package PerlPanel::Applet::IconBar;
use vars qw($ICON_DIR);
use strict;

our $ICON_DIR = sprintf('%s/share/pixmaps', $PerlPanel::PREFIX);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->{widget}->set_spacing($PerlPanel::OBJECT_REF->{config}{panel}{spacing});

	$self->{icondir} = sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	unless (-e $self->{icondir}) {
		mkdir(sprintf('%s/.%s', $ENV{HOME}, lc($PerlPanel::NAME)));
		mkdir($self->{icondir});
		return undef;
	}

	opendir(DIR, $self->{icondir});
	my @icons = grep { /\.desktop$/i } readdir(DIR);
	closedir(DIR);

	if (scalar(@icons) < 1) {
		my $dummy = PerlPanel::Applet::IconBar::DesktopEntry->new('dummy');
		my $icon = Gtk2::Image->new_from_stock('gtk-add', $PerlPanel::OBJECT_REF->icon_size_name);
		my $button = Gtk2::Button->new;
		$button->set_relief('none');
		$button->signal_connect('clicked', sub { $dummy->add });
		$button->add($icon);
		$PerlPanel::TOOLTIP_REF->set_tip($button, 'Add Icon');
		$self->{widget}->pack_start($button, 0, 0, 0);
	} else {
		foreach my $file (sort @icons) {
			my $filename = sprintf("%s/%s", $self->{icondir}, $file);
			$self->add_icon(PerlPanel::Applet::IconBar::DesktopEntry->new($filename));
		}
	}

	return 1;
}

sub add_icon {
	my ($self, $entry) = @_;
	$self->{widget}->pack_start($entry->widget, 0, 0, 0);
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 1;
}

sub fill {
	return 1;
}

sub end {
	return 'start';
}

sub get_default_config {
	return undef;
}

package PerlPanel::Applet::IconBar::DesktopEntry;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{filename}	= shift;
	$self->{icondir}	= sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	chomp($self->{nautilus}	= `which nautilus`);
	bless($self, $self->{package});
	$self->parse unless ($self->{filename} eq 'dummy');
	$self->build;
	return $self;
}

sub parse {
	my $self = shift;
	open(ENTRY, $self->{filename}) or die $!;
	# this is not very clever, just try to grep out what we need:
	while (<ENTRY>) {
		chomp;
		if (/^exec=(.+)$/i) {
			$self->{exec} = $1;
		} elsif (/^icon=(.+)$/i) {
			$self->{icon} = $1;
		} elsif (/^name=(.+)$/i) {
			$self->{name} = $1;
		} elsif (/^name\[(.+)\]=(.+)$/i) {
			$self->{name} = $2;
		} elsif (/^comment\[(.+)\]=(.+)$/i) {
			$self->{comment} = $2;
		} elsif (/^comment=(.+)$/i) {
			$self->{comment} = $1;
		}
	}
	close(ENTRY);
	return 1;
}

sub build {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	if (-e $self->{icon}) {
		$self->{iconfile} = $self->{icon};
	} elsif (-e "$ICON_DIR/$self->{icon}" && "$ICON_DIR/$self->{icon}" =~ /\.(png|gif|jpeg|jpg|xpm|bmp)$/) {
		$self->{iconfile} = "$ICON_DIR/$self->{icon}";
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-missing-image', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	if (defined($self->{iconfile})) {
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
		$self->{pixmap} = Gtk2::Image->new_from_pixbuf($self->{pixbuf});
	}
	$self->{pixmap}->set_size_request($PerlPanel::OBJECT_REF->icon_size, $PerlPanel::OBJECT_REF->icon_size);
	my $tip = $self->{name} || $self->{exec};
	$tip .= "\n".$self->{comment} if ($self->{comment} ne '');
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, $tip);
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('button_release_event', sub { $self->clicked($_[1]->button) });
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub clicked {
	my ($self, $button) = @_;
	if ($button == 1) {
		system($self->{exec}.' &');
	} elsif ($button == 3) {
		if (!defined($self->{menu})) {
			$self->{itemfactory} = [
				[
					'/',
					undef,
					undef,
					undef,
					'<Branch>',
				],
				[
					'/Delete...',
					undef,
					sub { $self->delete },
					undef,
					'<StockItem>',
					'gtk-remove',
				],
				[
					'/Edit...',
					undef,
					sub { $self->edit },
					undef,
					'<StockItem>',
					'gtk-preferences',
				],
				[
					'/Add...',
					undef,
					sub { $self->add },
					undef,
					'<StockItem>',
					'gtk-add',
				],
			];
			if (-x $self->{nautilus}) {
				push(
					@{$self->{itemfactory}},
					[
						'/Separator',
						undef,
						undef,
						undef,
						'<Separator>',
					],
					[
						'/View Icon Directory',
						undef,
						sub { system("$self->{nautilus} $self->{icondir} &") },
						undef,
						'<StockItem>',
						'gtk-open'
					],
				);
			}
			$self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
			$self->{factory}->create_items(@{$self->{itemfactory}});
			$self->{menu} = $self->{factory}->get_widget('<main>');
		}
		$self->{menu}->popup(undef, undef, sub { return $self->popup_position(@_) }, 0, $self->{widget}, undef);
	}
	return 1;
}

sub popup_position {
	my $self = shift;
	my $x0 = $_[1];
	if ($PerlPanel::OBJECT_REF->position eq 'top') {
		return ($x0, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		$self->{menu}->realize;
		$self->{menu}->show_all;
		return ($x0, $PerlPanel::OBJECT_REF->screen_height - $self->{menu}->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	}
}

sub edit {
	my $self = shift;
	chomp (my $menueditor = `which perlpanel-item-edit`);
	if (-x $menueditor) {
		# create a lock file for the subshell to remove when the editor is done:
		my $lockfile = "$self->{filename}.lock";
		open(LOCKFILE, ">$lockfile") && close(LOCKFILE);
		# record the desktop file's mod time:
		my $mtime = (stat($self->{filename}))[9];
		# run the editor:
		$self->{widget}->set_sensitive(0);
		system("$menueditor $self->{filename} && rm -f $lockfile &");
		# wait for the lockfile to be removed:
		while (-e $lockfile) {
			Gtk2->main_iteration while (Gtk2->events_pending);
		}
		# reload if the file changed:
		$self->{widget}->set_sensitive(1);
		my $newmtime = (stat($self->{filename}))[9];
		if ($newmtime > $mtime) {
			$PerlPanel::OBJECT_REF->reload;
		}
	} else {
		$PerlPanel::OBJECT_REF->warning('No desktop item editor could be found.');
	}
	return 1;
}

sub add {
	my $self = shift;
	chomp (my $menueditor = `which perlpanel-item-edit`);
	my $filename = sprintf('%s/.%s/icons/%d.desktop', $ENV{HOME}, lc($PerlPanel::NAME), time());
	if (-x $menueditor) {
		# create a lock file for the subshell to remove when the editor is done:
		my $lockfile = "$filename.lock";
		open(LOCKFILE, ">$lockfile") && close(LOCKFILE);
		# touch the file:
		open(FILE, ">$filename") && close(FILE);
		# record the desktop file's mod time:
		my $mtime = (stat($filename))[9];
		# run the editor:
		system("$menueditor $filename && rm -f $lockfile &");
		# wait for the lockfile to be removed:
		while (-e $lockfile) {
			Gtk2->main_iteration while (Gtk2->events_pending);
		}
		# reload if the file changed:
		my $newmtime = (stat($filename))[9];
		if ($newmtime > $mtime) {
			$PerlPanel::OBJECT_REF->reload;
		} else {
			unlink($filename);
		}
	} else {
		$PerlPanel::OBJECT_REF->warning('No desktop item editor could be found.');
	}
	return 1;
}

sub delete {
	my $self = shift;
	unlink($self->{filename});
	$PerlPanel::OBJECT_REF->reload;
}

1;
