# $Id: Launcher.pm,v 1.17 2004/11/26 12:47:54 jodrell Exp $
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
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel::Applet::Launcher;
use PerlPanel::DesktopEntry;
use vars qw($MULTI $LAUNCHER_DIR $LAUNCHER_EDITOR);
use strict;

$PerlPanel::DesktopEntry::VERBOSE = 0;

our $MULTI = 1;
our $LAUNCHER_DIR = sprintf('%s/.%s/launchers', $ENV{HOME}, lc($PerlPanel::NAME));
chomp (our $LAUNCHER_EDITOR = `which perlpanel-item-edit 2> /dev/null`);

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->{widget}->set_relief('none');
	$self->widget->add(Gtk2::Image->new);
	$self->init;

	return 1;
}

sub init {
	my $self = shift;

	$self->{file} = sprintf('%s/%s.desktop', $LAUNCHER_DIR, $self->{id});

	if (!-e $self->{file}) {

		PerlPanel::mkpath($LAUNCHER_DIR);
		if (!-d $LAUNCHER_DIR) {
			print STDERR "*** Error: couldn't create launcher directory '$LAUNCHER_DIR'\n";
			exit 256;
		}

		if (-x $LAUNCHER_EDITOR) {
			open(FILE, ">$self->{file}") && close(FILE);
			$self->edit;
		} else {
			PerlPanel::warning(_('No desktop item editor could be found.'));
		}

	} else {
		my $entry = PerlPanel::DesktopEntry->new($self->{file});

		if (!defined($entry) || !$entry->is_valid || $entry->Name eq '' || $entry->Exec eq '') {
			PerlPanel::warning(_('Launcher file is empty or invalid. Click OK to edit.'), sub { $self->edit });

		} else {

			my $name	= $entry->Name(PerlPanel::locale);
			my $comment	= $entry->Comment(PerlPanel::locale);
			my $program	= $entry->Exec(PerlPanel::locale);
			my $icon	= $entry->Icon(PerlPanel::locale);

			PerlPanel::tips->set_tip($self->widget, ($comment ne '' ? sprintf("%s\n%s", $name, $comment) : $name));

			$self->widget->signal_handler_disconnect($self->{sigid}) if (defined($self->{sigid}));
			$self->{sigid} = $self->widget->signal_connect('button_release_event', sub {
				my ($mouse_pos_x, $mouse_pos_y) = $self->widget->get_pointer;
				my $widget_size_x = $self->widget->size_request->width;
				my $widget_size_y = $self->widget->size_request->height;
				if (
					$mouse_pos_x <= $widget_size_x &&
					$mouse_pos_y <= $widget_size_y &&
					$mouse_pos_x > -1 &&
					$mouse_pos_y > -1	

				) {

					if ($_[1]->button == 1) {
						PerlPanel::launch($program, $entry->StartupNotify);

					} elsif ($_[1]->button == 3) {
						my $menu = Gtk2::Menu->new;

						my $exec_item = Gtk2::ImageMenuItem->new_from_stock('gtk-execute');
						$exec_item->signal_connect('activate', sub { $menu->destroy ; PerlPanel::launch($program, $entry->StartupNotify) });

						my $edit_item = Gtk2::ImageMenuItem->new_from_stock('gtk-properties');
						$edit_item->signal_connect('activate', sub { $menu->destroy ; $self->edit });

						my $remove_item = Gtk2::ImageMenuItem->new_from_stock('gtk-remove');
						$remove_item->signal_connect('activate', sub { $self->remove });

						my $add_item = Gtk2::ImageMenuItem->new_from_stock('gtk-add');
						$add_item->signal_connect('activate', sub { $self->add_launcher });

						$menu->add($exec_item);
						$menu->add($edit_item);
						$menu->add($remove_item);
						$menu->add(Gtk2::SeparatorMenuItem->new);
						$menu->add($add_item);
						$menu->show_all;
						$menu->popup(undef, undef, sub { return $self->popup_position($menu) }, undef, $_[1]->button, undef);

					}
				}
				return undef;
			});

			if (-r $icon) {
				my $pbf = Gtk2::Gdk::Pixbuf->new_from_file_at_size($icon, PerlPanel::icon_size(), PerlPanel::icon_size());
				$self->widget->child->set_from_pixbuf($pbf);

			} else {
				$icon =~ s/\.png$//;
				$icon = PerlPanel::lookup_icon($icon);
				if (-r $icon) {
					my $pbf = Gtk2::Gdk::Pixbuf->new_from_file_at_size($icon, PerlPanel::icon_size(), PerlPanel::icon_size());
					$self->widget->child->set_from_pixbuf($pbf);

				} else {
					$self->widget->remove($self->widget->child) if defined($self->widget->child);
					my $pbf = $PerlPanel::OBJECT_REF->panel->render_icon('gtk-missing-image', 'dialog')->scale_simple(
						PerlPanel::icon_size,
						PerlPanel::icon_size,
						'bilinear'
					);
					$self->widget->add(Gtk2::Image->new_from_pixbuf($pbf));

				}
			}

			$self->widget->drag_source_set(
				['button1_mask', 'button3_mask'],
				['copy', 'move'],
				{'target' => "text/uri-list", 'flags' => [], 'info' => 0},
			);
			$self->widget->signal_connect('drag_data_get', sub { $self->get_drag_data(@_) });

		}
	}
	$self->widget->show_all;
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

sub get_default_config {
	return undef;
}

sub edit {
	my $self = shift;
	my $mtime = time();
	$self->widget->set_sensitive(undef);
	PerlPanel::exec_wait("$LAUNCHER_EDITOR $self->{file}", sub {
		$self->widget->set_sensitive(1);
		my $newmtime = (stat($self->{file}))[9];

		if ($newmtime > $mtime) {
			# the editor modified the file, so reload:
			$self->init;
		}
	});
	return 1;
}

sub remove {
	my $self = shift;
	unlink($self->{file});
	PerlPanel::remove_applet('Launcher', $self->{id});
	return 1;
}

sub popup_position {
	my ($self, $menu) = @_;
	my ($x, undef) = PerlPanel::get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);
	} else {
		$menu->realize;
		return ($x, PerlPanel::screen_height() - $menu->allocation->height - PerlPanel::panel->allocation->height);
	}
}

### c+p'd from MenuBase.pm:
sub add_launcher {
	my $self = shift;
	my $applet = 'Launcher';
	# place the new applet next to the menu:
	my $idx = 0;
	foreach my $applet ($PerlPanel::OBJECT_REF->{hbox}->get_children) {
		last if ($applet eq $self->widget);
		$idx++;
	}
	if ($idx >= 0) {
		splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $idx+1, 0, $applet);
		$PerlPanel::OBJECT_REF->load_applet($applet, $idx+1);
		PerlPanel::save_config();
	}
	return 1;
}

sub get_drag_data {
	my ($self, $widget, $context, $data, $info, $time) = @_;
	my $uri = Gnome2::VFS->make_uri_canonical($self->{file});
	$data->set($data->target, 8, $uri);
	return 1;
}

1;
