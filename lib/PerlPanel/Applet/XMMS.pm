# $Id: XMMS.pm,v 1.5 2004/01/11 23:07:45 jodrell Exp $
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
package PerlPanel::Applet::XMMS;
use vars qw(%TOOLTIPS %CALLBACKS $ICON_DIR);
use Xmms::Remote;
use strict;

our %TOOLTIPS = (
	prev	=> 'Play Previous Track',
	stop	=> 'Stop Playing',
	play	=> 'Play',
	pause	=> 'Pause',
	next	=> 'Play Next Track',
);

our %CALLBACKS = (
	prev	=> sub { $_[0]->playlist_prev },
	stop	=> sub { $_[0]->stop },
	play	=> sub { if ($_[0]->is_playing) { $_[0]->pause } else { $_[0]->play }},
	next	=> sub { $_[0]->playlist_next },
);

our $ICON_DIR = sprintf('%s/share/pixmaps/%s/xmms-applet', $PerlPanel::PREFIX, lc($PerlPanel::NAME));

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::HBox->new;
	$self->{controller} = Xmms::Remote->new;
	$self->{pbfs}{pause} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/%s.png', $ICON_DIR, 'pause'));
	foreach my $name (qw(prev play stop next)) {
		$self->{buttons}{$name} = $self->create_button($name);
		my $func = $CALLBACKS{$name};
		$self->{buttons}{$name}->signal_connect('clicked', sub { &$func($self->{controller}) });
		$PerlPanel::TOOLTIP_REF->set_tip($self->{buttons}{$name}, $TOOLTIPS{$name});
		$self->{widget}->pack_start($self->{buttons}{$name}, 0, 0, 0);
	}
	Glib::Timeout->add(50, sub {
		my $running = 0;
		eval('$running = ($self->{controller}->is_running ? 1 : 0)');
		if ($running == 0) {
			$self->widget->set_sensitive(0);
		} else {
			$self->widget->set_sensitive(1);
			if ($self->{controller}->is_playing) {
				$self->{buttons}{stop}->set_sensitive(1);
				if ($self->{controller}->is_paused) {
					$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{play});
					$PerlPanel::TOOLTIP_REF->set_tip($self->{buttons}{play}, $TOOLTIPS{play});
				} else {
					$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{pause});
					$PerlPanel::TOOLTIP_REF->set_tip($self->{buttons}{play}, $TOOLTIPS{pause});
				}
			} else {
				$self->{buttons}{stop}->set_sensitive(0);
				$self->{buttons}{play}->child->set_from_pixbuf($self->{pbfs}{play});
			}
		}
		return 1;
	});
	return 1;
}

sub create_button {
	my ($self, $id) = @_;
	$self->{pbfs}{$id} = Gtk2::Gdk::Pixbuf->new_from_file(sprintf('%s/%s.png', $ICON_DIR, $id));
	my $button = Gtk2::Button->new;
	my $image = Gtk2::Image->new_from_pixbuf($self->{pbfs}{$id});
	$button->set_relief('none');
	$button->add($image);
	return $button;
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
	return undef;
}

1;
