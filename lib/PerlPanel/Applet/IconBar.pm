# $Id: IconBar.pm,v 1.4 2003/05/29 16:04:46 jodrell Exp $
package PerlPanel::Applet::IconBar;
use File::Basename;
use Image::Size;
use Image::Magick;
use vars qw($ICON_SPACING $ICON_DIR);
use strict;

our $ICON_SPACING	= 2;
our $ICON_DIR		= '/usr/share/pixmaps';

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->{widget}->set_spacing($ICON_SPACING);
	$self->{icondir} = sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	opendir(DIR, $self->{icondir}) or print STDERR "Error opening $self->{icondir}: $!\n" and return undef;
	my @icons = grep { /\.desktop$/i } readdir(DIR);
	closedir(DIR);
	if (scalar(@icons) < 1) {
		print STDERR "Error: no .desktop files found in $self->{icondir}\n" and exit;
	} else {
		foreach my $file (sort @icons) {
			my $filename = sprintf("%s/%s", $self->{icondir}, $file);
			$self->add_icon(PerlPanel::Applet::IconBar::DesktopEntry->new($filename));
		}
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
		$self->{pixmap} = Gtk2::Image->new_from_file($self->rescale($self->{icon}));
	} elsif (-e "$ICON_DIR/$self->{icon}") {
		$self->{pixmap} = Gtk2::Image->new_from_file($self->rescale("$ICON_DIR/$self->{icon}"));
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-missing-image', 'menu');
	}
	$self->{pixmap}->set_size_request($PerlPanel::ICON_SIZE, $PerlPanel::ICON_SIZE);
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, ($self->{name} || $self->{exec}));
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub { system($self->{exec}." &") });
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub rescale {
	my ($self, $image) = @_;
	my ($x, $y) = Image::Size::imgsize($image);
	my $cachefile = sprintf('%s/.%s/iconcache/%s', $ENV{HOME}, lc($PerlPanel::NAME), File::Basename::basename($image));
	if ($x <= $PerlPanel::ICON_SIZE && $y <= $PerlPanel::ICON_SIZE) {
		# image is small enough already:
		return $image;
	} elsif (-e $cachefile) {
		# already got a cached version:
		return $cachefile;
	} else {
		mkdir(sprintf('%s/.%s/iconcache', $ENV{HOME}, lc($PerlPanel::NAME)));
		my $geometry;
		if ($x > $y) {
			# image is landscape:
			$geometry = sprintf('%dx%d', $PerlPanel::ICON_SIZE, $PerlPanel::ICON_SIZE * ($y / $x));
		} elsif ($x == $y) {
			# image is square:
			$geometry = sprintf('%dx%d', $PerlPanel::ICON_SIZE, $PerlPanel::ICON_SIZE);
		} else {
			# image is portrait:
			$geometry = sprintf('%dx%d', $PerlPanel::ICON_SIZE, $PerlPanel::ICON_SIZE * ($x / $y));
		}
		my $img = Image::Magick->new;
		$img->Read(filename => $image);
		$img->Resize(geometry=>$geometry);
		$img->Write(filename => $cachefile);
		return $cachefile;
	}
}

1;
