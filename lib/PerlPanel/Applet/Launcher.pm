# $Id: Launcher.pm,v 1.2 2004/09/10 16:23:47 jodrell Exp $
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
use Data::Dumper;
use vars qw($MULTI $LAUNCHER_DIR $LAUNCHER_EDITOR);
use strict;

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

		mkdir($LAUNCHER_DIR);

		if (-x $LAUNCHER_EDITOR) {
			open(FILE, ">$self->{file}") && close(FILE);
			$self->edit;
		} else {
			PerlPanel::warning(_('No desktop item editor could be found.'));
		}

	} elsif (!-r $self->{file}) {
		PerlPanel::warning(_("Error opening file '{file}': {error}", file => $self->{file}, error => $!));

	} else {
		if (!open(FILE, $self->{file})) {
			PerlPanel::warning(_("Error opening file '{file}': {error}", file => $self->{file}, error => $!));

		} else {
			my $data;
			while (<FILE>) {
				$data .= $_;
			}
			close(FILE);
			my ($name, $comment, $icon, $program) = PerlPanel::parse_desktopfile($data);
			PerlPanel::tips->set_tip($self->widget, ($comment ne '' ? sprintf("%s\n%s", $name, $comment) : $name));
			$self->widget->signal_connect('button_release_event', sub {
				if ($_[1]->button == 1) {
					system("$program &");
				} elsif ($_[1]->button == 3) {
					my $menu = Gtk2::Menu->new;
					my $edit_item = Gtk2::ImageMenuItem->new_from_stock('gtk-properties');
					$edit_item->signal_connect('activate', sub { $self->edit });
					my $remove_item = Gtk2::ImageMenuItem->new_from_stock('gtk-remove');
					$remove_item->signal_connect('activate', sub { $self->remove });
					$menu->add($edit_item);
					$menu->add($remove_item);
					$menu->show_all;
					$menu->popup(undef, undef, undef, undef, $_[1]->button, undef);
				}
				return undef;
			});
			if (-r $icon) {
				my $pbf = Gtk2::Gdk::Pixbuf->new_from_file($icon);
				if ($pbf->get_height > PerlPanel::icon_size()) {
					$pbf = $pbf->scale_simple(($pbf->get_width * (PerlPanel::icon_size() / $pbf->get_height)), PerlPanel::icon_size(), 'bilinear');
				}
				$self->widget->child->set_from_pixbuf($pbf);

			} else {
				$self->widget->remove($self->widget->child) if defined($self->widget->child);
				$self->widget->add(Gtk2::Image->new_from_stock('gtk-missing-image', PerlPanel::icon_size_name));

			}
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
	PerlPanel::exec_wait("$LAUNCHER_EDITOR $self->{file}", sub {
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
	for (my $i = 0 ; $i < scalar(@{$PerlPanel::OBJECT_REF->{config}{applets}}) ; $i++) {
		if ((@{$PerlPanel::OBJECT_REF->{config}{applets}})[$i] eq sprintf('Launcher::%s', $self->{id})) {
			$self->widget->destroy;
			splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $i, 1);
			PerlPanel::save_config();
		}
	}
}

1;
