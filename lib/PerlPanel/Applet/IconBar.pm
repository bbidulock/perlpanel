# $Id: IconBar.pm,v 1.1.1.1 2003/05/27 14:54:42 jodrell Exp $
package PerlPanel::Applet::IconBar;
use Config::Simple;
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
	opendir(DIR, $self->{icondir}) or die $!;
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
	return 0;
}

sub fill {
	return 0;
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
		$self->{pixmap} = Gtk2::Image->new_from_file($self->{icon});
	} elsif (-e "$ICON_DIR/$self->{icon}") {
		$self->{pixmap} = Gtk2::Image->new_from_file("$ICON_DIR/$self->{icon}");
	} else {
		$self->{pixmap} = Gtk2::Image->new_from_stock('gtk-open', 'menu');
	}
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, ($self->{name} || $self->{exec}));
	$self->{widget}->add($self->{pixmap});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub { system($self->{exec}." &") });
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

1;
