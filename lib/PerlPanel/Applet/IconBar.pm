# $Id: IconBar.pm,v 1.9 2003/06/05 12:56:07 jodrell Exp $
package PerlPanel::Applet::IconBar;
use Image::Size;
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
	foreach my $file (sort @icons) {
		my $filename = sprintf("%s/%s", $self->{icondir}, $file);
		$self->add_icon(PerlPanel::Applet::IconBar::DesktopEntry->new($filename));
	}
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

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{filename}	= shift;
	bless($self, $self->{package});
	$self->parse;
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
		} elsif (/^name\[en_(.+)\]=(.+)$/i) {
			$self->{name} = $2;
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
	} elsif (-e "$ICON_DIR/$self->{icon}") {
		$self->{iconfile} = "$ICON_DIR/$self->{icon}";
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-missing-image', $PerlPanel::OBJECT_REF->icon_size_name);
	}
	if (defined($self->{iconfile})) {
		$self->{pixbuf} = Gtk2::Gdk::Pixbuf->new_from_file($self->{iconfile});
		my ($x0, $y0) = Image::Size::imgsize($self->{iconfile});
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
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, sprintf('%s (right-click to edit)', ($self->{name} || $self->{exec})));
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('button_press_event', sub {
		my ($button, $event) = @_;
		if ($event->button == 1) {
			system($self->{exec}.' &');
		} elsif ($event->button == 3) {
			chomp (my $menueditor = `which gnome-desktop-item-edit`);
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
		}
	});
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

1;
