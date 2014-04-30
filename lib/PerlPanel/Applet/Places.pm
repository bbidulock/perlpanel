package PerlPanel::Applet::Places;
use base 'PerlPanel::MenuBase';
use URI::Escape;
use strict;
use warnings;

sub configure {
	my $self = shift;
	my $icon;

	$self->{HOME} = $ENV{HOME};

	$self->{XDG_CONFIG_HOME} = $ENV{XDG_CONFIG_HOME};
	$self->{XDG_CONFIG_HOME} = "$self->{HOME}/.config" unless $self->{XDG_CONFIG_HOME};
	$ENV{XDG_CONFIG_HOME} = $self->{XDG_CONFIG_HOME};

	$self->{XDG_DATA_HOME} = $ENV{XDG_DATA_HOME};
	$self->{XDG_DATA_HOME} = "$self->{HOME}/.local/share" unless $self->{XDG_DATA_HOME};
	$ENV{XDG_DATA_HOME} = $self->{XDG_DATA_HOME};

	$self->{files} = [
		"$self->{XDG_CONFIG_HOME}/gtk-3.0/bookmarks",
		"$self->{XDG_CONFIG_HOME}/spacefm/bookmarks",
		"$self->{HOME}/.gtk-bookmarks",
	];

	my $wg = $self->{widget} = Gtk2::Button->new;
	my $cf = $self->{config} = PerlPanel::get_config('Places');
	$cf = {} unless $cf;
	$wg->set_relief(($cf->{relief} and $cf->{relief} eq 'true') ? 'half' : 'none');
	my $pb = $self->{pixbuf} = PerlPanel::get_applet_pbf('Places', PerlPanel::icon_size);
	if ($cf->{arrow} and $cf->{arrow} eq 'true') {
		my $fixed = Gtk2::Fixed->new;
		$fixed->put(Gtk2::Image->new_from_pixbuf($pb), 0, 0);
		my $arrow = Gtk2::Gdk::Pixbuf->new_from_file(
				snrpintf('%s/share/%s/menu-arrow-%s.png', $PerlPanel::PREFIX,
					lc($PerlPanel::NAME), lc(PerlPanel::position)));
		my $x = $pb->get_width - $arrow->get_width;
		my $y = PerlPanel::position eq 'bottom' ? 0 : $pb->get_height - $arrow->get_height;
		$fixed->put(Gtk2::Image->new_from_pixbuf($arrow), $x, $y);
		$icon = $self->{icon} = Gtk2::Alignment->new(0.5, 0.5, 0, 0);
		$icon->add($fixed);
	} else {
		$icon = $self->{icon} = Gtk2::Image->new_from_pixbuf($pb);
	}
	if (not $cf->{label}) {
		$wg->add($icon);
	} else {
		my $hb = Gtk2::HBox->new;
		my $lb = Gtk2::Label->new($cf->{label});
		$wg->add($hb);
		$hb->set_border_width(0);
		$hb->set_spacing(0);
		$hb->pack_start($icon, 0, 0, 0);
		$hb->pack_start($lb, 1, 1, 0);
	}
	PerlPanel::tips->set_tip($wg, _('Places'));
	$wg->signal_connect(clicked=>sub{$self->clicked});
	$self->{mtime} = 0;
	PerlPanel::add_timeout(1000, sub{
			$self->create_menu if ($self->file_age > $self->{mtime});
			return 1;
	});
	$wg->show_all;
	return 1;
}

sub widget {
	return shift->{widget};
}

sub clicked {
	my $self = shift;
	$self->create_menu;
	$self->popup;
}

sub create_menu {
	my $self = shift;
	$self->{menu} = Gtk2::Menu->new;
	$self->add_places;
	return 1;
}

