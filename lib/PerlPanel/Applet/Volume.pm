# $Id: Volume.pm,v 1.3 2005/01/10 10:25:19 jodrell Exp $
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
# Copyright: (C) 2005 Eric Andreychek <eric@openthought.net>
#
package PerlPanel::Applet::Volume;
$PerlPanel::Applet::Volume::VERSION = '0.16';
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});

	my $loaded = 0;
	eval {
		# we use a require() here instead of use(), because use() causes a compile-time
		# error that the PerlPanel::load_applet catches, but require() causes a run-time
		# error that the eval() catches:
		require Audio::Mixer && ($loaded = 1);
	};
	if ($loaded == 0) {
		PerlPanel::warning(_('The Volume applet requires the Audio::Mixer module!'));
		$self->{active} = 0;

	} else {
		$self->{active} = 1;

	}

	return $self;
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Volume');
	$self->{widget} = Gtk2::Button->new;
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('volume', PerlPanel::icon_size)));
	$self->widget->set_relief('none');

	if ($self->{active} == 0) {
		$self->widget->set_sensitive(0);
		PerlPanel::tips->set_tip($self->widget, _('Volume Control (disabled due to missing Audio::Mixer dependency)'));

	} else {
		$self->widget->signal_connect('clicked', sub { $self->_handle_click });
		PerlPanel::tips->set_tip($self->widget, _('Volume Control'));

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

sub end {
	return 'start';
}

sub get_default_config {
	return {
		channel => 'vol',
	};
}

sub _handle_click {
	my $self = shift;
	if (defined($self->{window})) {
		$self->_remove_popup;

	} else {
		$self->_mix;

	}
	return 1;

}

sub _remove_popup {
	my $self = shift;
	Gtk2->grab_remove($self->{window});
	$self->{window}->destroy;
	delete($self->{window});
	return 1;
}

sub _mix {
	my $self = shift;

	$self->{window} = Gtk2::Window->new('popup');

	my $vbox = Gtk2::VBox->new(0, 0);

	my ($cur_val) = Audio::Mixer::get_cval($self->{config}{channel});
	my $adj = Gtk2::Adjustment->new(-$cur_val, -100, 0.0, 5, 10, 0.0);
	$adj->signal_connect(value_changed => \&_update_mixer, $self );
	my $vscale = Gtk2::VScale->new($adj);

	$vscale->set_size_request(-1, 100);
	$vscale->set_update_policy('continuous');
	$vscale->set_digits(1);
	$vscale->set_draw_value(0);

	$vbox->pack_start(Gtk2::Label->new(_('+')), 1, 1, 0);

	$vbox->pack_start($vscale, 1, 1, 0);
	$vscale->show;

	$vbox->pack_start(Gtk2::Label->new(_('-')), 1, 1, 0);

	$vbox->set_border_width(6);

	my $port = Gtk2::Viewport->new;
	$port->set_shadow_type('out');
	$port->add($vbox);
	$self->{window}->add($port);

	$self->{window}->set_position('mouse');
	$self->{window}->set_title(_('Audio Mixer'));
	$self->{window}->set_icon(PerlPanel::icon);

	# Determine if the click was outside the popup, and if so, we can remove
	# the popup.  This code is from the cellrenderer_date.pl example that comes
	# with Gtk2-perl.  Thanks to muppet for pointing it out.
	$self->{window}->signal_connect(button_press_event => sub {
		my ($popup, $event) = @_;

		if ($event->button == 1) {
			my ($x, $y) = ($event->x_root, $event->y_root);
			my ($xoffset, $yoffset) = $popup->window->get_root_origin;

			my $allocation = $popup->allocation;

			my $x1 = $xoffset + 2 * $allocation->x;
			my $y1 = $yoffset + 2 * $allocation->y;
			my $x2 = $x1 + $allocation->width;
			my $y2 = $y1 + $allocation->height;

			unless ($x > $x1 && $x < $x2 && $y > $y1 && $y < $y2) {
				$self->_remove_popup;
				return 1;
			}
		}

		return 0;
	});

	$self->{window}->show_all;
	$self->{window}->move($self->_popup_position);

	# Grab the focus and pointer so we learn about all button events
	Gtk2->grab_add($self->{window});
	$self->{window}->grab_focus;
	Gtk2::Gdk->pointer_grab(
		$self->{window}->window,
		1,
		[qw(button-press-mask button-release-mask pointer-motion-mask)],
		undef,
		undef,
		0
	);

	return 1;
}

sub _update_mixer {
	my ($get, $self) = @_;
	Audio::Mixer::set_cval($self->{config}{channel}, abs($get->value));
	return 1;
}

sub _popup_position {
	my $self = shift;
	my ($x, undef) = PerlPanel::get_widget_position($self->widget);
	$x = 0 if ($x < 5);

	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);

	} else {
		my $t = ($self->{window}->get_size)[1];
		return ($x, ((PerlPanel::screen_height) - $t - (PerlPanel::panel->allocation->height)));

	}
}

1;
