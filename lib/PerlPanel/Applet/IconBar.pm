# $Id: IconBar.pm,v 1.31 2004/01/16 22:46:33 jodrell Exp $
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
package PerlPanel::Applet::IconBar;
use vars qw($ICON_DIR $MENU_EDITOR $OBJECT_REF);
use strict;

our $ICON_DIR = sprintf('%s/share/pixmaps', $PerlPanel::PREFIX);

chomp (our $MENU_EDITOR = `which perlpanel-item-edit 2> /dev/null`);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	our $OBJECT_REF = $self;
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->widget->set_spacing($PerlPanel::OBJECT_REF->{config}{panel}{spacing});

	$self->{icondir} = sprintf('%s/.%s/icons', $ENV{HOME}, lc($PerlPanel::NAME));
	unless (-e $self->{icondir}) {
		mkdir(sprintf('%s/.%s', $ENV{HOME}, lc($PerlPanel::NAME)));
		mkdir($self->{icondir});
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
		$self->widget->pack_start($button, 0, 0, 0);
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
	push(@{$self->{icons}}, $entry);
	$self->widget->pack_start($entry->widget, 0, 0, 0);
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
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

sub reorder_window {
	my $self = shift;
	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title('Reorder Icons');
	$dialog->set_border_width(12);
	$dialog->set_default_size(250, 200);
	$dialog->add_buttons('gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	my $list = Gtk2::SimpleList->new(
		'Icon'	=> 'pixbuf',
		'Name'	=> 'text',
		file	=> 'text',
	);
	$list->get_column(2)->set_visible(0);
	foreach my $icon (@{$self->{icons}}) {
		push(@{$list->{data}}, [$icon->{pixbuf}, $icon->{name}, $icon->{filename}]);
	}
	$list->set_reorderable(1);
	my $scrwin = Gtk2::ScrolledWindow->new;
	$scrwin->set_policy('never', 'automatic');
	$scrwin->set_shadow_type('in');
	$scrwin->add($list);
	$dialog->vbox->pack_start($scrwin, 1, 1, 0);
	$dialog->signal_connect('response', sub {
		if ($_[1] eq 'ok') {
			my $now = time();
			for (my $i = 0 ; $i < scalar(@{$list->{data}}) ; $i++) {
				my $src_filename = @{@{$list->{data}}[$i]}[2];
				my $dst_filename = sprintf('%s/%d.desktop', $self->{icondir}, $now + $i);
				rename($src_filename, $dst_filename);
			}
		}
		$dialog->destroy;
		if ($_[1] eq 'ok') {
			$PerlPanel::OBJECT_REF->reload;
		}
	});
	$dialog->show_all;
	$dialog->run;
	return 1;
}

package PerlPanel::Applet::IconBar::DesktopEntry;
use Gtk2::Helper;
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

	$self->{widget} = Gtk2::Button->new;
	$self->widget->set_border_width(0);
	$self->widget->add($self->{pixmap});
	$self->widget->set_relief('none');

	$self->widget->signal_connect('button_release_event', sub {
		# this mess reconciles the behaviour of 'button_release_event' with the expected behaviour, which
		# should be that of 'clicked'. The clicked() method is only called if the mouse pointer is within
		# the widget (get_pointer() returns the co-ords of the pointer relative to the top left corner of
		# the widget):
		my ($mouse_pos_x, $mouse_pos_y) = $self->widget->get_pointer;
		my $widget_size_x = $self->widget->size_request->width;
		my $widget_size_y = $self->widget->size_request->height;
		if (
			$mouse_pos_x <= $widget_size_x &&
			$mouse_pos_y <= $widget_size_y &&
			$mouse_pos_x > 0 &&
			$mouse_pos_y > 0

		) {
			$self->clicked($_[1]->button);
		}
		return undef;
	});

	my $tip = $self->{name} || $self->{exec};
	$tip .= "\n".$self->{comment} if ($self->{comment} ne '');
	$PerlPanel::TOOLTIP_REF->set_tip($self->widget, $tip);

	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub clicked {
	my ($self, $button) = @_;
	$self->widget->grab_focus;
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
					'gtk-properties',
				],
				[
					'/Add...',
					undef,
					sub { $self->add },
					undef,
					'<StockItem>',
					'gtk-add',
				],
				[
					'/Reorder...',
					undef,
					sub { $PerlPanel::Applet::IconBar::OBJECT_REF->reorder_window },
					undef,
					'<StockItem>',
					'gtk-index',
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
						sub { system("$self->{nautilus} --no-desktop $self->{icondir} &") },
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
		$self->{menu}->popup(undef, undef, sub { return $self->popup_position(@_) }, 0, $self->widget, undef);
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
	if (-x $MENU_EDITOR) {
		my $mtime = (stat($self->{filename}))[9];
		$self->widget->set_sensitive(0);
		$PerlPanel::OBJECT_REF->exec_wait("$MENU_EDITOR $self->{filename}", sub {
			$self->widget->set_sensitive(1);

			my $newmtime = (stat($self->{filename}))[9];

			if ($newmtime > $mtime) {
				$PerlPanel::OBJECT_REF->reload;
			}
		});
	} else {
		$PerlPanel::OBJECT_REF->warning('No desktop item editor could be found.');
	}
	return 1;
}

sub add {
	my $self = shift;
	chomp (my $MENU_EDITOR = `which perlpanel-item-edit`);
	my $filename = sprintf('%s/.%s/icons/%d.desktop', $ENV{HOME}, lc($PerlPanel::NAME), time());
	if (-x $MENU_EDITOR) {
		open(FILE, ">$filename") && close(FILE);
		my $mtime = time();
		$PerlPanel::OBJECT_REF->exec_wait("$MENU_EDITOR $filename", sub {
			my $newmtime = (stat($filename))[9];

			if ($newmtime > $mtime) {
				$PerlPanel::OBJECT_REF->reload;
			}
		});
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