sub add_places {
	my $self = shift;
	my %places = ();

	my %names = (
		DESKTOP		=> [ Desktop	=>_('Desktop'),		q(user-desktop)		],
		DOWNLOAD	=> [ Download	=>_('Download'),	q(folder-download)	],
		TEMPLATES	=> [ Templates	=>_('Templates'),	q(folder-templates)	],
		PUBLICSHARE	=> [ Public	=>_('Public'),		q(folder-publicshare)	],
		DOCUMENTS	=> [ Documents	=>_('Documents'),	q(folder-documents)	],
		MUSIC		=> [ Music	=>_('Music'),		q(folder-music)		],
		PICTURES	=> [ Pictures	=>_('Pictures'),	q(folder-pictures)	],
		VIDEOS		=> [ Videos	=>_('Videos'),		q(folder-videos)	],
	);

	if (-r "$self->{XDG_CONFIG_HOME}/user-dirs.dirs") {
		my @todelete = ();
		foreach my $place (keys %names) {
			$places{$place} = [];
			chomp(my $dir = `sh -c ".  $self->{XDG_CONFIG_HOME}/user-dirs.dirs; echo -n \\"\$XDG_${place}_DIR\\""`);
			next if not $dir or $dir eq $self->{HOME} or not -d $dir;
			$places{$place}[0] = $dir;
			$places{$place}[1] = $dir;
			$places{$place}[1] =~ s{.*/}{};
		}
	}
	foreach my $place (keys %names) {
		$places{$place}[2] = $names{$place}[2];
		next if $places{$place}[0];
		my $dir = "$self->{HOME}/$names{$place}[0]";
		next unless -d $dir;
		$places{$place}[0] = "$self->{HOME}/$names{$place}[0]";
		$places{$place}[1] = $names{$place}[1];
	}

	$places{HOME}	    = [ $self->{HOME},	    _('Home'),		q(user-home)		];
	$places{ROOT}	    = [ '/',		    _('File System'),	q(folder)		];

	foreach my $place (keys %places) {
		if (my $dir = $places{$place}[0]) {
			$dir = q(file://).join('/',map{uri_escape($_)}split(/\//,$dir));
			$places{$place}[0] = $dir;
		}
	}

	$places{COMPUTER}   = [ q(computer:///),    _('Computer'),	q(computer)		];
	$places{NETWORK}    = [ q(network:///),	    _('Network'),	q(network)		];
	$places{TRASH}	    = [ q(trash:///),	    _('Trash'),		q(user-trash)		];

	my @marks = ();
	foreach my $file (@{$self->{files}}) {
		next unless -s "$file";
		next unless open(my $fh, '<', $file);
		while (<$fh>) { chomp;
			my($uri,$name,$icon) = split(/\s+/,$_,2);
			if ($uri =~ m{^file:}) {
				$icon = q(folder);
			} elsif ($uri =~ m{^(http|https|ftp|sftp|smb):}) {
				$icon = q(folder-remote);
			} else {
				$icon = q(folder);
			}
			push @marks, [ $uri, $name, $icon ];
		}
		close($fh);
		last if @marks;
	}
	$self->{mtime} = $self->file_age;

	foreach my $place ((map{$places{$_}}qw(HOME ROOT DESKTOP DOWNLOAD TEMPLATES PUBLICSHARE DOCUMENTS MUSIC
				PICTURES VIDEOS COMPUTER NETWORK TRASH)), @marks) {
		if ($place->[0]) {
			$self->menu->append($self->menu_item($place->[1],PerlPanel::lookup_icon($place->[2]),
				sub{
					# print STDERR "would launch: \"pcmanfm --no-desktop '$place->[0]'\"\n";
					PerlPanel::launch("pcmanfm --no-desktop '$place->[0]'");
				}));
		}
	}
	return 1;
}

sub file_age {
	my $self = shift;
	my $latest = 0;
	my $mtime;
	foreach my $file (@{$self->{files}}) {
		next unless -r $file;
		$mtime = (stat($file))[9];
		$latest = $mtime if $mtime > $latest;
	}
	return $latest;
}

sub get_default_config {
	return {
		label	=> _('Places'),
		relief	=> 'true',
		arrow	=> 'false',
	};
}

1;
