# $Id: ScreenShot.pm,v 1.4 2004/09/17 11:28:53 jodrell Exp $
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
package PerlPanel::Applet::ScreenShot;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new();
	$self->widget->set_relief('none');
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('ScreenShot', PerlPanel::icon_size)));
	$self->widget->signal_connect('clicked', sub { $self->prompt });

	$self->{app} = PerlPanel::load_glade('screenshot');
	$self->{app}->get_widget('screenshot_dialog')->signal_connect('delete_event', sub {
		$self->{app}->get_widget('screenshot_dialog')->hide_all;
		return 1;
	});
	$self->{app}->get_widget('screenshot_dialog')->signal_connect('response', sub {
		$self->{app}->get_widget('screenshot_dialog')->hide_all;
		if ($_[1] eq 'ok') {
			$self->get_screenshot->save($self->{app}->get_widget('file_entry')->get_text, 'png');
		}
		return undef;
	});
	$self->{app}->get_widget('browse_button')->signal_connect('clicked', sub {
		my $dialog;
		if ('' ne (my $msg = Gtk2->check_version (2, 4, 0)) or $Gtk2::VERSION < 1.040) {
			$dialog = Gtk2::FileSelection->new(_('Choose File'));
		} else {
			$dialog = Gtk2::FileChooserDialog->new(
				_('Choose File'),
				undef,
				'save',
				'gtk-cancel'	=> 'cancel',
				'gtk-ok' => 'ok'
			);
		}
		$dialog->set_icon(PerlPanel::icon);
		$dialog->set_filename($self->{app}->get_widget('file_entry')->get_text);
		$dialog->signal_connect('response', sub {
			if ($_[1] eq 'ok') {
				$self->{app}->get_widget('file_entry')->set_text($dialog->get_filename);
			}
			$dialog->destroy;
		});
		$dialog->show_all;
	});

	PerlPanel::tips->set_tip($self->widget, _('Take Screenshot'));
	$self->widget->show_all;
	return 1;

}

sub prompt {
	my $self = shift;
	my $pbf = $self->get_screenshot->scale_simple(240, (PerlPanel::screen_height() * (240 / PerlPanel::screen_width())), 'bilinear');
	$self->{app}->get_widget('preview_image')->set_from_pixbuf($pbf);
	$self->{app}->get_widget('file_entry')->set_text(_('{home}/screenshot.png', home => $ENV{HOME}));
	$self->{app}->get_widget('screenshot_dialog')->set_icon(PerlPanel::icon);
	$self->{app}->get_widget('screenshot_dialog')->set_position('center');
	$self->{app}->get_widget('screenshot_dialog')->show_all;
	return 1;
}

sub get_screenshot {
	my $self = shift;
	my $window = Gtk2::Gdk::Screen->get_default->get_root_window;
	my ($width, $height) = $window->get_size;
	my $pbf = Gtk2::Gdk::Pixbuf->new('rgb', 1, 8, $width, $height);
	$pbf->get_from_drawable($window, $window->get_colormap, 0, 0, 0, 0, $width, $height);
	return $pbf;
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
	return undef;
}

1;
