# $Id: Clock.pm,v 1.15 2003/08/12 16:03:14 jodrell Exp $
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
package PerlPanel::Applet::Clock;
use POSIX qw(strftime);
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->{widget}->set_relief('none');
	$self->{label}= Gtk2::Label->new();
	$self->{widget}->add($self->{label});
	$self->{widget}->signal_connect('clicked', sub { $self->prefs });
	$self->update;
	Glib::Timeout->add($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{interval}, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;
	$self->{label}->set_text(strftime($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format}, localtime(time())));
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, strftime($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format}, localtime(time())));
	return 1;
}

sub prefs {
	my $self = shift;
	$self->{widget}->set_sensitive(0);
	$self->{window} = Gtk2::Dialog->new;
	$self->{window}->set_title("$PerlPanel::NAME: Clock");
	$self->{window}->signal_connect('delete_event', sub { $self->{widget}->set_sensitive(1) });
	$self->{window}->set_border_width(8);
	$self->{window}->vbox->set_spacing(8);
	$self->{window}->set_icon($PerlPanel::OBJECT_REF->icon);
	$self->{table} = Gtk2::Table->new(2, 2, 0);
	$self->{table}->set_col_spacings(8);
	$self->{table}->set_row_spacings(8);
	$self->{table}->set_border_width(8);

	$self->{controls}{format} = Gtk2::Entry->new;
	$self->{controls}{format}->set_text($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format});

	$self->{controls}{date_format} = Gtk2::Entry->new;
	$self->{controls}{date_format}->set_text($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format});

	my $adj = Gtk2::Adjustment->new($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{interval}, 0, 60000, 1, 1000, undef);
	$self->{controls}{interval} = Gtk2::SpinButton->new($adj, 1, 0);

	$self->{labels}{format} = Gtk2::Label->new('Date format:');
	$self->{labels}{format}->set_alignment(1, 0.5);
	$self->{table}->attach_defaults($self->{labels}{format}, 0, 1, 0, 1);
	$self->{table}->attach_defaults($self->{controls}{format}, 1, 2, 0, 1);

	$self->{labels}{date_format} = Gtk2::Label->new('Tooltip format:');
	$self->{labels}{date_format}->set_alignment(1, 0.5);
	$self->{table}->attach_defaults($self->{labels}{date_format}, 0, 1, 1, 2);
	$self->{table}->attach_defaults($self->{controls}{date_format}, 1, 2, 1, 2);

	$self->{notebook} = Gtk2::Notebook->new;

	$self->{calendar} = Gtk2::Calendar->new;

	$self->{notebook}->append_page($self->{calendar}, Gtk2::Label->new('Calendar'));
	$self->{notebook}->append_page($self->{table}, Gtk2::Label->new('Configuration'));

	$self->{window}->vbox->pack_start($self->{notebook}, 1, 1, 0);

	$self->{window}->add_buttons(
		'gtk-cancel', 1,
		'gtk-ok', 0,
	);

	$self->{window}->signal_connect('response', sub {
		if ($_[1] == 0) {
			# 'ok' was clicked
			$PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format}      = $self->{controls}{format}->get_text;
			$PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format} = $self->{controls}{date_format}->get_text;
			$self->{widget}->set_sensitive(1);
			$self->{window}->destroy;
			$PerlPanel::OBJECT_REF->save_config;
			$PerlPanel::OBJECT_REF->reload;
		} elsif ($_[1] == 1) {
			# 'cancel' was clicked
			$self->{widget}->set_sensitive(1);
			$self->{window}->destroy;
		}
	});

	$self->{window}->show_all;

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
	return {
		format		=> '%H:%M',
		date_format	=> '%c',
		interval	=> 1000,
	}
}

1;
