# $Id: Pager.pm,v 1.13 2004/10/09 11:50:05 jodrell Exp $
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
package PerlPanel::Applet::Pager;
use Gnome2::Wnck;
use vars qw($MULTI);
use strict;

our $MULTI = 1;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	$self->{id}		= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{config} = PerlPanel::get_config('Pager', $self->{id});

	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;

	$self->{widget} = Gtk2::HBox->new;
	$self->widget->set_border_width(Gtk2->CHECK_VERSION(2,4,0) ? 0 : 1);
	$self->widget->set_size_request(-1, PerlPanel::icon_size());
	$self->widget->signal_connect('button_release_event', sub {
		if ($_[1]->button == 3) {
			$self->popup_menu();
			return 1;
		} else {
			return undef;
		}
	});
	$self->widget->signal_connect('popup_menu', sub { $self->popup_menu });

	$self->{pager} = Gnome2::Wnck::Pager->new($self->{screen});
	$self->{pager}->set_shadow_type('in');
	$self->{pager}->set_n_rows($self->{config}->{rows} > 0 ? $self->{config}->{rows} : 1);

	$self->widget->add($self->{pager});

	PerlPanel::tips->set_tip($self->widget, _('Workspace Pager'));
	$self->widget->show_all;
	return 1;
}

sub popup_menu {
	my $self = shift;
	my $menu = Gtk2::Menu->new;
	my $properties_item	= Gtk2::ImageMenuItem->new_from_stock('gtk-properties');
	$properties_item->signal_connect('activate', sub { $self->prefs_window });
	my $remove_item	= Gtk2::ImageMenuItem->new_from_stock('gtk-remove');
	$remove_item->signal_connect('activate', sub { PerlPanel::remove_applet('Pager', $self->{id}) });
	$menu->add($properties_item);
	$menu->add($remove_item);
	$menu->show_all;
	$menu->popup(undef, undef, sub { return $self->popup_position($menu)	 }, undef, 3, undef);
	return 1;

}

sub prefs_window {
	my $self = shift;
	my $glade = PerlPanel::load_glade('pager');
	$glade->get_widget('pager_prefs_dialog')->set_position('center');
	$glade->get_widget('pager_prefs_dialog')->set_icon(PerlPanel::icon);
	$glade->get_widget('pager_prefs_dialog')->signal_connect('response', sub {
		PerlPanel::save_config();
		shift()->destroy;
	});
	$glade->get_widget('dialog_image')->set_from_pixbuf(PerlPanel::get_applet_pbf('Pager', 48));
	$glade->get_widget('row_spin')->set_value($self->{config}->{rows});
	$glade->get_widget('row_spin')->set_range(1, 100);
	$glade->get_widget('row_spin')->signal_connect('changed', sub {
		$self->{config}->{rows} = $glade->get_widget('row_spin')->get_value;
		$self->{pager}->set_n_rows($self->{config}->{rows});
	});
	$glade->get_widget('pager_prefs_dialog')->show_all;
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
	return 'end';
}

sub get_default_config {
	return {rows => 1};
}

sub popup_position {
	my ($self, $menu) = @_;
	my ($x, undef) = PerlPanel::get_mouse_pointer_position();
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);
	} else {
		$menu->realize;
		return ($x, PerlPanel::screen_height() - $menu->allocation->height - PerlPanel::panel->allocation->height);
	}
}

1;
